import XCTest
@testable import ClaudeUsageWidget

final class StatsServiceTests: XCTestCase {

    func testCalculateTokenStatsFromCache() {
        let today = Self.dateString(daysAgo: 0)
        let yesterday = Self.dateString(daysAgo: 1)
        let twoWeeksAgo = Self.dateString(daysAgo: 14)

        let cache = StatsCache(
            dailyActivity: [
                DailyActivity(date: today, messageCount: 42, sessionCount: 5, toolCallCount: 120),
                DailyActivity(date: yesterday, messageCount: 30, sessionCount: 3, toolCallCount: 80),
                DailyActivity(date: twoWeeksAgo, messageCount: 100, sessionCount: 10, toolCallCount: 300)
            ],
            dailyModelTokens: [
                DailyTokens(date: today, tokensByModel: ["claude-sonnet": 10000, "claude-opus": 5000]),
                DailyTokens(date: yesterday, tokensByModel: ["claude-sonnet": 8000]),
                DailyTokens(date: twoWeeksAgo, tokensByModel: ["claude-sonnet": 50000])
            ],
            lastComputedDate: today
        )

        let stats = StatsService.calculateTokenStats(from: cache)

        XCTAssertEqual(stats.todayTokens, 15000)    // 10000 + 5000
        XCTAssertEqual(stats.weekTokens, 23000)      // 15000 + 8000 (twoWeeksAgo excluded)
        XCTAssertEqual(stats.todayMessages, 42)
        XCTAssertEqual(stats.weekMessages, 72)        // 42 + 30 (twoWeeksAgo excluded)
    }

    func testCalculateTokenStatsEmptyCache() {
        let cache = StatsCache(dailyActivity: nil, dailyModelTokens: nil, lastComputedDate: nil)
        let stats = StatsService.calculateTokenStats(from: cache)

        XCTAssertEqual(stats.todayTokens, 0)
        XCTAssertEqual(stats.weekTokens, 0)
        XCTAssertEqual(stats.todayMessages, 0)
        XCTAssertEqual(stats.weekMessages, 0)
    }

    func testReadStatsFromFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let today = Self.dateString(daysAgo: 0)
        let json = """
        {
            "dailyActivity": [{"date": "\(today)", "messageCount": 10, "sessionCount": 1, "toolCallCount": 5}],
            "dailyModelTokens": [{"date": "\(today)", "tokensByModel": {"claude-sonnet": 3000}}]
        }
        """
        let filePath = tmpDir.appendingPathComponent("stats-cache.json")
        try json.write(to: filePath, atomically: true, encoding: .utf8)

        let service = StatsService(statsFilePath: filePath.path)
        let stats = service.readStats()
        XCTAssertEqual(stats.todayTokens, 3000)
        XCTAssertEqual(stats.todayMessages, 10)
    }

    func testReadStatsMissingFile() {
        let service = StatsService(statsFilePath: "/nonexistent/path/stats-cache.json")
        let stats = service.readStats()

        XCTAssertEqual(stats.todayTokens, 0)
        XCTAssertEqual(stats.weekTokens, 0)
    }

    private static func dateString(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
    }
}
