import SwiftUI

@main
struct ClaudeUsageWidgetApp: App {
    @StateObject private var manager = UsageManager()
    @AppStorage("refreshInterval") private var refreshInterval: Int = 300

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                manager: manager,
                refreshInterval: $refreshInterval
            )
        } label: {
            let image = manager.iconTier.menuBarImage()
            Image(nsImage: image)
                .accessibilityLabel(manager.iconTier.accessibilityLabel)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Wrapper view needed because Scene modifiers like .onAppear, .onChange, .onOpenURL
/// are View-level modifiers — they must live inside the MenuBarExtra content, not on the Scene.
struct MenuBarContentView: View {
    @ObservedObject var manager: UsageManager
    @Binding var refreshInterval: Int

    var body: some View {
        VStack(spacing: 0) {
            PopoverView(manager: manager, onRefresh: { await manager.refresh() })

            Divider()
                .background(AnthropicColors.tan.opacity(0.2))

            SettingsView(onIntervalChanged: { interval in
                manager.startTimer(interval: TimeInterval(interval))
            })
        }
        .frame(width: 260)
        .background(AnthropicColors.charcoal.opacity(0.95))
        .task {
            manager.startTimer(interval: TimeInterval(refreshInterval))
            await manager.refresh()
        }
        .onOpenURL { url in
            // Handle claudeusage://open — app is already activated by macOS
            if url.scheme == "claudeusage" {
                Task { await manager.refresh() }
            }
        }
    }
}
