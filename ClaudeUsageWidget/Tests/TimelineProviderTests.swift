import XCTest
@testable import ClaudeUsageWidget

final class TimelineProviderTests: XCTestCase {

    func testBuildTimelineFromSnapshot() {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 45.0, resetsAt: Date().addingTimeInterval(3600)),
            sevenDay: UsageMetric(percent: 30.0, resetsAt: Date().addingTimeInterval(86400)),
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50),
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: nil
        )

        let entries = UsageTimelineEntry.buildTimeline(from: snapshot)

        // Should have entries spaced 15 minutes apart
        XCTAssertGreaterThanOrEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.snapshot.fiveHour?.percent, 45.0)

        // Verify 15-minute spacing
        if entries.count >= 2 {
            let interval = entries[1].date.timeIntervalSince(entries[0].date)
            XCTAssertEqual(interval, 15 * 60, accuracy: 1)
        }
    }

    func testBuildTimelineWithNoSnapshot() {
        let entries = UsageTimelineEntry.buildTimeline(from: nil)

        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries.first?.snapshot.fiveHour)
        XCTAssertNotNil(entries.first?.snapshot.error, "Nil snapshot should produce an error message for the widget")
        XCTAssertTrue(entries.first!.snapshot.error!.contains("No data"))
    }

    func testEntryIsStale() {
        let staleSnapshot = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date().addingTimeInterval(-31 * 60),
            lastSuccessfulUpdate: nil,
            error: nil
        )
        let entry = UsageTimelineEntry(date: Date(), snapshot: staleSnapshot)
        XCTAssertTrue(entry.snapshot.isStale)
    }

    // MARK: - Pre-computed pace in timeline entries

    func testBuildTimelinePreComputesPaceInfo() {
        // 5-hour window: resetsAt in 2h → 3h elapsed of 5h → fractionElapsed = 0.6
        // percent = 22 → projected = 22/0.6 ≈ 36.7%
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 22.0, resetsAt: Date().addingTimeInterval(2 * 3600)),
            sevenDay: UsageMetric(percent: 32.0, resetsAt: Date().addingTimeInterval(4 * 86400)),
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: nil
        )

        let entries = UsageTimelineEntry.buildTimeline(from: snapshot)

        let first = entries.first!
        XCTAssertNotNil(first.paceByMetric[.fiveHour], "fiveHour pace should be pre-computed in the entry")
        XCTAssertNotNil(first.paceByMetric[.sevenDay], "sevenDay pace should be pre-computed in the entry")
    }

    func testBuildTimelineRespectsDisabledPaceSettings() {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 22.0, resetsAt: Date().addingTimeInterval(2 * 3600)),
            sevenDay: UsageMetric(percent: 32.0, resetsAt: Date().addingTimeInterval(4 * 86400)),
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: nil
        )

        let paceSettings = PaceSettings(enabledMetrics: [.sevenDay])
        let entries = UsageTimelineEntry.buildTimeline(from: snapshot, paceSettings: paceSettings)

        let first = entries.first!
        XCTAssertNil(first.paceByMetric[.fiveHour], "fiveHour pace should be nil when disabled")
        XCTAssertNotNil(first.paceByMetric[.sevenDay], "sevenDay pace should be present when enabled")
    }

    func testBuildTimelineNilSnapshotHasEmptyPace() {
        let entries = UsageTimelineEntry.buildTimeline(from: nil)

        let first = entries.first!
        XCTAssertTrue(first.paceByMetric.isEmpty, "No pace data when snapshot is nil")
    }

    func testBuildTimelinePaceAccuracyMatchesComputePace() {
        let resetsAt = Date().addingTimeInterval(2 * 3600)
        let fiveHour = UsageMetric(percent: 22.0, resetsAt: resetsAt)
        let snapshot = UsageSnapshot(
            fiveHour: fiveHour,
            sevenDay: nil,
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: nil
        )

        let entries = UsageTimelineEntry.buildTimeline(from: snapshot)
        let entryPace = entries.first!.paceByMetric[.fiveHour]
        let directPace = computePace(metric: fiveHour, windowDuration: MetricKey.fiveHour.windowDuration)

        // Both should produce equivalent results (computed at ~same time)
        XCTAssertNotNil(entryPace)
        XCTAssertNotNil(directPace)
        XCTAssertEqual(entryPace!.projectedPercent, directPace!.projectedPercent, accuracy: 1.0)
        XCTAssertEqual(entryPace!.status, directPace!.status)
    }

    func testMakeEntryPreComputesPace() {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 30.0, resetsAt: Date().addingTimeInterval(2 * 3600)),
            sevenDay: nil,
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: nil
        )

        let entry = UsageTimelineEntry.makeEntry(date: Date(), snapshot: snapshot, paceSettings: .allEnabled)

        XCTAssertNotNil(entry.paceByMetric[.fiveHour])
    }
}
