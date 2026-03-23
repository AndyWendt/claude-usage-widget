# Pace Indicator — Design Spec

**Date:** 2026-03-22
**Status:** Approved

## Overview

Add a "pace" indicator to the Claude Usage Widget that shows whether the user's current consumption rate will overshoot or undershoot the limit before the window resets, compared to a linear expected curve. Displays both a projected final utilization percentage and a visual marker on the usage bar.

## Design Choice

**Hybrid (Marker + Minimal Text)** — a vertical tick on the usage bar at the projected position, plus a compact `→ XX%` label next to the reset timer, color-coded by pace status. No explicit "over/under" text label; status is conveyed through color.

## Data Model & Calculation

### Linear Interpolation Formula

```
windowDuration = 5 hours or 7 days (depending on metric — see below)
windowStart = resetsAt - windowDuration
elapsed = now - windowStart
fractionElapsed = elapsed / windowDuration  (0.0 to 1.0)
projectedPercent = (currentPercent / fractionElapsed) clamped to 0...100
expectedPercent = fractionElapsed * 100
```

### Window Duration

`UsageMetric` does not carry a `windowDuration` field. The pace calculation is a **standalone function** that accepts `windowDuration` as a parameter:

```swift
func computePace(
    metric: UsageMetric,
    windowDuration: TimeInterval,
    now: Date = .init()
) -> PaceInfo?
```

Call sites pass the known duration:
- `fiveHour` → `5 * 3600` (5 hours)
- `sevenDay`, `sevenDaySonnet`, `sevenDayOpus` → `7 * 24 * 3600` (7 days)

### Pace Status

Comparison is against the **linear expected curve** (steady usage across the window), not against 100% capacity. This answers: "Am I consuming faster or slower than a perfectly even rate?"

- **Under pace**: `projectedPercent < expectedPercent - 5`
- **On pace**: within 5 points of expected (dead zone to prevent flickering)
- **Over pace**: `projectedPercent > expectedPercent + 5`

### New Types

```swift
enum PaceStatus {
    case under, on, over
}

struct PaceInfo {
    let projectedPercent: Double   // 0...100+, where you'll end up at reset
    let status: PaceStatus         // .under / .on / .over
}
```

Both types are transient — computed on-demand, never serialized. Neither is `Codable`.

### Guard Rails

- If `fractionElapsed < 0.05` (less than 5% into the window), return nil — not enough data to project.
- If `fractionElapsed >= 1.0` or `fractionElapsed <= 0.0` (window expired or hasn't started), return nil.
- If `projectedPercent > 100`, clamp marker position to 100% and display `→ 100%+`. The `projectedPercent` value itself is unclamped for the label.

## Visual Design

### Colors

New colors are an intentional palette expansion beyond the existing tan/coral family, chosen to provide clear semantic meaning for pace status:

- **Under pace**: green `#5B9A6F` — muted to stay on-brand
- **On pace**: yellow `#C4A84D` — warm tone complementing the tan palette
- **Over pace**: coral `#E07A5F` (reuses existing `AnthropicColors.coral`)

### Popover (UsageBarView)

- The bar uses `GeometryReader` + `ZStack`. SwiftUI does not clip child content by default, so the tick marker is added as an additional child in the `ZStack` (or via `.overlay`). No `.clipped()` exists on the bar currently — ensure none is added.
- 2pt-wide `RoundedRectangle` tick positioned at `projectedPercent%` along the bar width
- Tick extends slightly above and below the bar (top: -3pt, height: 14pt for an 8pt bar)
- Tick color matches pace status
- Tick opacity: 0.7 to avoid visual dominance over the actual fill
- The pace `→ XX%` label is placed **outside and after `ResetTimerView`** in `UsageBarView`'s `VStack`. It is NOT inside `ResetTimerView` (which only takes `resetsAt: Date`). Layout: an `HStack` containing `ResetTimerView` + `Spacer` + pace label.
- When pace is disabled for a metric (or returns nil), marker and label are hidden — bar unchanged from current

### Edge Cases

- If the marker would be within 3% of the fill edge, offset the marker **away from the fill** by 4pt, clamped to bar bounds (0...barWidth).
- If projected is near 0% or 100%, clamp marker position to stay within bar bounds.

### Widgets (WidgetUsageBar)

Same concept, scaled for widget density. Note: widgets use inline `Text(resetsAt, style: .relative)` rather than `ResetTimerView`, so the pace label is placed in an `HStack` alongside the existing reset text.

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

## Settings & Configuration

### User Preference

Pace settings are stored **separately from `UsageSnapshot`** to keep the snapshot as a pure data-transfer object. Two storage locations:

1. **App**: `@AppStorage("paceEnabledMetrics")` in UserDefaults (consistent with existing `@AppStorage("refreshInterval")` pattern). Stored as a JSON-encoded `Set<String>`.
2. **Widget**: A separate `pace-settings.json` file in the shared container, written by `SharedContainerService` alongside `usage-snapshot.json`.

Valid keys: `"fiveHour"`, `"sevenDay"`, `"sevenDaySonnet"`, `"sevenDayOpus"`
Default: all enabled (when file is missing or empty, treat as all enabled).

### New Type

```swift
struct PaceSettings: Codable, Equatable {
    let enabledMetrics: Set<String>

    static let allEnabled = PaceSettings(enabledMetrics: [
        "fiveHour", "sevenDay", "sevenDaySonnet", "sevenDayOpus"
    ])
}
```

### SharedContainerService Addition

```swift
func writePaceSettings(_ settings: PaceSettings) throws
func readPaceSettings() -> PaceSettings  // returns .allEnabled if file missing
```

### Popover Settings

- New "Pace Indicator" section in SettingsView
- Individual toggle for each metric
- Changes write to UserDefaults AND shared container (via `SharedContainerService.writePaceSettings`)

### Widget Behavior

- Widgets read `pace-settings.json` from the shared container via `SharedContainerService.readPaceSettings()`
- Missing file = all enabled (graceful degradation)
- `UsageSnapshot` is NOT modified — no new fields, no migration burden, no impact on existing call sites or tests

## Testing

### Unit Tests

- **Pace calculation**: test `computePace()` at 0%, 25%, 50%, 75%, 100% elapsed with various utilization levels
- **Window duration parameter**: verify correct results with 5-hour and 7-day durations
- **Guard rails**: `fractionElapsed < 0.05` returns nil, `fractionElapsed >= 1.0` returns nil, `fractionElapsed <= 0.0` returns nil
- **Edge cases**: projected > 100% produces unclamped value with correct status, zero usage
- **Dead zone**: verify 5-point threshold assigns under/on/over correctly
- **PaceSettings serialization**: `PaceSettings` encodes/decodes correctly
- **PaceSettings defaults**: missing file returns `.allEnabled`
- **SharedContainerService**: write/read roundtrip for `pace-settings.json`

### Not Testing

- SwiftUI view rendering (consistent with existing project pattern)

## Files Modified

- `Shared/Models/UsageSnapshot.swift` — add `PaceInfo`, `PaceStatus`, `PaceSettings`, `computePace()` function (UsageSnapshot struct itself unchanged)
- `Shared/Services/SharedContainerService.swift` — add `writePaceSettings()` / `readPaceSettings()`
- `Shared/Services/ServiceProtocols.swift` — add pace settings methods to protocol
- `Shared/Theme/AnthropicColors.swift` — add `paceGreen`, `paceYellow` colors
- `App/Views/UsageBarView.swift` — add projection marker tick and `→ XX%` label in HStack after ResetTimerView
- `App/Views/SettingsView.swift` — add pace toggle section
- `App/UsageManager.swift` — read/write pace settings to UserDefaults and shared container
- `Widget/Views/WidgetUsageBar.swift` — add projection marker and pace label
- `Widget/Views/SmallWidgetView.swift` — read pace settings, pass through
- `Widget/Views/MediumWidgetView.swift` — read pace settings, pass through
- `Widget/Views/LargeWidgetView.swift` — read pace settings, pass through
- `Tests/` — new `PaceTests.swift` for calculation tests, updated `SharedContainerServiceTests.swift`
