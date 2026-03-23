# Pace Indicator — Design Spec

**Date:** 2026-03-22
**Status:** Approved

## Overview

Add a "pace" indicator to the Claude Usage Widget that shows whether the user is over or under their usage allotment based on linear interpolation. Displays both a projected final utilization percentage and a visual marker on the usage bar.

## Design Choice

**Hybrid (Marker + Minimal Text)** — a vertical tick on the usage bar at the projected position, plus a compact `→ XX%` label next to the reset timer, color-coded by pace status. No explicit "over/under" text label; status is conveyed through color.

## Data Model & Calculation

### Linear Interpolation Formula

```
windowDuration = 5 hours or 7 days (depending on metric)
windowStart = resetsAt - windowDuration
elapsed = now - windowStart
fractionElapsed = elapsed / windowDuration  (0.0 to 1.0)
projectedPercent = (currentPercent / fractionElapsed) clamped to 0...100
expectedPercent = fractionElapsed * 100
```

### Pace Status

- **Under pace**: `projectedPercent < expectedPercent - 5`
- **On pace**: within 5 points of expected (dead zone to prevent flickering)
- **Over pace**: `projectedPercent > expectedPercent + 5`

### New Types

```swift
enum PaceStatus: Codable {
    case under, on, over
}

struct PaceInfo {
    let projectedPercent: Double   // 0...100, where you'll end up at reset
    let status: PaceStatus         // .under / .on / .over
}
```

`PaceInfo` is computed from an existing `UsageMetric` — no new API calls needed. Computed on-demand as a method on `UsageMetric` or a standalone function.

### Guard Rails

- If `fractionElapsed < 0.05` (less than 5% into the window), return nil — not enough data to project.
- If `projectedPercent > 100`, clamp marker to 100% and display `→ 100%+`.

## Visual Design

### Colors

- **Under pace**: green `#5B9A6F`
- **On pace**: yellow `#C4A84D`
- **Over pace**: coral `#E07A5F` (matches existing warning color)

### Popover (UsageBarView)

- Bar track gains `overflow: visible` (clipsToBounds = false in SwiftUI terms)
- 2pt-wide vertical tick positioned at `projectedPercent%` along the bar width
- Tick extends slightly above and below the bar (top: -3pt, height: 14pt for an 8pt bar)
- Tick color matches pace status
- Reset timer row gains a right-aligned `→ XX%` in matching color
- When pace is disabled for a metric, marker and label are hidden — bar unchanged from current

### Edge Cases

- If marker would be within 3% of the fill edge, offset slightly so they don't merge visually
- Marker opacity: 0.7 to avoid visual dominance over the actual fill

### Widgets (WidgetUsageBar)

Same concept, scaled for widget density:
- 2pt marker tick on the 6pt bar
- 8px `→ XX%` text next to reset timer
- Small widget: pace on the single 5-hour bar (if enabled)
- Medium widget: pace on both bars (if enabled)
- Large widget: pace on all visible bars

### Unchanged

- Menu bar icon
- Token stats section
- Debug panel
- API calls / refresh intervals
- Shared container file format (additive change only)

## Settings & Configuration

### User Preference

- `paceEnabledMetrics: Set<String>` stored on `UsageSnapshot`
- Valid keys: `"fiveHour"`, `"sevenDay"`, `"sevenDaySonnet"`, `"sevenDayOpus"`
- `nil` means all enabled (backwards compatibility with old snapshots)
- Default: all enabled

### Popover Settings

- New "Pace Indicator" section in SettingsView
- Individual toggle for each metric
- Changes write to UserDefaults and update the snapshot's `paceEnabledMetrics` on next refresh

### Widget Behavior

- Widgets read `paceEnabledMetrics` from the shared container snapshot
- Preference flows through the existing `UsageSnapshot` → `SharedContainerService` → widget pipeline
- No separate settings file needed

### Snapshot Model Change

```swift
struct UsageSnapshot: Codable, Equatable {
    // ... existing fields ...
    let paceEnabledMetrics: Set<String>?  // nil = all enabled
}
```

## Testing

### Unit Tests

- **Pace calculation**: test at 0%, 25%, 50%, 75%, 100% elapsed with various utilization levels
- **Edge cases**: < 5% elapsed returns nil, projected > 100% clamps, zero usage
- **Dead zone**: verify 5-point threshold assigns under/on/over correctly
- **Settings serialization**: `paceEnabledMetrics` encodes/decodes, nil defaults to all enabled
- **Backwards compat**: old snapshots without `paceEnabledMetrics` decode correctly

### Not Testing

- SwiftUI view rendering (consistent with existing project pattern)

## Files Modified

- `Shared/Models/UsageSnapshot.swift` — add `paceEnabledMetrics`, `PaceInfo`, `PaceStatus`, pace computation
- `App/Views/UsageBarView.swift` — add projection marker and `→ XX%` label
- `App/Views/SettingsView.swift` — add pace toggle section
- `App/UsageManager.swift` — read/write pace settings to UserDefaults, include in snapshot
- `Widget/Views/WidgetUsageBar.swift` — add projection marker and label
- `Widget/Views/SmallWidgetView.swift` — pass pace data through
- `Widget/Views/MediumWidgetView.swift` — pass pace data through
- `Widget/Views/LargeWidgetView.swift` — pass pace data through
- `Shared/Theme/AnthropicColors.swift` — add green and yellow pace colors
- `Tests/` — new pace calculation tests, updated snapshot tests
