import SwiftUI

struct WidgetPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Claude Usage")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(height: 8)
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(height: 8)
        }
        .padding(12)
        .redacted(reason: .placeholder)
    }
}
