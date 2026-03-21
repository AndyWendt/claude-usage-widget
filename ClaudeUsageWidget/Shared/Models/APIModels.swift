import Foundation

struct UsageApiResponse: Codable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDaySonnet: UsageWindow?
    let sevenDayOpus: UsageWindow?

    func toSnapshot(tokenStats: TokenStats) -> UsageSnapshot {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        func parseDate(_ s: String) -> Date {
            isoFormatter.date(from: s) ?? ISO8601DateFormatter().date(from: s) ?? Date()
        }

        return UsageSnapshot(
            fiveHour: fiveHour.map { UsageMetric(percent: $0.utilization, resetsAt: parseDate($0.resetsAt)) },
            sevenDay: sevenDay.map { UsageMetric(percent: $0.utilization, resetsAt: parseDate($0.resetsAt)) },
            sevenDaySonnet: sevenDaySonnet.map { UsageMetric(percent: $0.utilization, resetsAt: parseDate($0.resetsAt)) },
            sevenDayOpus: sevenDayOpus.map { UsageMetric(percent: $0.utilization, resetsAt: parseDate($0.resetsAt)) },
            tokenStats: tokenStats,
            lastUpdated: Date(),
            error: nil
        )
    }
}

struct UsageWindow: Codable {
    let utilization: Double
    let resetsAt: String
}

// MARK: - Local Stats Cache

struct StatsCache: Codable {
    let dailyActivity: [DailyActivity]?
    let dailyModelTokens: [DailyTokens]?
    let lastComputedDate: String?
}

struct DailyActivity: Codable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
}

struct DailyTokens: Codable {
    let date: String
    let tokensByModel: [String: Int]
}
