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

    func testBuildTimelinePreComputesCodexPaceInfo() {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 22.0, resetsAt: Date().addingTimeInterval(2 * 3600)),
            sevenDay: UsageMetric(percent: 32.0, resetsAt: Date().addingTimeInterval(4 * 86400)),
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            codex: ProviderUsageSnapshot(
                fiveHour: UsageMetric(percent: 12.0, resetsAt: Date().addingTimeInterval(2 * 3600)),
                sevenDay: UsageMetric(percent: 18.0, resetsAt: Date().addingTimeInterval(4 * 86400)),
                extraLabel: nil,
                extraMetric: nil,
                tokenStats: .zero,
                lastUpdated: Date(),
                lastSuccessfulUpdate: nil,
                error: nil
            ),
            tokenStats: .zero,
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: nil
        )

        let entries = UsageTimelineEntry.buildTimeline(from: snapshot)

        let first = entries.first!
        XCTAssertNotNil(first.codexPaceByMetric[.fiveHour], "Codex fiveHour pace should be pre-computed in the entry")
        XCTAssertNotNil(first.codexPaceByMetric[.sevenDay], "Codex sevenDay pace should be pre-computed in the entry")
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
        XCTAssertTrue(first.codexPaceByMetric.isEmpty, "No Codex pace data when snapshot is nil")
    }

    func testBuildTimelinePaceAccuracyMatchesComputePace() {
        let now = Date()
        let resetsAt = now.addingTimeInterval(2 * 3600)
        let fiveHour = UsageMetric(percent: 22.0, resetsAt: resetsAt)
        let snapshot = UsageSnapshot(
            fiveHour: fiveHour,
            sevenDay: nil,
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: now,
            lastSuccessfulUpdate: nil,
            error: nil
        )

        let entry = UsageTimelineEntry.makeEntry(date: now, snapshot: snapshot, paceSettings: .allEnabled)
        let entryPace = entry.paceByMetric[.fiveHour]
        let directPace = computePace(metric: fiveHour, windowDuration: MetricKey.fiveHour.windowDuration, now: now)

        XCTAssertNotNil(entryPace)
        XCTAssertNotNil(directPace)
        XCTAssertEqual(entryPace!.projectedPercent, directPace!.projectedPercent, accuracy: 0.01)
        XCTAssertEqual(entryPace!.status, directPace!.status)
    }

    func testGetSnapshotPlaceholderHasNoPace() {
        // When there's no real snapshot, the placeholder fallback should not show pace
        let entry = UsageTimelineEntry.makeEntry(date: Date(), snapshot: UsageSnapshot(
            fiveHour: UsageMetric(percent: 45.0, resetsAt: Date().addingTimeInterval(3600)),
            sevenDay: UsageMetric(percent: 30.0, resetsAt: Date().addingTimeInterval(86400)),
            sevenDaySonnet: UsageMetric(percent: 22.0, resetsAt: Date().addingTimeInterval(86400)),
            sevenDayOpus: UsageMetric(percent: 15.0, resetsAt: Date().addingTimeInterval(86400)),
            tokenStats: TokenStats(todayTokens: 12000, weekTokens: 85000, todayMessages: 25, weekMessages: 150),
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: nil
        ), paceSettings: .allEnabled, isPlaceholder: true)

        XCTAssertTrue(entry.paceByMetric.isEmpty, "Placeholder entries should not show pace indicators")
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
