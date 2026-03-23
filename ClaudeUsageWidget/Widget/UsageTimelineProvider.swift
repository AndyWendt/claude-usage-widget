import Foundation
import WidgetKit
import os.log

private let timelineLog = Logger(subsystem: "com.andywendt.claude-usage-widget.widget", category: "Timeline")

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageTimelineEntry {
        UsageTimelineEntry(date: Date(), snapshot: UsageSnapshot(
            fiveHour: UsageMetric(percent: 45.0, resetsAt: Date().addingTimeInterval(3600)),
            sevenDay: UsageMetric(percent: 30.0, resetsAt: Date().addingTimeInterval(86400)),
            sevenDaySonnet: UsageMetric(percent: 22.0, resetsAt: Date().addingTimeInterval(86400)),
            sevenDayOpus: UsageMetric(percent: 15.0, resetsAt: Date().addingTimeInterval(86400)),
            tokenStats: TokenStats(todayTokens: 12000, weekTokens: 85000, todayMessages: 25, weekMessages: 150),
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: nil
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageTimelineEntry) -> Void) {
        let debug = DebugLogger.shared
        debug.log("getSnapshot called (isPreview: \(context.isPreview))", source: "Widget")
        debug.dumpContainerDiagnostics(source: "Widget-getSnapshot")

        let container = SharedContainerService()
        let snapshot = container.readSnapshot()
        debug.log("getSnapshot result: \(snapshot != nil ? "got data" : "nil → using placeholder")", source: "Widget")

        let entry = UsageTimelineEntry(
            date: Date(),
            snapshot: snapshot ?? placeholder(in: context).snapshot
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageTimelineEntry>) -> Void) {
        let debug = DebugLogger.shared
        debug.log("getTimeline called", source: "Widget")
        debug.dumpContainerDiagnostics(source: "Widget-getTimeline")

        let container = SharedContainerService()
        let snapshot = container.readSnapshot()

        let entries = UsageTimelineEntry.buildTimeline(from: snapshot)
        debug.log("getTimeline: \(entries.count) entries, snapshot=\(snapshot != nil ? "present" : "nil")", source: "Widget")

        let policy: TimelineReloadPolicy = snapshot == nil
            ? .after(Date().addingTimeInterval(5 * 60))
            : .atEnd

        debug.log("getTimeline reload policy: \(snapshot == nil ? "retry in 5min" : "atEnd")", source: "Widget")
        completion(Timeline(entries: entries, policy: policy))
    }
}
