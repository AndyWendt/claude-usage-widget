# Dynamic Menu Bar Icon

## Summary

Replace the static `gauge.medium` SF Symbol in the menu bar with a dynamic icon that reflects current usage level. The icon changes both its SF Symbol variant (needle position) and color tint based on the highest usage across three tracked metrics.

## Metric Selection

The icon is driven by the **maximum** usage percentage across these three metrics:

- 5-hour window (`fiveHour.percent`)
- 7-day all models (`sevenDay.percent`)
- 7-day Opus (`sevenDayOpus.percent`)

Sonnet weekly (`sevenDaySonnet`) is **excluded** from the calculation.

When no snapshot is loaded (app just launched, no data yet), fall back to the current static `gauge.medium` with default system tint.

## Icon States

| Tier | Range | SF Symbol | Color |
|---|---|---|---|
| Low | 0–39% | `gauge.open.with.lines.needle.33percent` | Green — `Color(red: 0.290, green: 0.855, blue: 0.502)` (#4ade80) |
| Moderate | 40–69% | `gauge.open.with.lines.needle.50percent` | Tan — `AnthropicColors.tan` (#D4A574) |
| High | 70–89% | `gauge.open.with.lines.needle.67percent` | Coral — `AnthropicColors.coral` (#E07A5F) |
| Critical | 90%+ | `gauge.open.with.lines.needle.100percent` | Red — `Color(red: 0.937, green: 0.267, blue: 0.267)` (#ef4444) |

No text or percentage is displayed in the menu bar — icon only.

## Color Rendering

Use `.foregroundColor()` tinting on the SF Symbol `Image`. This produces a single-color tint that matches the monochrome menu bar aesthetic. No palette or hierarchical rendering needed.

## Files to Change

### 1. `UsageSnapshot.swift` — Add computed property

Add a `maxUsagePercent` computed property to `UsageSnapshot` that returns the maximum percent across the three relevant metrics (excluding Sonnet), or `nil` if no metrics are available:

```swift
var maxUsagePercent: Double? {
    let values = [fiveHour?.percent, sevenDay?.percent, sevenDayOpus?.percent].compactMap { $0 }
    return values.max()
}
```

### 2. `AnthropicColors.swift` — Add icon tier colors

Add the two new colors not already in the palette (green and red), plus add an enum or struct that maps a usage percentage to an icon tier containing the SF Symbol name and color:

```swift
static let iconGreen = Color(red: 0.290, green: 0.855, blue: 0.502)
static let iconRed = Color(red: 0.937, green: 0.267, blue: 0.267)
```

Add a `MenuBarIconState` type:

```swift
struct MenuBarIconState {
    let symbolName: String
    let tintColor: Color

    static let `default` = MenuBarIconState(
        symbolName: "gauge.medium",
        tintColor: .primary
    )

    static func from(percent: Double) -> MenuBarIconState {
        switch percent {
        case ..<40:
            return MenuBarIconState(symbolName: "gauge.open.with.lines.needle.33percent", tintColor: AnthropicColors.iconGreen)
        case ..<70:
            return MenuBarIconState(symbolName: "gauge.open.with.lines.needle.50percent", tintColor: AnthropicColors.tan)
        case ..<90:
            return MenuBarIconState(symbolName: "gauge.open.with.lines.needle.67percent", tintColor: AnthropicColors.coral)
        default:
            return MenuBarIconState(symbolName: "gauge.open.with.lines.needle.100percent", tintColor: AnthropicColors.iconRed)
        }
    }
}
```

### 3. `UsageManager.swift` — Add published icon state

Add a `@Published var iconState: MenuBarIconState = .default` property. Update it at the end of `refresh()` whenever `snapshot` changes:

```swift
if let percent = snapshot?.maxUsagePercent {
    iconState = MenuBarIconState.from(percent: percent)
} else {
    iconState = .default
}
```

### 4. `ClaudeUsageWidgetApp.swift` — Use dynamic icon

Replace the static `MenuBarExtra` with a dynamic one. `MenuBarExtra` supports `label:` with a custom view instead of `systemImage:`:

```swift
MenuBarExtra {
    MenuBarContentView(...)
} label: {
    Image(systemName: manager.iconState.symbolName)
        .foregroundColor(manager.iconState.tintColor)
}
.menuBarExtraStyle(.window)
```

## Update Cadence

The icon updates every time the snapshot refreshes — on the existing configurable timer interval (default 5 minutes). No additional timer or polling is needed.

## Fallback Behavior

- **No data loaded:** Static `gauge.medium`, default system tint (`.primary`)
- **API error with no metrics:** Same as no data — static gauge, default tint
- **All metrics at 0%:** Low tier — green gauge with needle at 33%

## Testing Considerations

- `MenuBarIconState.from(percent:)` is a pure function — unit test the threshold boundaries (39, 40, 69, 70, 89, 90)
- `UsageSnapshot.maxUsagePercent` — test with combinations of nil/non-nil metrics, verify Sonnet is excluded
- Verify fallback to `.default` when snapshot is nil or has no metrics
