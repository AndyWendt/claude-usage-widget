import XCTest
import SQLite3
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

        let service = StatsService(
            statsFilePath: filePath.path,
            projectsDirectoryPath: tmpDir.appendingPathComponent("missing-projects").path
        )
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
            sessionMetaDirectoryPath: tmpDir.path,
            projectsDirectoryPath: tmpDir.appendingPathComponent("missing-projects").path
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
            sessionMetaDirectoryPath: sessionMetaDir.path,
            projectsDirectoryPath: tmpDir.appendingPathComponent("missing-projects").path
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
            sessionMetaDirectoryPath: sessionMetaDir.path,
            projectsDirectoryPath: tmpDir.appendingPathComponent("missing-projects").path
        )
        let stats = service.readStats()

        XCTAssertEqual(stats.todayTokens, 0)
        XCTAssertEqual(stats.weekTokens, 1000)
        XCTAssertEqual(stats.weekMessages, 5)
    }

    func testReadStatsPrefersTranscriptLogsAndMatchesCcusageAggregation() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectsDir = tmpDir.appendingPathComponent("projects")
        let projectSessionDir = projectsDir
            .appendingPathComponent("demo-project")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: projectSessionDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let cachePath = tmpDir.appendingPathComponent("stats-cache.json")
        try """
        {
            "lastComputedDate": "\(Self.dateString(daysAgo: 0))",
            "dailyActivity": [{"date": "\(Self.dateString(daysAgo: 0))", "messageCount": 999, "sessionCount": 1, "toolCallCount": 1}],
            "dailyModelTokens": [{"date": "\(Self.dateString(daysAgo: 0))", "tokensByModel": {"claude-opus": 999999}}]
        }
        """.write(to: cachePath, atomically: true, encoding: .utf8)

        let transcriptURL = projectSessionDir.appendingPathComponent("usage.jsonl")
        try Self.writeTranscriptEntries(
            to: transcriptURL,
            entries: [
                .init(
                    timestamp: Self.isoDate(daysAgo: 0, fractionalSeconds: true),
                    requestId: "req-1",
                    messageId: "msg-1",
                    inputTokens: 10,
                    outputTokens: 20,
                    cacheCreationInputTokens: 30,
                    cacheReadInputTokens: 40
                ),
                .init(
                    timestamp: Self.isoDate(daysAgo: 0, fractionalSeconds: true),
                    requestId: "req-1",
                    messageId: "msg-1",
                    inputTokens: 10,
                    outputTokens: 20,
                    cacheCreationInputTokens: 30,
                    cacheReadInputTokens: 40
                ),
                .init(
                    timestamp: Self.isoDate(daysAgo: 0, fractionalSeconds: false),
                    requestId: nil,
                    messageId: "msg-without-request",
                    inputTokens: 5,
                    outputTokens: 10,
                    cacheCreationInputTokens: 15,
                    cacheReadInputTokens: 20
                ),
                .init(
                    timestamp: Self.isoDate(daysAgo: 1, fractionalSeconds: false),
                    requestId: "req-2",
                    messageId: "msg-2",
                    inputTokens: 5,
                    outputTokens: 6,
                    cacheCreationInputTokens: 7,
                    cacheReadInputTokens: 8
                ),
                .init(
                    timestamp: Self.isoDate(daysAgo: 8, fractionalSeconds: false),
                    requestId: "req-old",
                    messageId: "msg-old",
                    inputTokens: 500,
                    outputTokens: 400,
                    cacheCreationInputTokens: 300,
                    cacheReadInputTokens: 200
                )
            ]
        )

        let service = StatsService(
            statsFilePath: cachePath.path,
            sessionMetaDirectoryPath: tmpDir.appendingPathComponent("missing-session-meta").path,
            projectsDirectoryPath: projectsDir.path
        )

        let stats = service.readStats()

        XCTAssertEqual(stats.todayTokens, 150)
        XCTAssertEqual(stats.weekTokens, 176)
        XCTAssertEqual(stats.todayMessages, 2)
        XCTAssertEqual(stats.weekMessages, 3)
    }

    func testReadStatsFallsBackToCacheWhenTranscriptDirectoryHasNoValidEntries() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectsDir = tmpDir.appendingPathComponent("projects")
        let projectSessionDir = projectsDir
            .appendingPathComponent("demo-project")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: projectSessionDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let cachePath = tmpDir.appendingPathComponent("stats-cache.json")
        let today = Self.dateString(daysAgo: 0)
        try """
        {
            "lastComputedDate": "\(today)",
            "dailyActivity": [{"date": "\(today)", "messageCount": 12, "sessionCount": 1, "toolCallCount": 4}],
            "dailyModelTokens": [{"date": "\(today)", "tokensByModel": {"claude-sonnet": 3456}}]
        }
        """.write(to: cachePath, atomically: true, encoding: .utf8)

        try "not valid json\n{}\n".write(
            to: projectSessionDir.appendingPathComponent("usage.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let service = StatsService(
            statsFilePath: cachePath.path,
            sessionMetaDirectoryPath: tmpDir.appendingPathComponent("missing-session-meta").path,
            projectsDirectoryPath: projectsDir.path
        )

        let stats = service.readStats()

        XCTAssertEqual(stats.todayTokens, 3456)
        XCTAssertEqual(stats.weekTokens, 3456)
        XCTAssertEqual(stats.todayMessages, 12)
        XCTAssertEqual(stats.weekMessages, 12)
    }

    func testCodexStatsServiceReadsSQLiteTotals() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbURL = tmpDir.appendingPathComponent("state.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        XCTAssertEqual(
            sqlite3_exec(
                db,
                """
                CREATE TABLE threads (
                    id TEXT PRIMARY KEY,
                    rollout_path TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL,
                    source TEXT NOT NULL,
                    model_provider TEXT NOT NULL,
                    cwd TEXT NOT NULL,
                    title TEXT NOT NULL,
                    sandbox_policy TEXT NOT NULL,
                    approval_mode TEXT NOT NULL,
                    tokens_used INTEGER NOT NULL DEFAULT 0,
                    has_user_event INTEGER NOT NULL DEFAULT 0,
                    archived INTEGER NOT NULL DEFAULT 0
                );
                """,
                nil,
                nil,
                nil
            ),
            SQLITE_OK
        )

        let now = Int(Date().timeIntervalSince1970)
        let threeDaysAgo = now - (3 * 24 * 3600)
        let tenDaysAgo = now - (10 * 24 * 3600)

        XCTAssertEqual(
            sqlite3_exec(
                db,
                """
                INSERT INTO threads (id, rollout_path, created_at, updated_at, source, model_provider, cwd, title, sandbox_policy, approval_mode, tokens_used, has_user_event, archived) VALUES
                ('today', '/tmp/today.jsonl', \(now), \(now), 'cli', 'openai', '/tmp', 'Today', 'workspace-write', 'never', 1200, 1, 0),
                ('week', '/tmp/week.jsonl', \(threeDaysAgo), \(threeDaysAgo), 'cli', 'openai', '/tmp', 'Week', 'workspace-write', 'never', 800, 1, 0),
                ('old', '/tmp/old.jsonl', \(tenDaysAgo), \(tenDaysAgo), 'cli', 'openai', '/tmp', 'Old', 'workspace-write', 'never', 4000, 1, 0),
                ('other-provider', '/tmp/other.jsonl', \(now), \(now), 'cli', 'anthropic', '/tmp', 'Other', 'workspace-write', 'never', 9999, 1, 0);
                """,
                nil,
                nil,
                nil
            ),
            SQLITE_OK
        )

        let service = CodexStatsService(databasePath: dbURL.path)
        let stats = service.readStats()

        XCTAssertEqual(stats.todayTokens, 1200)
        XCTAssertEqual(stats.weekTokens, 2000)
        XCTAssertEqual(stats.todayMessages, 1)
        XCTAssertEqual(stats.weekMessages, 2)
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

    private static func isoDate(daysAgo: Int, fractionalSeconds: Bool) -> String {
        let formatter = ISO8601DateFormatter()
        if fractionalSeconds {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        }
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return formatter.string(from: date)
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

    private static func writeTranscriptEntries(to url: URL, entries: [TranscriptFixture]) throws {
        let lines = entries.map { entry in
            var fields = [
                "\"timestamp\":\"\(entry.timestamp)\"",
                "\"message\":{\"usage\":{\"input_tokens\":\(entry.inputTokens),\"output_tokens\":\(entry.outputTokens),\"cache_creation_input_tokens\":\(entry.cacheCreationInputTokens),\"cache_read_input_tokens\":\(entry.cacheReadInputTokens)}"
            ]

            if let messageId = entry.messageId {
                fields[1].append(",\"id\":\"\(messageId)\"")
            }
            fields[1].append("}")

            if let requestId = entry.requestId {
                fields.append("\"requestId\":\"\(requestId)\"")
            }

            return "{\(fields.joined(separator: ","))}"
        }

        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}

private struct TranscriptFixture {
    let timestamp: String
    let requestId: String?
    let messageId: String?
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int
}
