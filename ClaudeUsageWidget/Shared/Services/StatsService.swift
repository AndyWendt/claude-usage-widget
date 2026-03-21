import Foundation

final class StatsService: StatsServiceProtocol {
    private let statsFilePath: String

    init(statsFilePath: String? = nil) {
        if let path = statsFilePath {
            self.statsFilePath = path
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.statsFilePath = home.appendingPathComponent(".claude/stats-cache.json").path
        }
    }

    func readStats() -> TokenStats {
        guard let data = FileManager.default.contents(atPath: statsFilePath),
              let cache = try? JSONDecoder().decode(StatsCache.self, from: data) else {
            return TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0)
        }
        return Self.calculateTokenStats(from: cache)
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
}
