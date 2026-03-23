import SwiftUI

struct UsageBarView: View {
    let label: String
    let metric: UsageMetric?
    var isOpus: Bool = false
    var paceInfo: PaceInfo? = nil
    var showPace: Bool = true

    var body: some View {
        if let metric {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AnthropicColors.creamMuted)

                    Spacer()

                    Text("\(Int(metric.clampedPercent))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AnthropicColors.cream)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AnthropicColors.tan.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(gradient(for: metric.clampedPercent))
                            .frame(width: geo.size.width * metric.clampedPercent / 100)
                            .opacity(metric.clampedPercent >= 90 ? pulseOpacity : 1.0)
                            .onAppear {
                                if metric.clampedPercent >= 90 {
                                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                        pulseOpacity = 0.7
                                    }
                                }
                            }

                        if showPace, let pace = paceInfo {
                            let clampedPosition = min(max(pace.projectedPercent, 0), 100)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(paceColor(for: pace.status))
                                .opacity(0.7)
                                .frame(width: 2, height: 14)
                                .offset(x: geo.size.width * clampedPosition / 100 - 1, y: -3)
                        }
                    }
                }
                .frame(height: 8)

                if showPace, let pace = paceInfo {
                    HStack {
                        ResetTimerView(resetsAt: metric.resetsAt)
                        Spacer()
                        Text(pace.projectedPercent > 100 ? "→ 100%+" : "→ \(Int(min(pace.projectedPercent, 100)))%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(paceColor(for: pace.status))
                    }
                } else {
                    ResetTimerView(resetsAt: metric.resetsAt)
                }
            }
        }
    }

    @State private var pulseOpacity: Double = 1.0

    private func gradient(for percent: Double) -> LinearGradient {
        if percent >= 90 {
            return AnthropicColors.dangerGradient
        } else if percent >= 70 {
            return AnthropicColors.warningGradient
        } else if isOpus {
            return AnthropicColors.opusGradient
        } else {
            return AnthropicColors.normalGradient
        }
    }

    private func paceColor(for status: PaceStatus) -> Color {
        switch status {
        case .under: return AnthropicColors.paceGreen
        case .on: return AnthropicColors.paceYellow
        case .over: return AnthropicColors.coral
        }
    }
}
