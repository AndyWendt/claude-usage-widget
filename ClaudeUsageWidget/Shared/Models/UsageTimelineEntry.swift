import Foundation
import WidgetKit

struct UsageTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot

    static func buildTimeline(from snapshot: UsageSnapshot?) -> [UsageTimelineEntry] {
        let base = snapshot ?? UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: nil
        )

        guard snapshot != nil else {
            return [UsageTimelineEntry(date: Date(), snapshot: base)]
        }

        // Generate entries every 15 minutes for the next hour
        var entries: [UsageTimelineEntry] = []
        let now = Date()
        for i in 0..<4 {
            let entryDate = now.addingTimeInterval(TimeInterval(i * 15 * 60))
            entries.append(UsageTimelineEntry(date: entryDate, snapshot: base))
        }
        return entries
    }
}
