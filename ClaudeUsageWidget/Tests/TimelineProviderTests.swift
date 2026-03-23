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
}
