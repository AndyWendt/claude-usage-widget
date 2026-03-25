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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigation = MenuBarNavigation()

    var body: some View {
        currentPanel
        .frame(width: navigation.panel.size.width, height: navigation.panel.size.height)
        .background(AnthropicColors.charcoal.opacity(0.95))
        .animation(.easeInOut(duration: 0.15), value: navigation.panel)
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
        .onChange(of: scenePhase) { _, newPhase in
            if MenuBarClosePolicy.shouldDismiss(for: newPhase) {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var currentPanel: some View {
        switch navigation.panel {
        case .usage:
            PopoverView(
                manager: manager,
                onRefresh: { await manager.refresh() },
                onOpenSettings: { navigation.openSettings() }
            )
        case .settings:
            SettingsPanelView(
                manager: manager,
                onBack: { navigation.goBack() },
                onOpenDebugger: { navigation.openDebugger() },
                onIntervalChanged: { interval in
                    manager.startTimer(interval: TimeInterval(interval))
                }
            )
        case .debugger:
            DebugLogView(onBack: { navigation.goBack() })
        }
    }
}

enum MenuBarClosePolicy {
    static func shouldDismiss(for scenePhase: ScenePhase) -> Bool {
        switch scenePhase {
        case .active:
            false
        case .inactive, .background:
            true
        @unknown default:
            true
        }
    }
}
