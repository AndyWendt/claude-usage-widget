import SwiftUI

@main
struct ClaudeUsageWidgetApp: App {
    var body: some Scene {
        MenuBarExtra("Claude Usage", systemImage: "gauge.medium") {
            Text("Loading...")
        }
        .menuBarExtraStyle(.window)
    }
}
