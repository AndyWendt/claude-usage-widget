import SwiftUI

struct SmallWidgetView: View {
    let snapshot: UsageSnapshot
    let paceByMetric: [MetricKey: PaceInfo]
    let codexPaceByMetric: [MetricKey: PaceInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.hasCodexData ? "AI Usage" : "Claude Usage")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)

            if snapshot.hasCodexData {
                if let fiveHour = snapshot.fiveHour {
                    WidgetUsageBar(
                        label: "Claude",
                        percent: fiveHour.percent,
                        resetsAt: fiveHour.resetsAt,
                        paceInfo: paceByMetric[.fiveHour]
                    )
                }

                if let codexFiveHour = snapshot.codex?.fiveHour {
                    WidgetUsageBar(
                        label: "Codex",
                        percent: codexFiveHour.percent,
                        resetsAt: codexFiveHour.resetsAt,
                        paceInfo: codexPaceByMetric[.fiveHour],
                        fillGradient: AnthropicColors.codexGradient,
                        trackColor: AnthropicColors.codexTrack
                    )
                }
            } else if let fiveHour = snapshot.fiveHour {
                WidgetUsageBar(
                    label: "5-Hour",
                    percent: fiveHour.percent,
                    resetsAt: fiveHour.resetsAt,
                    paceInfo: paceByMetric[.fiveHour]
                )
            } else {
                Text("No data")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if snapshot.error != nil {
                WidgetErrorIndicator(snapshot: snapshot)
            } else if snapshot.isStale {
                staleIndicator
            }
        }
        .padding(12)
    }

    private var staleIndicator: some View {
        HStack(spacing: 2) {
            Image(systemName: "clock")
                .font(.system(size: 8))
            Text(snapshot.lastUpdated, style: .relative)
                .font(.system(size: 8))
        }
        .foregroundStyle(.tertiary)
    }
}
