import SwiftUI

struct WidgetErrorView: View {
    let message: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: message != nil ? "exclamationmark.triangle" : "gauge.medium")
                .font(.system(size: 20))
                .foregroundStyle(message != nil ? AnthropicColors.coral : AnthropicColors.tan)
            Text(message ?? "Open Claude Usage Widget to get started")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }
}
