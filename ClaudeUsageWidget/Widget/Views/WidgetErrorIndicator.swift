import SwiftUI

struct WidgetErrorIndicator: View {
    let snapshot: UsageSnapshot

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(AnthropicColors.coral)
            if let lastSuccess = snapshot.lastSuccessfulUpdate {
                Text(lastSuccess, style: .relative)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
