import SwiftUI

struct MediumWidgetView: View {
    let snapshot: UsageSnapshot
    let paceByMetric: [MetricKey: PaceInfo]
    let codexPaceByMetric: [MetricKey: PaceInfo]

    var body: some View {
        Group {
            if snapshot.hasCodexData {
                HStack(spacing: 12) {
                    WidgetProviderColumn(
                        title: "Claude",
                        fiveHour: snapshot.fiveHour,
                        weekly: snapshot.sevenDay,
                        fiveHourPace: paceByMetric[.fiveHour],
                        weeklyPace: paceByMetric[.sevenDay]
                    )

                    WidgetProviderColumn(
                        title: "Codex",
                        fiveHour: snapshot.codex?.fiveHour,
                        weekly: snapshot.codex?.sevenDay,
                        fiveHourPace: codexPaceByMetric[.fiveHour],
                        weeklyPace: codexPaceByMetric[.sevenDay],
                        fillGradient: AnthropicColors.codexGradient,
                        trackColor: AnthropicColors.codexTrack
                    )
                }
            } else {
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
                                paceInfo: paceByMetric[.fiveHour]
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
                                paceInfo: paceByMetric[.sevenDay]
                            )
                        }

                        Spacer()

                        statusFooter
                    }
                }
            }
        }
        .padding(12)
    }

    private var statusFooter: some View {
        Group {
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
}

private struct WidgetProviderColumn: View {
    let title: String
    let fiveHour: UsageMetric?
    let weekly: UsageMetric?
    let fiveHourPace: PaceInfo?
    let weeklyPace: PaceInfo?
    var fillGradient: LinearGradient? = nil
    var trackColor: Color = Color.white.opacity(0.12)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(title == "Codex" ? AnthropicColors.codexBlue : AnthropicColors.tan)

            if let fiveHour {
                WidgetUsageBar(
                    label: "5-Hour",
                    percent: fiveHour.percent,
                    resetsAt: fiveHour.resetsAt,
                    paceInfo: fiveHourPace,
                    fillGradient: fillGradient,
                    trackColor: trackColor
                )
            }

            if let weekly {
                WidgetUsageBar(
                    label: "Weekly",
                    percent: weekly.percent,
                    resetsAt: weekly.resetsAt,
                    paceInfo: weeklyPace,
                    fillGradient: fillGradient,
                    trackColor: trackColor
                )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
