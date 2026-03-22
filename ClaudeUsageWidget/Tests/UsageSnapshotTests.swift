import XCTest
@testable import ClaudeUsageWidget

final class UsageMetricTests: XCTestCase {
    func testEncodeDecode() throws {
        let metric = UsageMetric(percent: 45.5, resetsAt: Date(timeIntervalSince1970: 1711000000))
        let data = try UsageSnapshot.makeEncoder().encode(metric)
        let decoded = try UsageSnapshot.makeDecoder().decode(UsageMetric.self, from: data)
        XCTAssertEqual(decoded.percent, 45.5)
        XCTAssertEqual(decoded.resetsAt, metric.resetsAt)
    }

    func testPercentClamped() {
        let metric = UsageMetric(percent: 150.0, resetsAt: Date())
        XCTAssertEqual(metric.clampedPercent, 100.0)

        let negative = UsageMetric(percent: -5.0, resetsAt: Date())
        XCTAssertEqual(negative.clampedPercent, 0.0)

        let normal = UsageMetric(percent: 72.3, resetsAt: Date())
        XCTAssertEqual(normal.clampedPercent, 72.3)
    }
}

final class TokenStatsTests: XCTestCase {
    func testEncodeDecode() throws {
        let stats = TokenStats(todayTokens: 15000, weekTokens: 85000, todayMessages: 42, weekMessages: 210)
        let data = try UsageSnapshot.makeEncoder().encode(stats)
        let decoded = try UsageSnapshot.makeDecoder().decode(TokenStats.self, from: data)
        XCTAssertEqual(decoded.todayTokens, 15000)
        XCTAssertEqual(decoded.weekTokens, 85000)
        XCTAssertEqual(decoded.todayMessages, 42)
        XCTAssertEqual(decoded.weekMessages, 210)
    }

    func testFormattedTokens() {
        let stats = TokenStats(todayTokens: 1_500_000, weekTokens: 42_000, todayMessages: 500, weekMessages: 3500)
        XCTAssertEqual(stats.formattedTodayTokens, "1.5M")
        XCTAssertEqual(stats.formattedWeekTokens, "42.0K")
    }

    func testFormattedTokensSmallValues() {
        let stats = TokenStats(todayTokens: 750, weekTokens: 0, todayMessages: 3, weekMessages: 10)
        XCTAssertEqual(stats.formattedTodayTokens, "750")
        XCTAssertEqual(stats.formattedWeekTokens, "0")
    }
}

final class UsageSnapshotTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 45.0, resetsAt: Date(timeIntervalSince1970: 1711000000)),
            sevenDay: UsageMetric(percent: 30.0, resetsAt: Date(timeIntervalSince1970: 1711500000)),
            sevenDaySonnet: nil,
            sevenDayOpus: UsageMetric(percent: 88.0, resetsAt: Date(timeIntervalSince1970: 1711500000)),
            tokenStats: TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50),
            lastUpdated: Date(timeIntervalSince1970: 1711000000),
            error: nil
        )
        let data = try UsageSnapshot.makeEncoder().encode(snapshot)
        let decoded = try UsageSnapshot.makeDecoder().decode(UsageSnapshot.self, from: data)
        XCTAssertEqual(decoded.fiveHour?.percent, 45.0)
        XCTAssertNil(decoded.sevenDaySonnet)
        XCTAssertEqual(decoded.sevenDayOpus?.percent, 88.0)
        XCTAssertNil(decoded.error)
    }

    func testWithError() throws {
        let snapshot = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: "API error 401: Unauthorized"
        )
        let data = try UsageSnapshot.makeEncoder().encode(snapshot)
        let decoded = try UsageSnapshot.makeDecoder().decode(UsageSnapshot.self, from: data)
        XCTAssertEqual(decoded.error, "API error 401: Unauthorized")
        XCTAssertNil(decoded.fiveHour)
    }

    func testIsStale() {
        let fresh = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: nil
        )
        XCTAssertFalse(fresh.isStale)

        let stale = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date().addingTimeInterval(-31 * 60),
            error: nil
        )
        XCTAssertTrue(stale.isStale)
    }

    // MARK: - maxUsagePercent

    func testMaxUsagePercentAllNilReturnsNil() {
        let snapshot = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: nil
        )
        XCTAssertNil(snapshot.maxUsagePercent)
    }

    func testMaxUsagePercentSingleMetricReturnsThatValue() {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 42.0, resetsAt: Date()),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: nil
        )
        XCTAssertEqual(snapshot.maxUsagePercent, 42.0)
    }

    func testMaxUsagePercentReturnsMaxAcrossMetrics() {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 30.0, resetsAt: Date()),
            sevenDay: UsageMetric(percent: 60.0, resetsAt: Date()),
            sevenDaySonnet: nil,
            sevenDayOpus: UsageMetric(percent: 88.0, resetsAt: Date()),
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: nil
        )
        XCTAssertEqual(snapshot.maxUsagePercent, 88.0)
    }

    func testMaxUsagePercentExcludesSonnet() {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 20.0, resetsAt: Date()),
            sevenDay: nil,
            sevenDaySonnet: UsageMetric(percent: 99.0, resetsAt: Date()),
            sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: nil
        )
        XCTAssertEqual(snapshot.maxUsagePercent, 20.0)
    }

    func testMaxUsagePercentSonnetOnlyReturnsNil() {
        let snapshot = UsageSnapshot(
            fiveHour: nil, sevenDay: nil,
            sevenDaySonnet: UsageMetric(percent: 80.0, resetsAt: Date()),
            sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(), error: nil
        )
        XCTAssertNil(snapshot.maxUsagePercent)
    }

    func testMaxUsagePercentClampsValues() {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 150.0, resetsAt: Date()),
            sevenDay: UsageMetric(percent: -10.0, resetsAt: Date()),
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: nil
        )
        XCTAssertEqual(snapshot.maxUsagePercent, 100.0)
    }
}
