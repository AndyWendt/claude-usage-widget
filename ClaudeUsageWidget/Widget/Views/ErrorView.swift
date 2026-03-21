import SwiftUI

struct WidgetErrorView: View {
    let message: String?

    /// True when the message represents an actual error vs a "no data yet" prompt.
    private var isError: Bool {
        guard let message else { return false }
        return !message.starts(with: "No data")
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle" : "gauge.medium")
                .font(.system(size: 20))
                .foregroundStyle(isError ? AnthropicColors.coral : AnthropicColors.tan)
            Text(message ?? "Open Claude Usage Widget to get started")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }
}
