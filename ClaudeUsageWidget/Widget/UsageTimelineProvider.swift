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
            error: nil
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageTimelineEntry) -> Void) {
        let container = SharedContainerService()
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedContainerService.appGroupID)
        timelineLog.error("[Timeline] getSnapshot containerURL: \(containerURL?.path ?? "nil", privacy: .public)")
        let snapshot = container.readSnapshot()
        timelineLog.error("[Timeline] getSnapshot readSnapshot returned: \(snapshot != nil ? "data" : "nil", privacy: .public)")
        let entry = UsageTimelineEntry(
            date: Date(),
            snapshot: snapshot ?? placeholder(in: context).snapshot
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageTimelineEntry>) -> Void) {
        let container = SharedContainerService()
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedContainerService.appGroupID)
        timelineLog.error("[Timeline] getTimeline containerURL: \(containerURL?.path ?? "nil", privacy: .public)")
        let snapshot = container.readSnapshot()
        timelineLog.error("[Timeline] getTimeline readSnapshot returned: \(snapshot != nil ? "data" : "nil", privacy: .public)")
        let entries = UsageTimelineEntry.buildTimeline(from: snapshot)

        let policy: TimelineReloadPolicy = snapshot == nil
            ? .after(Date().addingTimeInterval(5 * 60))
            : .atEnd

        completion(Timeline(entries: entries, policy: policy))
    }
}
