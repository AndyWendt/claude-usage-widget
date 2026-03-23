import Foundation

struct UsageMetric: Codable, Equatable {
    let percent: Double
    let resetsAt: Date

    var clampedPercent: Double {
        min(max(percent, 0.0), 100.0)
    }
}

struct TokenStats: Codable, Equatable {
    let todayTokens: Int
    let weekTokens: Int
    let todayMessages: Int
    let weekMessages: Int

    var formattedTodayTokens: String {
        Self.formatNumber(todayTokens)
    }

    var formattedWeekTokens: String {
        Self.formatNumber(weekTokens)
    }

    static func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

struct UsageSnapshot: Codable, Equatable {
    let fiveHour: UsageMetric?
    let sevenDay: UsageMetric?
    let sevenDaySonnet: UsageMetric?
    let sevenDayOpus: UsageMetric?
    let tokenStats: TokenStats
    let lastUpdated: Date
    let lastSuccessfulUpdate: Date?
    let error: String?

    var maxUsagePercent: Double? {
        let values = [fiveHour?.clampedPercent, sevenDay?.clampedPercent, sevenDayOpus?.clampedPercent].compactMap { $0 }
        return values.max()
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 30 * 60
    }

    var hasUsageData: Bool {
        fiveHour != nil || sevenDay != nil || sevenDaySonnet != nil || sevenDayOpus != nil
    }

    func withError(_ message: String, tokenStats: TokenStats? = nil) -> UsageSnapshot {
        UsageSnapshot(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            sevenDaySonnet: sevenDaySonnet,
            sevenDayOpus: sevenDayOpus,
            tokenStats: tokenStats ?? self.tokenStats,
            lastUpdated: Date(),
            lastSuccessfulUpdate: lastSuccessfulUpdate,
            error: message
        )
    }

    /// Canonical encoder — always uses iso8601 dates for interoperability
    /// between the main app and the widget extension.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Canonical decoder — always uses iso8601 dates for interoperability
    /// between the main app and the widget extension.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
