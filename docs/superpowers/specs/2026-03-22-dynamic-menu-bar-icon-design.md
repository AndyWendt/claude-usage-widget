# Dynamic Menu Bar Icon

## Summary

Replace the static `gauge.medium` SF Symbol in the menu bar with a dynamic icon that reflects current usage level. The icon changes both its SF Symbol variant (needle position) and color tint based on the highest usage across three tracked metrics.

## Metric Selection

The icon is driven by the **maximum** clamped usage percentage across these three metrics:

- 5-hour window (`fiveHour.clampedPercent`)
- 7-day all models (`sevenDay.clampedPercent`)
- 7-day Opus (`sevenDayOpus.clampedPercent`)

Sonnet weekly (`sevenDaySonnet`) is **excluded** from the calculation.

When no snapshot is loaded (app just launched, no data yet), fall back to the current static `gauge.medium` with default system tint.

## Icon States

| Tier | Range | SF Symbol | Color |
|---|---|---|---|
| Low | 0–39% | `gauge.open.with.lines.needle.33percent` | Green (#4ade80) |
| Moderate | 40–69% | `gauge.open.with.lines.needle.50percent` | Tan (#D4A574) |
| High | 70–89% | `gauge.open.with.lines.needle.67percent` | Coral (#E07A5F) |
| Critical | 90%+ | `gauge.open.with.lines.needle.84percent` | Red (#ef4444) |

**SF Symbol verification note:** The exact symbol names in the `gauge.open.with.lines.needle.*` family must be verified in the SF Symbols app on the target macOS version (14+). If any variant does not exist, fall back to the closest available variant in the `gauge.with.dots.needle.*` family (which has `0percent`, `33percent`, `50percent`, `67percent`, `100percent`). The implementation should include a compile-time or runtime check and document which symbols were actually used.

No text or percentage is displayed in the menu bar — icon only.

## Color Rendering

**macOS forces template rendering on menu bar icons**, which means `.foregroundStyle()` applied to an `Image` inside `MenuBarExtra`'s label is ignored — the system overrides it to monochrome.

To display colored icons, we must render the SF Symbol into an `NSImage` with `isTemplate = false`:

1. Create an `NSImage` from the SF Symbol name using `NSImage(systemSymbolName:accessibilityDescription:)`
2. Apply a symbol configuration with the desired tint color using `withSymbolConfiguration(.init(paletteColors: [nsColor]))`
3. Set `isTemplate = false` on the resulting image so macOS does not force monochrome
4. Use `Image(nsImage:)` in the `MenuBarExtra` label

This is a well-established pattern used by apps like iStat Menus for colored menu bar icons.

## Files to Change

### 1. `UsageSnapshot.swift` — Add computed property

Add a `maxUsagePercent` computed property to `UsageSnapshot` that returns the maximum clamped percent across the three relevant metrics (excluding Sonnet), or `nil` if no metrics are available. This is a computed property so it has no impact on `Codable` conformance:

```swift
var maxUsagePercent: Double? {
    let values = [fiveHour?.clampedPercent, sevenDay?.clampedPercent, sevenDayOpus?.clampedPercent].compactMap { $0 }
    return values.max()
}
```

### 2. `AnthropicColors.swift` — Add icon tier enum and NSColor helpers

Add the two new colors not already in the palette (green and red):

```swift
static let iconGreen = Color(red: 0.290, green: 0.855, blue: 0.502)
static let iconRed = Color(red: 0.937, green: 0.267, blue: 0.267)
```

Add a `MenuBarIconTier` enum. Using an enum gives natural `Equatable`/`Hashable` conformance and prevents unnecessary SwiftUI redraws:

```swift
enum MenuBarIconTier: Equatable {
    case idle
    case low
    case moderate
    case high
    case critical

    var symbolName: String {
        switch self {
        case .idle:  return "gauge.medium"
        case .low:      return "gauge.open.with.lines.needle.33percent"
        case .moderate: return "gauge.open.with.lines.needle.50percent"
        case .high:     return "gauge.open.with.lines.needle.67percent"
        case .critical: return "gauge.open.with.lines.needle.84percent"
        }
    }

    var tintNSColor: NSColor {
        switch self {
        case .idle:  return .labelColor
        case .low:      return NSColor(AnthropicColors.iconGreen)
        case .moderate: return NSColor(AnthropicColors.tan)
        case .high:     return NSColor(AnthropicColors.coral)
        case .critical: return NSColor(AnthropicColors.iconRed)
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .idle:  return "Claude Usage"
        case .low:      return "Claude Usage: Low"
        case .moderate: return "Claude Usage: Moderate"
        case .high:     return "Claude Usage: High"
        case .critical: return "Claude Usage: Critical"
        }
    }

    static func from(percent: Double) -> MenuBarIconTier {
        switch percent {
        case ..<40:  return .low
        case ..<70:  return .moderate
        case ..<90:  return .high
        default:     return .critical
        }
    }

    /// Renders the SF Symbol as a tinted NSImage suitable for the menu bar.
    /// For the `.idle` case, returns a template image so macOS handles
    /// dark/light mode automatically. For all other tiers, returns a
    /// non-template image with the tier color baked in.
    func menuBarImage() -> NSImage {
        guard let baseImage = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityLabel
        ) else {
            return NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Claude Usage")!
        }

        // Idle tier: let macOS handle appearance (template = true)
        if self == .idle {
            baseImage.isTemplate = true
            return baseImage
        }

        let config = NSImage.SymbolConfiguration(paletteColors: [tintNSColor])
        let tinted = baseImage.withSymbolConfiguration(config) ?? (baseImage.copy() as! NSImage)
        tinted.isTemplate = false
        return tinted
    }
}
```

### 3. `UsageManager.swift` — Add published icon tier with `didSet`

Use `didSet` on `snapshot` to derive the icon tier. This ensures the tier updates on both the success and error paths of `refresh()`:

```swift
@Published var iconTier: MenuBarIconTier = .idle

@Published var snapshot: UsageSnapshot? {
    didSet {
        if let percent = snapshot?.maxUsagePercent {
            iconTier = MenuBarIconTier.from(percent: percent)
        } else {
            iconTier = .default
        }
    }
}
```

### 4. `ClaudeUsageWidgetApp.swift` — Use dynamic icon

Replace the static `MenuBarExtra` with the label-based initializer, rendering a tinted `NSImage`:

```swift
MenuBarExtra {
    MenuBarContentView(
        manager: manager,
        refreshInterval: $refreshInterval
    )
} label: {
    let image = manager.iconTier.menuBarImage()
    Image(nsImage: image)
        .accessibilityLabel(manager.iconTier.accessibilityLabel)
}
.menuBarExtraStyle(.window)
```

## Update Cadence

The icon updates every time the snapshot refreshes — on the existing configurable timer interval (default 5 minutes). No additional timer or polling is needed.

## Fallback Behavior

- **No data loaded:** Static `gauge.medium`, default system label color (monochrome)
- **API error with no metrics:** Same as no data — static gauge, default tint
- **All metrics at 0%:** Low tier — green gauge with needle at 33%
- **SF Symbol not found:** Falls back to `gauge.medium`

## Testing Considerations

- `MenuBarIconTier.from(percent:)` is a pure function — unit test the threshold boundaries (0, 39, 40, 69, 70, 89, 90, 100)
- `UsageSnapshot.maxUsagePercent` — test with combinations of nil/non-nil metrics, verify Sonnet is excluded, verify negative values and values >100 are clamped
- Verify fallback to `.idle` when snapshot is nil or has no metrics
- Manual verification: confirm the SF Symbol names render correctly on macOS 14+ in the SF Symbols app
- Manual verification: confirm colored icon renders in menu bar (not forced to monochrome)
