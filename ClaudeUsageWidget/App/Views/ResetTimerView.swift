import SwiftUI

struct ResetTimerView: View {
    let resetsAt: Date

    var body: some View {
        Text(timerText)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(AnthropicColors.creamMuted)
    }

    private var timerText: String {
        let remaining = resetsAt.timeIntervalSince(Date())
        guard remaining > 0 else { return "Resetting..." }

        let totalMinutes = Int(remaining) / 60
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "Resets in \(days)d \(hours)h"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }
}
