import Foundation

enum MetricKey: String, Codable, CaseIterable {
    case fiveHour, sevenDay, sevenDaySonnet, sevenDayOpus

    var windowDuration: TimeInterval {
        switch self {
        case .fiveHour: return 5 * 3600
        case .sevenDay, .sevenDaySonnet, .sevenDayOpus: return 7 * 24 * 3600
        }
    }
}

enum PaceStatus: Equatable {
    case under, on, over
}

struct PaceInfo: Equatable {
    let projectedPercent: Double
    let status: PaceStatus
    var clampedProjectedPercent: Double { min(max(projectedPercent, 0), 100) }
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
    let enabledMetrics: Set<MetricKey>

    static let allEnabled = PaceSettings(enabledMetrics: Set(MetricKey.allCases))
}

func computePace(metric: UsageMetric, windowDuration: TimeInterval, now: Date = .init()) -> PaceInfo? {
    guard windowDuration > 0 else { return nil }

    let windowStart = metric.resetsAt.addingTimeInterval(-windowDuration)
    let elapsed = now.timeIntervalSince(windowStart)
    let fractionElapsed = elapsed / windowDuration

    guard fractionElapsed >= 0.05, fractionElapsed < 1.0 else {
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
