import SwiftUI

struct PopoverView: View {
    @ObservedObject var manager: UsageManager
    let onRefresh: () async -> Void
    @State private var showDebugLogs = false
    @State private var debugLogText = ""

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if showDebugLogs {
                debugLogView
            } else if manager.isLoading && manager.snapshot == nil {
                loadingView
            } else if let snapshot = manager.snapshot {
                contentView(snapshot)
            } else {
                emptyView
            }
        }
        .frame(width: showDebugLogs ? 500 : 260, height: showDebugLogs ? 600 : 400)
        .background(AnthropicColors.charcoal.opacity(0.95))
    }

    private var headerView: some View {
        HStack {
            Text("Claude Code Usage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)
            Spacer()
            Button(action: {
                showDebugLogs.toggle()
                if showDebugLogs {
                    debugLogText = DebugLogger.shared.readLogs()
                }
            }) {
                Image(systemName: showDebugLogs ? "ladybug.fill" : "ladybug")
                    .font(.system(size: 11))
                    .foregroundStyle(showDebugLogs ? AnthropicColors.coral : AnthropicColors.tan.opacity(0.5))
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            Button(action: { Task { await onRefresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(AnthropicColors.tan)
                    .rotationEffect(.degrees(manager.isLoading ? 360 : 0))
                    .animation(manager.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isLoading)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .background(AnthropicColors.tan.opacity(0.15))
            .cornerRadius(6)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .font(.system(size: 11))
                .foregroundStyle(AnthropicColors.creamMuted)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            Text("Click refresh to load usage data")
                .font(.system(size: 11))
                .foregroundStyle(AnthropicColors.creamMuted)
            Spacer()
        }
    }

    private func contentView(_ snapshot: UsageSnapshot) -> some View {
        let paceSettings = manager.paceSettings

        return ScrollView {
            VStack(spacing: 10) {
                UsageBarView(
                    label: "5-Hour Window",
                    metric: snapshot.fiveHour,
                    paceInfo: paceSettings.enabledMetrics.contains(.fiveHour)
                        ? snapshot.fiveHour.flatMap { computePace(metric: $0, windowDuration: MetricKey.fiveHour.windowDuration) }
                        : nil
                )
                UsageBarView(
                    label: "Weekly (All Models)",
                    metric: snapshot.sevenDay,
                    paceInfo: paceSettings.enabledMetrics.contains(.sevenDay)
                        ? snapshot.sevenDay.flatMap { computePace(metric: $0, windowDuration: MetricKey.sevenDay.windowDuration) }
                        : nil
                )
                UsageBarView(
                    label: "Weekly (Sonnet)",
                    metric: snapshot.sevenDaySonnet,
                    paceInfo: paceSettings.enabledMetrics.contains(.sevenDaySonnet)
                        ? snapshot.sevenDaySonnet.flatMap { computePace(metric: $0, windowDuration: MetricKey.sevenDaySonnet.windowDuration) }
                        : nil
                )
                UsageBarView(
                    label: "Weekly (Opus)",
                    metric: snapshot.sevenDayOpus,
                    isOpus: true,
                    paceInfo: paceSettings.enabledMetrics.contains(.sevenDayOpus)
                        ? snapshot.sevenDayOpus.flatMap { computePace(metric: $0, windowDuration: MetricKey.sevenDayOpus.windowDuration) }
                        : nil
                )

                divider

                TokenStatsView(stats: snapshot.tokenStats)

                if let error = snapshot.error {
                    errorBanner(error)
                    if let lastSuccess = snapshot.lastSuccessfulUpdate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(lastSuccess, style: .relative)
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(AnthropicColors.creamMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, AnthropicColors.tan.opacity(0.3), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(AnthropicColors.coral)
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(AnthropicColors.coral)
                .lineLimit(2)
        }
        .padding(8)
        .background(AnthropicColors.coral.opacity(0.1))
        .cornerRadius(6)
    }

    private var debugLogView: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Refresh Logs") {
                    debugLogText = DebugLogger.shared.readLogs()
                }
                .font(.system(size: 10))
                Button("Run Diagnostics") {
                    DebugLogger.shared.dumpContainerDiagnostics(source: "App-Manual")
                    debugLogText = DebugLogger.shared.readLogs()
                }
                .font(.system(size: 10))
                Button("Clear") {
                    DebugLogger.shared.clearLogs()
                    debugLogText = ""
                }
                .font(.system(size: 10))
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(debugLogText, forType: .string)
                }
                .font(.system(size: 10))
            }
            .padding(.horizontal, 10)

            ScrollView {
                Text(debugLogText.isEmpty ? "(no logs — tap Refresh or Run Diagnostics)" : debugLogText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(AnthropicColors.cream)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        }
        .padding(.top, 4)
    }
}
