import Foundation
import WidgetKit

@MainActor
final class UsageManager: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var isLoading = false
    @Published var paceSettings: PaceSettings = .allEnabled

    private let keychainService: KeychainServiceProtocol
    private let apiService: APIServiceProtocol
    private let statsService: StatsServiceProtocol
    private let containerService: SharedContainerServiceProtocol
    private let widgetReloader: () -> Void
    private var cachedToken: String?
    private var timer: Timer?

    init(
        keychainService: KeychainServiceProtocol = KeychainService(),
        apiService: APIServiceProtocol = APIService(),
        statsService: StatsServiceProtocol = StatsService(),
        containerService: SharedContainerServiceProtocol = SharedContainerService(),
        widgetReloader: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsageWidget") }
    ) {
        self.keychainService = keychainService
        self.apiService = apiService
        self.statsService = statsService
        self.containerService = containerService
        self.widgetReloader = widgetReloader
        self.paceSettings = containerService.readPaceSettings()
    }

    func updatePaceSettings(_ settings: PaceSettings) {
        paceSettings = settings
        try? containerService.writePaceSettings(settings)
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

        let stats = statsService.readStats()
        debug.log("Stats: todayTokens=\(stats.todayTokens), weekTokens=\(stats.weekTokens)", source: "App")

        // Get token
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
            snapshot = UsageSnapshot(
                fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
                tokenStats: stats,
                lastUpdated: Date(),
                error: msg
            )
            return
        }

        // Fetch API
        do {
            let response = try await apiService.fetchUsage(token: token)
            let newSnapshot = response.toSnapshot(tokenStats: stats)
            debug.log("API success: fiveHour=\(newSnapshot.fiveHour?.percent ?? -1)%, sevenDay=\(newSnapshot.sevenDay?.percent ?? -1)%", source: "App")
            snapshot = newSnapshot
            do {
                try containerService.writeSnapshot(newSnapshot)
                debug.log("Snapshot written to shared container", source: "App")
            } catch {
                debug.log("WRITE FAILED: \(error)", source: "App")
            }
            widgetReloader()
            debug.log("Widget reload requested", source: "App")
        } catch {
            if case APIError.unauthorized = error { cachedToken = nil }
            if case APIError.forbidden = error { cachedToken = nil }

            let msg = describeError(error)
            debug.log("API error: \(msg)", source: "App")
            snapshot = UsageSnapshot(
                fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
                tokenStats: stats,
                lastUpdated: Date(),
                error: msg
            )
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
}
