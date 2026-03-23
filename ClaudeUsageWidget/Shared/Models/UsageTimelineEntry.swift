import Foundation
import WidgetKit

struct UsageTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
    let paceSettings: PaceSettings

    static func buildTimeline(from snapshot: UsageSnapshot?, paceSettings: PaceSettings = .allEnabled) -> [UsageTimelineEntry] {
        let base = snapshot ?? UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: "No data available. Open the app to refresh."
        )

        guard snapshot != nil else {
            return [UsageTimelineEntry(date: Date(), snapshot: base, paceSettings: paceSettings)]
        }

        // Generate entries every 15 minutes for the next hour
        var entries: [UsageTimelineEntry] = []
        let now = Date()
        for i in 0..<4 {
            let entryDate = now.addingTimeInterval(TimeInterval(i * 15 * 60))
            entries.append(UsageTimelineEntry(date: entryDate, snapshot: base, paceSettings: paceSettings))
        }
        return entries
    }
}
