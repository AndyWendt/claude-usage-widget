import SwiftUI

struct LargeWidgetView: View {
    let snapshot: UsageSnapshot
    let paceByMetric: [MetricKey: PaceInfo]
    let codexPaceByMetric: [MetricKey: PaceInfo]

    var body: some View {
        Group {
            if snapshot.hasCodexData {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI Usage")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AnthropicColors.tan)

                    HStack(alignment: .top, spacing: 14) {
                        WidgetProviderSection(
                            title: "Claude",
                            primaryLabel: "5-Hour Window",
                            primaryMetric: snapshot.fiveHour,
                            weeklyLabel: "Weekly",
                            weeklyMetric: snapshot.sevenDay,
                            extraLabel: snapshot.sevenDayOpus != nil ? "Weekly (Opus)" : "Weekly (Sonnet)",
                            extraMetric: snapshot.sevenDayOpus ?? snapshot.sevenDaySonnet,
                            primaryPace: paceByMetric[.fiveHour],
                            weeklyPace: paceByMetric[.sevenDay],
                            extraPace: snapshot.sevenDayOpus != nil ? paceByMetric[.sevenDayOpus] : paceByMetric[.sevenDaySonnet]
                        )

                        WidgetProviderSection(
                            title: "Codex",
                            primaryLabel: "5-Hour Window",
                            primaryMetric: snapshot.codex?.fiveHour,
                            weeklyLabel: "Weekly",
                            weeklyMetric: snapshot.codex?.sevenDay,
                            extraLabel: snapshot.codex?.extraLabel,
                            extraMetric: snapshot.codex?.extraMetric,
                            primaryPace: codexPaceByMetric[.fiveHour],
                            weeklyPace: codexPaceByMetric[.sevenDay],
                            extraPace: nil,
                            fillGradient: AnthropicColors.codexGradient,
                            trackColor: AnthropicColors.codexTrack
                        )
                    }

                    Divider()

                    HStack {
                        WidgetTokenColumn(title: "Claude", stats: snapshot.tokenStats)
                        WidgetTokenColumn(title: "Codex", stats: snapshot.codex?.tokenStats ?? .zero)
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
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude Code Usage")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AnthropicColors.tan)

                    if let fiveHour = snapshot.fiveHour {
                        WidgetUsageBar(
                            label: "5-Hour Window",
                            percent: fiveHour.percent,
                            resetsAt: fiveHour.resetsAt,
                            paceInfo: paceByMetric[.fiveHour]
                        )
                    }
                    if let sevenDay = snapshot.sevenDay {
                        WidgetUsageBar(
                            label: "Weekly (All)",
                            percent: sevenDay.percent,
                            resetsAt: sevenDay.resetsAt,
                            paceInfo: paceByMetric[.sevenDay]
                        )
                    }
                    if let sonnet = snapshot.sevenDaySonnet {
                        WidgetUsageBar(
                            label: "Weekly (Sonnet)",
                            percent: sonnet.percent,
                            resetsAt: sonnet.resetsAt,
                            paceInfo: paceByMetric[.sevenDaySonnet]
                        )
                    }
                    if let opus = snapshot.sevenDayOpus {
                        WidgetUsageBar(
                            label: "Weekly (Opus)",
                            percent: opus.percent,
                            resetsAt: opus.resetsAt,
                            isOpus: true,
                            paceInfo: paceByMetric[.sevenDayOpus]
                        )
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
            }
        }
        .padding(14)
    }
}

private struct WidgetProviderSection: View {
    let title: String
    let primaryLabel: String
    let primaryMetric: UsageMetric?
    let weeklyLabel: String
    let weeklyMetric: UsageMetric?
    let extraLabel: String?
    let extraMetric: UsageMetric?
    let primaryPace: PaceInfo?
    let weeklyPace: PaceInfo?
    let extraPace: PaceInfo?
    var fillGradient: LinearGradient? = nil
    var trackColor: Color = Color.white.opacity(0.12)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(title == "Codex" ? AnthropicColors.codexBlue : AnthropicColors.tan)

            if let primaryMetric {
                WidgetUsageBar(
                    label: primaryLabel,
                    percent: primaryMetric.percent,
                    resetsAt: primaryMetric.resetsAt,
                    paceInfo: primaryPace,
                    fillGradient: fillGradient,
                    trackColor: trackColor
                )
            }

            if let weeklyMetric {
                WidgetUsageBar(
                    label: weeklyLabel,
                    percent: weeklyMetric.percent,
                    resetsAt: weeklyMetric.resetsAt,
                    paceInfo: weeklyPace,
                    fillGradient: fillGradient,
                    trackColor: trackColor
                )
            }

            if let extraLabel, let extraMetric {
                WidgetUsageBar(
                    label: extraLabel,
                    percent: extraMetric.percent,
                    resetsAt: extraMetric.resetsAt,
                    paceInfo: extraPace,
                    fillGradient: fillGradient,
                    trackColor: trackColor
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetTokenColumn: View {
    let title: String
    let stats: TokenStats

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(stats.formattedTodayTokens)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            Text(stats.formattedWeekTokens)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
