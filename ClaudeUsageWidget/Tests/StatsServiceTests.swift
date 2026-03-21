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
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let service = StatsService(
            statsFilePath: "/nonexistent/path/stats-cache.json",
            sessionMetaDirectoryPath: tmpDir.path
        )
        let stats = service.readStats()

        XCTAssertEqual(stats.todayTokens, 0)
        XCTAssertEqual(stats.weekTokens, 0)
    }

    func testReadStatsFallsBackToSessionMetaWhenCacheIsStale() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessionMetaDir = tmpDir.appendingPathComponent("session-meta")
        try FileManager.default.createDirectory(at: sessionMetaDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let staleDate = Self.dateString(daysAgo: 20)
        let staleCache = """
        {
            "lastComputedDate": "\(staleDate)",
            "dailyActivity": [{"date": "\(staleDate)", "messageCount": 10, "sessionCount": 1, "toolCallCount": 5}],
            "dailyModelTokens": [{"date": "\(staleDate)", "tokensByModel": {"claude-sonnet": 3000}}]
        }
        """
        let cachePath = tmpDir.appendingPathComponent("stats-cache.json")
        try staleCache.write(to: cachePath, atomically: true, encoding: .utf8)

        try Self.writeSessionMeta(
            to: sessionMetaDir.appendingPathComponent("today.json"),
            startTime: Self.isoDate(daysAgo: 0),
            inputTokens: 1200,
            outputTokens: 300,
            userMessages: 2,
            assistantMessages: 5
        )
        try Self.writeSessionMeta(
            to: sessionMetaDir.appendingPathComponent("this-week.json"),
            startTime: Self.isoDate(daysAgo: 3),
            inputTokens: 400,
            outputTokens: 100,
            userMessages: 1,
            assistantMessages: 2
        )
        try Self.writeSessionMeta(
            to: sessionMetaDir.appendingPathComponent("old.json"),
            startTime: Self.isoDate(daysAgo: 14),
            inputTokens: 9999,
            outputTokens: 1,
            userMessages: 50,
            assistantMessages: 50
        )

        let service = StatsService(
            statsFilePath: cachePath.path,
            sessionMetaDirectoryPath: sessionMetaDir.path
        )
        let stats = service.readStats()

        XCTAssertEqual(stats.todayTokens, 1500)
        XCTAssertEqual(stats.weekTokens, 2000)
        XCTAssertEqual(stats.todayMessages, 7)
        XCTAssertEqual(stats.weekMessages, 10)
    }

    func testReadStatsMissingFileFallsBackToSessionMeta() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessionMetaDir = tmpDir.appendingPathComponent("session-meta")
        try FileManager.default.createDirectory(at: sessionMetaDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try Self.writeSessionMeta(
            to: sessionMetaDir.appendingPathComponent("recent.json"),
            startTime: Self.isoDate(daysAgo: 1),
            inputTokens: 700,
            outputTokens: 300,
            userMessages: 1,
            assistantMessages: 4
        )

        let service = StatsService(
            statsFilePath: tmpDir.appendingPathComponent("missing.json").path,
            sessionMetaDirectoryPath: sessionMetaDir.path
        )
        let stats = service.readStats()

        XCTAssertEqual(stats.todayTokens, 0)
        XCTAssertEqual(stats.weekTokens, 1000)
        XCTAssertEqual(stats.weekMessages, 5)
    }

    private static func dateString(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
    }

    private static func isoDate(daysAgo: Int) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
    }

    private static func writeSessionMeta(
        to url: URL,
        startTime: String,
        inputTokens: Int,
        outputTokens: Int,
        userMessages: Int,
        assistantMessages: Int
    ) throws {
        let json = """
        {
            "session_id": "\(UUID().uuidString)",
            "start_time": "\(startTime)",
            "input_tokens": \(inputTokens),
            "output_tokens": \(outputTokens),
            "user_message_count": \(userMessages),
            "assistant_message_count": \(assistantMessages)
        }
        """
        try json.write(to: url, atomically: true, encoding: .utf8)
    }
}
