import SwiftUI

struct TokenStatsView: View {
    let stats: TokenStats

    var body: some View {
        VStack(spacing: 4) {
            statsRow(label: "Today:", value: stats.formattedTodayTokens)
            statsRow(label: "This week:", value: stats.formattedWeekTokens)
        }
    }

    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AnthropicColors.creamMuted)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(AnthropicColors.cream)
        }
    }
}
