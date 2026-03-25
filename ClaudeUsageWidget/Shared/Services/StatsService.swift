import Foundation
import SQLite3

final class StatsService: StatsServiceProtocol {
    private let statsFilePath: String
    private let sessionMetaDirectoryPath: String
    private let projectsDirectoryPath: String
    private let transcriptCacheLock = NSLock()
    private var cachedTranscriptState: CachedTranscriptState?

    init(statsFilePath: String? = nil, sessionMetaDirectoryPath: String? = nil, projectsDirectoryPath: String? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser

        if let path = statsFilePath {
            self.statsFilePath = path
        } else {
            self.statsFilePath = home.appendingPathComponent(".claude/stats-cache.json").path
        }

        if let path = sessionMetaDirectoryPath {
            self.sessionMetaDirectoryPath = path
        } else {
            self.sessionMetaDirectoryPath = home
                .appendingPathComponent(".claude/usage-data/session-meta")
                .path
        }

        if let path = projectsDirectoryPath {
            self.projectsDirectoryPath = path
        } else {
            self.projectsDirectoryPath = home
                .appendingPathComponent(".claude/projects")
                .path
        }
    }

    func readStats() -> TokenStats {
        if let transcriptStats = readTranscriptStats() {
            return transcriptStats
        }

        guard let data = FileManager.default.contents(atPath: statsFilePath),
              let cache = try? JSONDecoder().decode(StatsCache.self, from: data) else {
            return readSessionMetaStats() ?? TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0)
        }

        let cacheStats = Self.calculateTokenStats(from: cache)
        if Self.cacheIncludesCurrentWeek(cache) {
            return cacheStats
        }

        return readSessionMetaStats() ?? cacheStats
    }

    static func calculateTokenStats(from cache: StatsCache) -> TokenStats {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let weekAgo = formatter.string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!)

        var todayTokens = 0
        var weekTokens = 0
        var todayMessages = 0
        var weekMessages = 0

        if let dailyTokens = cache.dailyModelTokens {
            for day in dailyTokens {
                let dayTotal = day.tokensByModel.values.reduce(0, +)
                if day.date == today { todayTokens = dayTotal }
                if day.date >= weekAgo { weekTokens += dayTotal }
            }
        }

        if let dailyActivity = cache.dailyActivity {
            for day in dailyActivity {
                if day.date == today { todayMessages = day.messageCount }
                if day.date >= weekAgo { weekMessages += day.messageCount }
            }
        }

        return TokenStats(
            todayTokens: todayTokens,
            weekTokens: weekTokens,
            todayMessages: todayMessages,
            weekMessages: weekMessages
        )
    }

    private func readTranscriptStats() -> TokenStats? {
        let fileManager = FileManager.default
        let projectsURL = URL(fileURLWithPath: projectsDirectoryPath, isDirectory: true)
        guard fileManager.fileExists(atPath: projectsDirectoryPath) else {
            return nil
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday

        guard let enumerator = fileManager.enumerator(
            at: projectsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var transcriptFiles: [TranscriptFile] = []
        var fingerprint = Hasher()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try Self.decodeISO8601Date(from: decoder)
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }

            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }

            if let modifiedAt = values?.contentModificationDate, modifiedAt < startOfWeek {
                continue
            }

            let modifiedAt = values?.contentModificationDate ?? .distantPast
            let fileSize = values?.fileSize ?? 0
            transcriptFiles.append(TranscriptFile(url: fileURL))
            fingerprint.combine(fileURL.path)
            fingerprint.combine(fileSize)
            fingerprint.combine(Int(modifiedAt.timeIntervalSinceReferenceDate))
        }

        fingerprint.combine(transcriptFiles.count)
        let fingerprintValue = fingerprint.finalize()

        if let cachedEntry = cachedTranscriptEntry(for: fingerprintValue) {
            return cachedEntry.stats
        }

        var todayTokens = 0
        var weekTokens = 0
        var todayMessages = 0
        var weekMessages = 0
        var processedHashes = Set<String>()
        var foundTranscriptEntry = false

        for transcriptFile in transcriptFiles {
            guard let contents = try? String(contentsOf: transcriptFile.url, encoding: .utf8) else { continue }

            for line in contents.split(whereSeparator: \.isNewline) {
                guard let data = String(line).data(using: .utf8),
                      let entry = try? decoder.decode(TranscriptUsageEntry.self, from: data) else {
                    continue
                }

                if let uniqueHash = Self.uniqueHash(for: entry),
                   !processedHashes.insert(uniqueHash).inserted {
                    continue
                }

                foundTranscriptEntry = true

                let usage = entry.message.usage
                let tokenTotal =
                    max(0, usage.inputTokens) +
                    max(0, usage.outputTokens) +
                    max(0, usage.cacheCreationInputTokens ?? 0) +
                    max(0, usage.cacheReadInputTokens ?? 0)

                if entry.timestamp >= startOfToday {
                    todayTokens += tokenTotal
                    todayMessages += 1
                }

                if entry.timestamp >= startOfWeek {
                    weekTokens += tokenTotal
                    weekMessages += 1
                }
            }
        }

        let stats = foundTranscriptEntry ? TokenStats(
            todayTokens: todayTokens,
            weekTokens: weekTokens,
            todayMessages: todayMessages,
            weekMessages: weekMessages
        ) : nil

        cacheTranscriptStats(stats, fingerprint: fingerprintValue)
        return stats
    }

    private func cachedTranscriptEntry(for fingerprint: Int) -> CachedTranscriptState? {
        transcriptCacheLock.lock()
        defer { transcriptCacheLock.unlock() }
        guard let cachedTranscriptState, cachedTranscriptState.fingerprint == fingerprint else {
            return nil
        }
        return cachedTranscriptState
    }

    private func cacheTranscriptStats(_ stats: TokenStats?, fingerprint: Int) {
        transcriptCacheLock.lock()
        cachedTranscriptState = CachedTranscriptState(fingerprint: fingerprint, stats: stats)
        transcriptCacheLock.unlock()
    }
}

private struct CachedTranscriptState {
    let fingerprint: Int
    let stats: TokenStats?
}

private struct TranscriptFile {
    let url: URL
}

extension StatsService {
    private func readSessionMetaStats() -> TokenStats? {
        let fileManager = FileManager.default
        guard let fileNames = try? fileManager.contentsOfDirectory(atPath: sessionMetaDirectoryPath) else {
            return nil
        }

        let formatter = Self.dayFormatter()
        let today = formatter.string(from: Date())
        let weekAgo = formatter.string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var todayTokens = 0
        var weekTokens = 0
        var todayMessages = 0
        var weekMessages = 0
        var foundSession = false

        for fileName in fileNames where fileName.hasSuffix(".json") {
            let fileURL = URL(fileURLWithPath: sessionMetaDirectoryPath).appendingPathComponent(fileName)
            guard let rawData = try? Data(contentsOf: fileURL) else { continue }

            // Some session-meta files contain trailing NUL bytes; strip them before decoding.
            let sanitizedData = Data(rawData.filter { $0 != 0 })
            guard let session = try? decoder.decode(SessionMeta.self, from: sanitizedData) else { continue }

            foundSession = true

            let sessionDay = formatter.string(from: session.startTime)
            let tokenTotal = max(0, session.inputTokens) + max(0, session.outputTokens)
            let messageTotal = max(0, session.userMessageCount) + max(0, session.assistantMessageCount)

            if sessionDay == today {
                todayTokens += tokenTotal
                todayMessages += messageTotal
            }
            if sessionDay >= weekAgo {
                weekTokens += tokenTotal
                weekMessages += messageTotal
            }
        }

        guard foundSession else { return nil }

        return TokenStats(
            todayTokens: todayTokens,
            weekTokens: weekTokens,
            todayMessages: todayMessages,
            weekMessages: weekMessages
        )
    }

    private static func cacheIncludesCurrentWeek(_ cache: StatsCache) -> Bool {
        let formatter = dayFormatter()
        let weekAgo = formatter.string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!)

        let mostRecentDate = (
            (cache.dailyActivity ?? []).map(\.date) +
            (cache.dailyModelTokens ?? []).map(\.date) +
            [cache.lastComputedDate].compactMap { $0 }
        ).max()

        guard let mostRecentDate else { return false }
        return mostRecentDate >= weekAgo
    }

    private static func dayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func uniqueHash(for entry: TranscriptUsageEntry) -> String? {
        guard let messageID = entry.message.id, let requestID = entry.requestId else {
            return nil
        }

        return "\(messageID):\(requestID)"
    }

    private static func decodeISO8601Date(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let date = fractionalISO8601Formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
    }

    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

final class CodexStatsService: StatsServiceProtocol {
    private let databasePath: String

    init(databasePath: String? = nil) {
        if let databasePath {
            self.databasePath = databasePath
        } else {
            self.databasePath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex/state_5.sqlite")
                .path
        }
    }

    func readStats() -> TokenStats {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            if db != nil {
                sqlite3_close(db)
            }
            return .zero
        }
        defer { sqlite3_close(db) }

        let calendar = Calendar.current
        let startOfToday = Int(calendar.startOfDay(for: Date()).timeIntervalSince1970)
        let startOfWeek = Int(
            calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: Date()))?
                .timeIntervalSince1970 ?? 0
        )

        return TokenStats(
            todayTokens: queryInt(db, sql: "SELECT COALESCE(SUM(tokens_used), 0) FROM threads WHERE model_provider = 'openai' AND created_at >= ?", threshold: startOfToday),
            weekTokens: queryInt(db, sql: "SELECT COALESCE(SUM(tokens_used), 0) FROM threads WHERE model_provider = 'openai' AND created_at >= ?", threshold: startOfWeek),
            todayMessages: queryInt(db, sql: "SELECT COUNT(*) FROM threads WHERE model_provider = 'openai' AND created_at >= ?", threshold: startOfToday),
            weekMessages: queryInt(db, sql: "SELECT COUNT(*) FROM threads WHERE model_provider = 'openai' AND created_at >= ?", threshold: startOfWeek)
        )
    }

    private func queryInt(_ db: OpaquePointer, sql: String, threshold: Int) -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            if statement != nil {
                sqlite3_finalize(statement)
            }
            return 0
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, sqlite3_int64(threshold))
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }
        return Int(sqlite3_column_int64(statement, 0))
    }
}

private struct SessionMeta: Decodable {
    let startTime: Date
    let inputTokens: Int
    let outputTokens: Int
    let userMessageCount: Int
    let assistantMessageCount: Int

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case userMessageCount = "user_message_count"
        case assistantMessageCount = "assistant_message_count"
    }
}

private struct TranscriptUsageEntry: Decodable {
    let timestamp: Date
    let requestId: String?
    let message: TranscriptMessage
}

private struct TranscriptMessage: Decodable {
    let usage: TranscriptTokenUsage
    let id: String?
}

private struct TranscriptTokenUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}
