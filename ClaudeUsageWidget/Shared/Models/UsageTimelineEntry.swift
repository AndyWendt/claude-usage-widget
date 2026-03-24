import Foundation
import WidgetKit

struct UsageTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
    var paceByMetric: [MetricKey: PaceInfo] = [:]
    var codexPaceByMetric: [MetricKey: PaceInfo] = [:]

    static func buildTimeline(from snapshot: UsageSnapshot?, paceSettings: PaceSettings = .allEnabled) -> [UsageTimelineEntry] {
        let base = snapshot ?? UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: "No data available. Open the app to refresh."
        )

        guard snapshot != nil else {
            return [UsageTimelineEntry(date: Date(), snapshot: base)]
        }

        // Generate entries every 15 minutes for the next hour
        var entries: [UsageTimelineEntry] = []
        let now = Date()
        for i in 0..<4 {
            let entryDate = now.addingTimeInterval(TimeInterval(i * 15 * 60))
            let pace = computePaceMap(metrics: claudePairs(from: base), paceSettings: paceSettings, now: entryDate)
            let codexPace = computePaceMap(metrics: codexPairs(from: base), paceSettings: paceSettings, now: entryDate)
            entries.append(UsageTimelineEntry(date: entryDate, snapshot: base, paceByMetric: pace, codexPaceByMetric: codexPace))
        }
        return entries
    }

    static func makeEntry(date: Date, snapshot: UsageSnapshot, paceSettings: PaceSettings, isPlaceholder: Bool = false) -> UsageTimelineEntry {
        guard !isPlaceholder else {
            return UsageTimelineEntry(date: date, snapshot: snapshot)
        }
        let pace = computePaceMap(metrics: claudePairs(from: snapshot), paceSettings: paceSettings, now: date)
        let codexPace = computePaceMap(metrics: codexPairs(from: snapshot), paceSettings: paceSettings, now: date)
        return UsageTimelineEntry(date: date, snapshot: snapshot, paceByMetric: pace, codexPaceByMetric: codexPace)
    }

    private static func computePaceMap(metrics: [(MetricKey, UsageMetric?)], paceSettings: PaceSettings, now: Date) -> [MetricKey: PaceInfo] {
        var map: [MetricKey: PaceInfo] = [:]
        for (key, metric) in metrics {
            guard paceSettings.enabledMetrics.contains(key), let metric else { continue }
            if let pace = computePace(metric: metric, windowDuration: key.windowDuration, now: now) {
                map[key] = pace
            }
        }
        return map
    }

    private static func claudePairs(from snapshot: UsageSnapshot) -> [(MetricKey, UsageMetric?)] {
        [
            (.fiveHour, snapshot.fiveHour),
            (.sevenDay, snapshot.sevenDay),
            (.sevenDaySonnet, snapshot.sevenDaySonnet),
            (.sevenDayOpus, snapshot.sevenDayOpus),
        ]
    }

    private static func codexPairs(from snapshot: UsageSnapshot) -> [(MetricKey, UsageMetric?)] {
        [
            (.fiveHour, snapshot.codex?.fiveHour),
            (.sevenDay, snapshot.codex?.sevenDay),
        ]
    }
}
