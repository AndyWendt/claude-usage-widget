import SwiftUI

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
    static let paceGreen = Color(red: 0.357, green: 0.604, blue: 0.435)    // #5B9A6F
    static let paceYellow = Color(red: 0.769, green: 0.659, blue: 0.302)   // #C4A84D

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
