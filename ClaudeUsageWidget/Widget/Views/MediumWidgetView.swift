import SwiftUI

struct MediumWidgetView: View {
    let snapshot: UsageSnapshot
    let paceSettings: PaceSettings

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Usage")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnthropicColors.tan)

                if let fiveHour = snapshot.fiveHour {
                    WidgetUsageBar(
                        label: "5-Hour",
                        percent: fiveHour.percent,
                        resetsAt: fiveHour.resetsAt,
                        paceInfo: paceSettings.enabledMetrics.contains(.fiveHour)
                            ? computePace(metric: fiveHour, windowDuration: MetricKey.fiveHour.windowDuration)
                            : nil
                    )
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(" ")
                    .font(.system(size: 11))

                if let sevenDay = snapshot.sevenDay {
                    WidgetUsageBar(
                        label: "Weekly",
                        percent: sevenDay.percent,
                        resetsAt: sevenDay.resetsAt,
                        paceInfo: paceSettings.enabledMetrics.contains(.sevenDay)
                            ? computePace(metric: sevenDay, windowDuration: MetricKey.sevenDay.windowDuration)
                            : nil
                    )
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
        }
        .padding(12)
    }

}
