import SwiftUI

struct PopoverView: View {
    @ObservedObject var manager: UsageManager
    let onRefresh: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if manager.isLoading && manager.snapshot == nil {
                loadingView
            } else if let snapshot = manager.snapshot {
                contentView(snapshot)
            } else {
                emptyView
            }
        }
        .frame(width: 260, height: 400)
        .background(AnthropicColors.charcoal.opacity(0.95))
    }

    private var headerView: some View {
        HStack {
            Text("Claude Code Usage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)
            Spacer()
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
        ScrollView {
            VStack(spacing: 10) {
                UsageBarView(label: "5-Hour Window", metric: snapshot.fiveHour)
                UsageBarView(label: "Weekly (All Models)", metric: snapshot.sevenDay)
                UsageBarView(label: "Weekly (Sonnet)", metric: snapshot.sevenDaySonnet)
                UsageBarView(label: "Weekly (Opus)", metric: snapshot.sevenDayOpus, isOpus: true)

                divider

                TokenStatsView(stats: snapshot.tokenStats)

                if let error = snapshot.error {
                    errorBanner(error)
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
}
