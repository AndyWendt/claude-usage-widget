import Foundation

enum PaceStatus: Equatable {
    case under, on, over
}

struct PaceInfo: Equatable {
    let projectedPercent: Double
    let status: PaceStatus
}

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

struct PaceSettings: Codable, Equatable {
    let enabledMetrics: Set<String>

    static let allEnabled = PaceSettings(enabledMetrics: [
        "fiveHour", "sevenDay", "sevenDaySonnet", "sevenDayOpus"
    ])
}

func computePace(metric: UsageMetric, windowDuration: TimeInterval, now: Date = .init()) -> PaceInfo? {
    let windowStart = metric.resetsAt.addingTimeInterval(-windowDuration)
    let elapsed = now.timeIntervalSince(windowStart)
    let fractionElapsed = elapsed / windowDuration

    guard fractionElapsed >= 0.05, fractionElapsed < 1.0, fractionElapsed > 0.0 else {
        return nil
    }

    let projectedPercent = metric.percent / fractionElapsed
    let expectedPercent = fractionElapsed * 100

    let status: PaceStatus
    if projectedPercent < expectedPercent - 5 {
        status = .under
    } else if projectedPercent > expectedPercent + 5 {
        status = .over
    } else {
        status = .on
    }

    return PaceInfo(projectedPercent: projectedPercent, status: status)
}

struct UsageSnapshot: Codable, Equatable {
    let fiveHour: UsageMetric?
    let sevenDay: UsageMetric?
    let sevenDaySonnet: UsageMetric?
    let sevenDayOpus: UsageMetric?
    let tokenStats: TokenStats
    let lastUpdated: Date
    let error: String?

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 30 * 60
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
