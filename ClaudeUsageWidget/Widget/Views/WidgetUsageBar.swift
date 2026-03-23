import SwiftUI

struct WidgetUsageBar: View {
    let label: String
    let percent: Double
    let resetsAt: Date
    var isOpus: Bool = false
    var paceInfo: PaceInfo? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(min(max(percent, 0), 100)))%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gradient)
                        .frame(width: geo.size.width * min(max(percent, 0), 100) / 100)

                    if let pace = paceInfo {
                        let fillPercent = min(max(percent, 0), 100)
                        let projPercent = pace.clampedProjectedPercent
                        let baseX = geo.size.width * projPercent / 100
                        let nudge: CGFloat = abs(projPercent - fillPercent) < 3
                            ? (projPercent > fillPercent ? 4 : -4)
                            : 0
                        let markerX = max(0, min(baseX + nudge, geo.size.width))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AnthropicColors.paceColor(for: pace.status))
                            .opacity(0.7)
                            .frame(width: 2, height: 10)
                            .offset(x: markerX - 1, y: -2)
                    }
                }
            }
            .frame(height: 6)

            if let pace = paceInfo {
                HStack {
                    Text(resetsAt, style: .relative)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(pace.projectedPercent > 100 ? "→ 100%+" : "→ \(Int(min(pace.projectedPercent, 100)))%")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AnthropicColors.paceColor(for: pace.status))
                }
            } else {
                Text(resetsAt, style: .relative)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var gradient: LinearGradient {
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

}
