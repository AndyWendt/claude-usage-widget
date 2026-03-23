import SwiftUI
import WidgetKit

@main
struct ClaudeUsageWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        UsageWidget()
    }
}

struct UsageWidget: Widget {
    let kind = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            Group {
                if entry.snapshot.error != nil && !entry.snapshot.hasUsageData {
                    WidgetErrorView(message: entry.snapshot.error)
                } else {
                    WidgetContentView(entry: entry)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "claudeusage://open"))
        }
        .configurationDisplayName("Claude Usage")
        .description("Monitor your Claude Code usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetContentView: View {
    @Environment(\.widgetFamily) var family
    let entry: UsageTimelineEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(snapshot: entry.snapshot, paceSettings: entry.paceSettings)
        case .systemMedium:
            MediumWidgetView(snapshot: entry.snapshot, paceSettings: entry.paceSettings)
        case .systemLarge:
            LargeWidgetView(snapshot: entry.snapshot, paceSettings: entry.paceSettings)
        default:
            SmallWidgetView(snapshot: entry.snapshot, paceSettings: entry.paceSettings)
        }
    }
}
