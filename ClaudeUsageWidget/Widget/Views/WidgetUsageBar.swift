import SwiftUI

struct WidgetUsageBar: View {
    let label: String
    let percent: Double
    let resetsAt: Date
    var isOpus: Bool = false

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
                }
            }
            .frame(height: 6)

            Text(resetsAt, style: .relative)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
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
