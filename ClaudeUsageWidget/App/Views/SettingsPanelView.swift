import SwiftUI

struct SettingsPanelView: View {
    @ObservedObject var manager: UsageManager
    let onBack: () -> Void
    let onOpenDebugger: () -> Void
    var onIntervalChanged: ((Int) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView {
                SettingsView(
                    manager: manager,
                    onIntervalChanged: onIntervalChanged,
                    onOpenDebugger: onOpenDebugger
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnthropicColors.tan)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)

            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
