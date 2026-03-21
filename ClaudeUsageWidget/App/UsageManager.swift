import Foundation
import WidgetKit

@MainActor
final class UsageManager: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var isLoading = false

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
        isLoading = true
        defer { isLoading = false }

        let stats = statsService.readStats()

        // Get token
        let token: String
        do {
            if let cached = cachedToken {
                token = cached
            } else {
                token = try keychainService.readToken()
                cachedToken = token
            }
        } catch {
            snapshot = UsageSnapshot(
                fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
                tokenStats: stats,
                lastUpdated: Date(),
                error: describeError(error)
            )
            return
        }

        // Fetch API
        do {
            let response = try await apiService.fetchUsage(token: token)
            let newSnapshot = response.toSnapshot(tokenStats: stats)
            snapshot = newSnapshot
            do {
                try containerService.writeSnapshot(newSnapshot)
            } catch {
                print("[ClaudeUsageWidget] Warning: failed to write snapshot to shared container: \(error.localizedDescription)")
            }
            widgetReloader()
        } catch {
            if case APIError.unauthorized = error { cachedToken = nil }
            if case APIError.forbidden = error { cachedToken = nil }

            snapshot = UsageSnapshot(
                fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
                tokenStats: stats,
                lastUpdated: Date(),
                error: describeError(error)
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
