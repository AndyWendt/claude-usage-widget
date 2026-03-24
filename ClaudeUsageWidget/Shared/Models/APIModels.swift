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
            lastSuccessfulUpdate: Date(),
            error: nil
        )
    }
}

struct UsageWindow: Codable {
    let utilization: Double
    let resetsAt: String
}

struct CodexAuthCredentials: Equatable {
    let accessToken: String
    let accountID: String
}

struct CodexUsageResponse: Codable {
    let rateLimit: CodexRateLimitEnvelope
    let codeReviewRateLimit: CodexRateLimitEnvelope?
    let additionalRateLimits: [CodexAdditionalRateLimit]?

    func toProviderSnapshot(tokenStats: TokenStats, now: Date = Date()) -> ProviderUsageSnapshot {
        let extra = preferredExtraLimit()

        return ProviderUsageSnapshot(
            fiveHour: makeMetric(from: rateLimit.primaryWindow),
            sevenDay: makeMetric(from: rateLimit.secondaryWindow),
            extraLabel: extra?.label,
            extraMetric: extra?.metric,
            tokenStats: tokenStats,
            lastUpdated: now,
            lastSuccessfulUpdate: now,
            error: nil
        )
    }

    private func preferredExtraLimit() -> (label: String, metric: UsageMetric)? {
        if let additional = (additionalRateLimits ?? []).lazy.compactMap({ limit -> (String, UsageMetric)? in
            guard let metric = makeMetric(from: limit.rateLimit.primaryWindow) ?? makeMetric(from: limit.rateLimit.secondaryWindow) else {
                return nil
            }
            return (limit.limitName, metric)
        }).first {
            return additional
        }

        if let codeReviewMetric = makeMetric(from: codeReviewRateLimit?.primaryWindow) ?? makeMetric(from: codeReviewRateLimit?.secondaryWindow) {
            return ("Code Review", codeReviewMetric)
        }

        return nil
    }

    private func makeMetric(from window: CodexRateWindow?) -> UsageMetric? {
        guard let window else { return nil }
        return UsageMetric(
            percent: window.usedPercent,
            resetsAt: Date(timeIntervalSince1970: window.resetAt)
        )
    }
}

struct CodexRateLimitEnvelope: Codable {
    let allowed: Bool?
    let limitReached: Bool?
    let primaryWindow: CodexRateWindow?
    let secondaryWindow: CodexRateWindow?
}

struct CodexRateWindow: Codable {
    let usedPercent: Double
    let limitWindowSeconds: Int
    let resetAfterSeconds: Int
    let resetAt: TimeInterval
}

struct CodexAdditionalRateLimit: Codable {
    let limitName: String
    let meteredFeature: String
    let rateLimit: CodexRateLimitEnvelope
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
