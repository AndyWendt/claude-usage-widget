import SwiftUI
import AppKit

enum AnthropicColors {
    static let tan = Color(red: 0.831, green: 0.647, blue: 0.455)           // #D4A574
    static let tanLight = Color(red: 0.910, green: 0.831, blue: 0.737)      // #E8D4BC
    static let tanDark = Color(red: 0.722, green: 0.584, blue: 0.416)       // #B8956A
    static let coral = Color(red: 0.878, green: 0.478, blue: 0.373)         // #E07A5F
    static let coralLight = Color(red: 0.941, green: 0.627, blue: 0.565)    // #F0A090
    static let charcoal = Color(red: 0.176, green: 0.165, blue: 0.149)      // #2D2A26
    static let cream = Color(red: 0.980, green: 0.969, blue: 0.949)         // #FAF7F2
    static let creamMuted = Color(red: 0.980, green: 0.969, blue: 0.949).opacity(0.6)
    static let dangerDark = Color(red: 0.659, green: 0.314, blue: 0.251)    // #A85040
    static let opusBrown = Color(red: 0.545, green: 0.451, blue: 0.333)     // #8B7355
    static let iconGreen = Color(red: 0.290, green: 0.855, blue: 0.502)     // #4ade80
    static let iconRed = Color(red: 0.937, green: 0.267, blue: 0.267)       // #ef4444

    // Gradients
    static let normalGradient = LinearGradient(
        colors: [tanDark, tan], startPoint: .leading, endPoint: .trailing
    )
    static let opusGradient = LinearGradient(
        colors: [opusBrown, tanLight], startPoint: .leading, endPoint: .trailing
    )
    static let warningGradient = LinearGradient(
        colors: [coral, coralLight], startPoint: .leading, endPoint: .trailing
    )
    static let dangerGradient = LinearGradient(
        colors: [dangerDark, coral], startPoint: .leading, endPoint: .trailing
    )
}

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
        let tinted = baseImage.withSymbolConfiguration(config) ?? (baseImage.copy() as! NSImage)
        tinted.isTemplate = false
        return tinted
    }
}
