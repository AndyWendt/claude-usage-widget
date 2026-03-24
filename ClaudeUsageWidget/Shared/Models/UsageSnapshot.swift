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

struct ProviderUsageSnapshot: Codable, Equatable {
    let fiveHour: UsageMetric?
    let sevenDay: UsageMetric?
    let extraLabel: String?
    let extraMetric: UsageMetric?
    let tokenStats: TokenStats
    let lastUpdated: Date
    let lastSuccessfulUpdate: Date?
    let error: String?

    var hasUsageData: Bool {
        fiveHour != nil || sevenDay != nil || extraMetric != nil
    }
}

struct CompareUsageSection: Equatable {
    let title: String
    let claudeLabel: String
    let claudeMetric: UsageMetric?
    let codexLabel: String
    let codexMetric: UsageMetric?
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
    let codex: ProviderUsageSnapshot?
    let tokenStats: TokenStats
    let lastUpdated: Date
    let lastSuccessfulUpdate: Date?
    let error: String?

    init(
        fiveHour: UsageMetric?,
        sevenDay: UsageMetric?,
        sevenDaySonnet: UsageMetric?,
        sevenDayOpus: UsageMetric?,
        codex: ProviderUsageSnapshot? = nil,
        tokenStats: TokenStats,
        lastUpdated: Date,
        lastSuccessfulUpdate: Date?,
        error: String?
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.sevenDaySonnet = sevenDaySonnet
        self.sevenDayOpus = sevenDayOpus
        self.codex = codex
        self.tokenStats = tokenStats
        self.lastUpdated = lastUpdated
        self.lastSuccessfulUpdate = lastSuccessfulUpdate
        self.error = error
    }

    var maxUsagePercent: Double? {
        let values = [
            fiveHour?.clampedPercent,
            sevenDay?.clampedPercent,
            sevenDayOpus?.clampedPercent,
            codex?.fiveHour?.clampedPercent,
            codex?.sevenDay?.clampedPercent,
            codex?.extraMetric?.clampedPercent
        ].compactMap { $0 }
        return values.max()
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 30 * 60
    }

    var hasUsageData: Bool {
        fiveHour != nil || sevenDay != nil || sevenDaySonnet != nil || sevenDayOpus != nil || (codex?.hasUsageData ?? false)
    }

    var hasCodexData: Bool {
        codex?.hasUsageData ?? false
    }

    var displayTitle: String {
        hasCodexData ? "AI Usage" : "Claude Code Usage"
    }

    var compareSections: [CompareUsageSection] {
        guard let codex, codex.hasUsageData else { return [] }

        var sections = [
            CompareUsageSection(
                title: "5-Hour Window",
                claudeLabel: "Claude",
                claudeMetric: fiveHour,
                codexLabel: "Codex",
                codexMetric: codex.fiveHour
            ),
            CompareUsageSection(
                title: "Weekly",
                claudeLabel: "Claude",
                claudeMetric: sevenDay,
                codexLabel: "Codex",
                codexMetric: codex.sevenDay
            )
        ]

        if let claudeExtra = preferredClaudeExtraMetric ?? codex.extraMetric {
            sections.append(
                CompareUsageSection(
                    title: "Extra Limit",
                    claudeLabel: preferredClaudeExtraLabel,
                    claudeMetric: preferredClaudeExtraMetric,
                    codexLabel: codex.extraLabel ?? "Codex Extra",
                    codexMetric: codex.extraMetric ?? claudeExtra
                )
            )
        }

        return sections
    }

    var compareErrorMessages: [String] {
        var messages: [String] = []
        if let error {
            messages.append("Claude: \(error)")
        }
        if let codexError = codex?.error {
            messages.append("Codex: \(codexError)")
        }
        return messages
    }

    func withError(_ message: String, tokenStats: TokenStats? = nil) -> UsageSnapshot {
        UsageSnapshot(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            sevenDaySonnet: sevenDaySonnet,
            sevenDayOpus: sevenDayOpus,
            codex: codex,
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

    private var preferredClaudeExtraMetric: UsageMetric? {
        sevenDayOpus ?? sevenDaySonnet
    }

    private var preferredClaudeExtraLabel: String {
        if sevenDayOpus != nil { return "Weekly (Opus)" }
        if sevenDaySonnet != nil { return "Weekly (Sonnet)" }
        return "Claude Extra"
    }
}
