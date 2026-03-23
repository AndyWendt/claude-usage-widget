import XCTest
@testable import ClaudeUsageWidget

final class APIModelsTests: XCTestCase {

    func testDecodeFullResponse() throws {
        let json = """
        {
            "five_hour": {"utilization": 45.5, "resets_at": "2026-03-21T18:00:00Z"},
            "seven_day": {"utilization": 30.0, "resets_at": "2026-03-25T00:00:00Z"},
            "seven_day_sonnet": {"utilization": 22.0, "resets_at": "2026-03-25T00:00:00Z"},
            "seven_day_opus": {"utilization": 88.0, "resets_at": "2026-03-25T00:00:00Z"}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(UsageApiResponse.self, from: json)

        XCTAssertEqual(response.fiveHour?.utilization, 45.5)
        XCTAssertEqual(response.sevenDay?.utilization, 30.0)
        XCTAssertEqual(response.sevenDaySonnet?.utilization, 22.0)
        XCTAssertEqual(response.sevenDayOpus?.utilization, 88.0)
    }

    func testDecodePartialResponse() throws {
        let json = """
        {
            "five_hour": {"utilization": 10.0, "resets_at": "2026-03-21T18:00:00Z"}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(UsageApiResponse.self, from: json)

        XCTAssertEqual(response.fiveHour?.utilization, 10.0)
        XCTAssertNil(response.sevenDay)
        XCTAssertNil(response.sevenDaySonnet)
        XCTAssertNil(response.sevenDayOpus)
    }

    func testDecodeStatsCacheJson() throws {
        let json = """
        {
            "dailyActivity": [
                {"date": "2026-03-21", "messageCount": 42, "sessionCount": 5, "toolCallCount": 120},
                {"date": "2026-03-20", "messageCount": 30, "sessionCount": 3, "toolCallCount": 80}
            ],
            "dailyModelTokens": [
                {"date": "2026-03-21", "tokensByModel": {"claude-sonnet": 10000, "claude-opus": 5000}},
                {"date": "2026-03-20", "tokensByModel": {"claude-sonnet": 8000}}
            ],
            "lastComputedDate": "2026-03-21"
        }
        """.data(using: .utf8)!

        let cache = try JSONDecoder().decode(StatsCache.self, from: json)

        XCTAssertEqual(cache.dailyActivity?.count, 2)
        XCTAssertEqual(cache.dailyActivity?.first?.messageCount, 42)
        XCTAssertEqual(cache.dailyModelTokens?.first?.tokensByModel["claude-sonnet"], 10000)
    }

    func testDecodeEmptyStatsCache() throws {
        let json = "{}".data(using: .utf8)!
        let cache = try JSONDecoder().decode(StatsCache.self, from: json)
        XCTAssertNil(cache.dailyActivity)
        XCTAssertNil(cache.dailyModelTokens)
    }

    func testToUsageSnapshot() {
        let response = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 45.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: UsageWindow(utilization: 30.0, resetsAt: "2026-03-25T00:00:00Z"),
            sevenDaySonnet: nil,
            sevenDayOpus: nil
        )
        let stats = TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50)
        let snapshot = response.toSnapshot(tokenStats: stats)

        XCTAssertEqual(snapshot.fiveHour?.percent, 45.0)
        XCTAssertEqual(snapshot.sevenDay?.percent, 30.0)
        XCTAssertNil(snapshot.sevenDaySonnet)
        XCTAssertNil(snapshot.error)
    }

    func testToSnapshotSetsLastSuccessfulUpdate() {
        let response = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 45.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        let stats = TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0)
        let beforeCall = Date()
        let snapshot = response.toSnapshot(tokenStats: stats)
        let afterCall = Date()

        XCTAssertNotNil(snapshot.lastSuccessfulUpdate)
        XCTAssertGreaterThanOrEqual(snapshot.lastSuccessfulUpdate!, beforeCall)
        XCTAssertLessThanOrEqual(snapshot.lastSuccessfulUpdate!, afterCall)
        XCTAssertNil(snapshot.error)
    }
}
