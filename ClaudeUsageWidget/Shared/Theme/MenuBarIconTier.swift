import AppKit
import SwiftUI

enum MenuBarIconTier: Equatable {
    case idle
    case low
    case moderate
    case high
    case critical

    var symbolName: String {
        switch self {
        case .idle:     return "gauge.medium"
        case .low:      return "gauge.open.with.lines.needle.33percent"
        case .moderate: return "gauge.open.with.lines.needle.50percent"
        case .high:     return "gauge.open.with.lines.needle.67percent"
        case .critical: return "gauge.open.with.lines.needle.84percent"
        }
    }

    var tintNSColor: NSColor {
        switch self {
        case .idle:     return .labelColor
        case .low:      return NSColor(AnthropicColors.iconGreen)
        case .moderate: return NSColor(AnthropicColors.tan)
        case .high:     return NSColor(AnthropicColors.coral)
        case .critical: return NSColor(AnthropicColors.iconRed)
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .idle:     return "Claude Usage"
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
            if let fallback = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Claude Usage") {
                fallback.isTemplate = true
                return fallback
            }
            return NSImage(size: NSSize(width: 18, height: 18))
        }

        if self == .idle {
            baseImage.isTemplate = true
            return baseImage
        }

        let config = NSImage.SymbolConfiguration(paletteColors: [tintNSColor])
        let tinted: NSImage
        if let configured = baseImage.withSymbolConfiguration(config) {
            tinted = configured
        } else {
            DebugLogger.shared.log(
                "withSymbolConfiguration returned nil for \(symbolName) — falling back to untinted",
                source: "MenuBarIcon"
            )
            tinted = (baseImage.copy() as? NSImage) ?? baseImage
        }
        tinted.isTemplate = false
        return tinted
    }
}
