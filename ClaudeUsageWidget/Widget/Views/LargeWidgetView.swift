import SwiftUI

struct LargeWidgetView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Claude Code Usage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)

            if let fiveHour = snapshot.fiveHour {
                WidgetUsageBar(label: "5-Hour Window", percent: fiveHour.percent, resetsAt: fiveHour.resetsAt)
            }
            if let sevenDay = snapshot.sevenDay {
                WidgetUsageBar(label: "Weekly (All)", percent: sevenDay.percent, resetsAt: sevenDay.resetsAt)
            }
            if let sonnet = snapshot.sevenDaySonnet {
                WidgetUsageBar(label: "Weekly (Sonnet)", percent: sonnet.percent, resetsAt: sonnet.resetsAt)
            }
            if let opus = snapshot.sevenDayOpus {
                WidgetUsageBar(label: "Weekly (Opus)", percent: opus.percent, resetsAt: opus.resetsAt, isOpus: true)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(snapshot.tokenStats.formattedTodayTokens)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("This week")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(snapshot.tokenStats.formattedWeekTokens)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
            }

            Spacer()

            if snapshot.error != nil {
                WidgetErrorIndicator(snapshot: snapshot)
            } else if snapshot.isStale {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(snapshot.lastUpdated, style: .relative)
                        .font(.system(size: 8))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
    }

}
