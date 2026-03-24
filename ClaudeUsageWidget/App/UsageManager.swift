import Foundation
import WidgetKit

@MainActor
final class UsageManager: ObservableObject {
    @Published var snapshot: UsageSnapshot? {
        didSet {
            if let percent = snapshot?.maxUsagePercent {
                iconTier = MenuBarIconTier.from(percent: percent)
            } else {
                iconTier = .idle
            }
        }
    }
    @Published var iconTier: MenuBarIconTier = .idle
    @Published var isLoading = false
    @Published var paceSettings: PaceSettings = .allEnabled

    private let keychainService: KeychainServiceProtocol
    private let apiService: APIServiceProtocol
    private let statsService: StatsServiceProtocol
    private let codexAuthService: CodexAuthServiceProtocol
    private let codexAPIService: CodexAPIServiceProtocol
    private let codexStatsService: StatsServiceProtocol
    private let containerService: SharedContainerServiceProtocol
    private let widgetReloader: () -> Void
    private var cachedToken: String?
    private var timer: Timer?

    init(
        keychainService: KeychainServiceProtocol = KeychainService(),
        apiService: APIServiceProtocol = APIService(),
        statsService: StatsServiceProtocol = StatsService(),
        codexAuthService: CodexAuthServiceProtocol = CodexAuthService(),
        codexAPIService: CodexAPIServiceProtocol = CodexAPIService(),
        codexStatsService: StatsServiceProtocol = CodexStatsService(),
        containerService: SharedContainerServiceProtocol = SharedContainerService(),
        widgetReloader: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsageWidget") }
    ) {
        self.keychainService = keychainService
        self.apiService = apiService
        self.statsService = statsService
        self.codexAuthService = codexAuthService
        self.codexAPIService = codexAPIService
        self.codexStatsService = codexStatsService
        self.containerService = containerService
        self.widgetReloader = widgetReloader
        self.paceSettings = containerService.readPaceSettings()
    }

    func updatePaceSettings(_ settings: PaceSettings) {
        paceSettings = settings
        do {
            try containerService.writePaceSettings(settings)
        } catch {
            DebugLogger.shared.log("PACE WRITE FAILED: \(error)", source: "App")
        }
        widgetReloader()
    }

    func startTimer(interval: TimeInterval = 300) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() async {
        let debug = DebugLogger.shared
        debug.log("refresh() started", source: "App")
        debug.dumpContainerDiagnostics(source: "App-refresh")

        isLoading = true
        defer { isLoading = false }

        let existing = snapshot ?? containerService.readSnapshot()
        let claudeStats = statsService.readStats()
        let codexStats = codexStatsService.readStats()
        debug.log("Stats: todayTokens=\(claudeStats.todayTokens), weekTokens=\(claudeStats.weekTokens)", source: "App")
        debug.log("Codex stats: todayTokens=\(codexStats.todayTokens), weekTokens=\(codexStats.weekTokens)", source: "App")

        let claudeResult = await refreshClaude(existing: existing, stats: claudeStats)
        let codexResult = await refreshCodex(existing: existing?.codex, stats: codexStats)

        let mergedSnapshot = mergeSnapshots(claude: claudeResult.snapshot, codex: codexResult.snapshot)
        snapshot = mergedSnapshot

        if claudeResult.shouldPersist || codexResult.shouldPersist {
            do {
                try containerService.writeSnapshot(mergedSnapshot)
                debug.log("Snapshot written to shared container", source: "App")
            } catch {
                debug.log("WRITE FAILED: \(error)", source: "App")
            }
            widgetReloader()
            debug.log("Widget reload requested", source: "App")
        }
    }

    private func handleError(_ msg: String, stats: TokenStats, source: String, existing: UsageSnapshot?) -> ClaudeRefreshResult {
        let debug = DebugLogger.shared
        if let existing, existing.hasUsageData {
            return ClaudeRefreshResult(snapshot: existing.withError(msg, tokenStats: stats), shouldPersist: true)
        } else {
            return ClaudeRefreshResult(snapshot: UsageSnapshot(
                fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
                codex: existing?.codex,
                tokenStats: stats,
                lastUpdated: Date(),
                lastSuccessfulUpdate: nil,
                error: msg
            ), shouldPersist: false)
        }
    }

    private func describeError(_ error: Error) -> String {
        switch error {
        case KeychainError.notFound:
            return "No credentials found. Please sign in to Claude Code first."
        case KeychainError.accessDenied:
            return "Keychain access denied. Please allow access when prompted."
        case KeychainError.invalidData(let msg):
            return "Invalid credentials: \(msg)"
        case APIError.unauthorized:
            return "Authentication failed. Token may have expired."
        case APIError.forbidden:
            return "Access forbidden."
        case APIError.serverError(let code):
            return "Server error (\(code))."
        case APIError.networkError(let msg):
            return "Network error: \(msg)"
        default:
            return "Error: \(error.localizedDescription)"
        }
    }

    private func describeCodexError(_ error: Error) -> String {
        switch error {
        case CodexAuthError.notConfigured:
            return "No Codex credentials found."
        case CodexAuthError.invalidData(let msg):
            return "Invalid Codex credentials: \(msg)"
        case APIError.unauthorized:
            return "Codex authentication failed. Token may have expired."
        case APIError.forbidden:
            return "Codex access forbidden."
        case APIError.serverError(let code):
            return "Codex server error (\(code))."
        case APIError.networkError(let msg):
            return "Codex network error: \(msg)"
        default:
            return "Codex error: \(error.localizedDescription)"
        }
    }

    private func refreshClaude(existing: UsageSnapshot?, stats: TokenStats) async -> ClaudeRefreshResult {
        let debug = DebugLogger.shared

        let token: String
        do {
            if let cached = cachedToken {
                token = cached
                debug.log("Using cached token (\(token.prefix(8))...)", source: "App")
            } else {
                token = try keychainService.readToken()
                cachedToken = token
                debug.log("Read token from keychain (\(token.prefix(8))...)", source: "App")
            }
        } catch {
            let msg = describeError(error)
            debug.log("Token error: \(msg)", source: "App")
            return handleError(msg, stats: stats, source: "token", existing: existing)
        }

        do {
            let response = try await apiService.fetchUsage(token: token)
            let newSnapshot = response.toSnapshot(tokenStats: stats)
            debug.log("API success: fiveHour=\(newSnapshot.fiveHour?.percent ?? -1)%, sevenDay=\(newSnapshot.sevenDay?.percent ?? -1)%", source: "App")
            return ClaudeRefreshResult(snapshot: newSnapshot, shouldPersist: true)
        } catch {
            if case APIError.unauthorized = error { cachedToken = nil }
            if case APIError.forbidden = error { cachedToken = nil }

            let msg = describeError(error)
            debug.log("API error: \(msg)", source: "App")
            return handleError(msg, stats: stats, source: "API", existing: existing)
        }
    }

    private func refreshCodex(existing: ProviderUsageSnapshot?, stats: TokenStats) async -> CodexRefreshResult {
        let debug = DebugLogger.shared

        do {
            let credentials = try codexAuthService.readAuth()
            let response = try await codexAPIService.fetchUsage(credentials: credentials)
            let newSnapshot = response.toProviderSnapshot(tokenStats: stats)
            debug.log("Codex API success: fiveHour=\(newSnapshot.fiveHour?.percent ?? -1)%, sevenDay=\(newSnapshot.sevenDay?.percent ?? -1)%", source: "App")
            return CodexRefreshResult(snapshot: newSnapshot, shouldPersist: true)
        } catch {
            let msg = describeCodexError(error)
            debug.log("Codex API error: \(msg)", source: "App")
            if let existing {
                return CodexRefreshResult(snapshot: existing.withError(msg, tokenStats: stats), shouldPersist: true)
            }
            if case CodexAuthError.notConfigured = error {
                return CodexRefreshResult(snapshot: nil, shouldPersist: false)
            }
            return CodexRefreshResult(snapshot: nil, shouldPersist: false)
        }
    }

    private func mergeSnapshots(claude: UsageSnapshot, codex: ProviderUsageSnapshot?) -> UsageSnapshot {
        UsageSnapshot(
            fiveHour: claude.fiveHour,
            sevenDay: claude.sevenDay,
            sevenDaySonnet: claude.sevenDaySonnet,
            sevenDayOpus: claude.sevenDayOpus,
            codex: codex,
            tokenStats: claude.tokenStats,
            lastUpdated: max(claude.lastUpdated, codex?.lastUpdated ?? claude.lastUpdated),
            lastSuccessfulUpdate: [claude.lastSuccessfulUpdate, codex?.lastSuccessfulUpdate].compactMap { $0 }.max(),
            error: claude.error
        )
    }
}

private struct ClaudeRefreshResult {
    let snapshot: UsageSnapshot
    let shouldPersist: Bool
}

private struct CodexRefreshResult {
    let snapshot: ProviderUsageSnapshot?
    let shouldPersist: Bool
}
