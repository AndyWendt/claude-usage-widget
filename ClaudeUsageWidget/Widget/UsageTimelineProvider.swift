import Foundation
import WidgetKit

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
        let snapshot = container.readSnapshot()
        let entry = UsageTimelineEntry(
            date: Date(),
            snapshot: snapshot ?? placeholder(in: context).snapshot
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageTimelineEntry>) -> Void) {
        let container = SharedContainerService()
        let snapshot = container.readSnapshot()
        let entries = UsageTimelineEntry.buildTimeline(from: snapshot)
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
