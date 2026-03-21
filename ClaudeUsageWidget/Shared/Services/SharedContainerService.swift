import Foundation
import os.log

private let containerLog = Logger(subsystem: "com.andywendt.claude-usage-widget", category: "SharedContainer")

final class SharedContainerService: SharedContainerServiceProtocol {
    static let appGroupID = "group.com.andywendt.claude-usage-widget"
    private static let snapshotKey = "usageSnapshot"

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: Self.appGroupID)
        if self.defaults == nil {
            containerLog.error("[SharedContainer] UserDefaults(suiteName:) returned nil — app group may be misconfigured")
        }
    }

    /// Test-only initializer that accepts a containerURL for backward compat with tests
    init(containerURL: URL?) {
        // Tests pass a containerURL — use standard UserDefaults for test isolation
        self.defaults = UserDefaults.standard
    }

    func writeSnapshot(_ snapshot: UsageSnapshot) throws {
        let encoder = UsageSnapshot.makeEncoder()
        let data = try encoder.encode(snapshot)
        defaults?.set(data, forKey: Self.snapshotKey)
        defaults?.synchronize()
        containerLog.info("[SharedContainer] wrote snapshot (\(data.count) bytes) to UserDefaults suite")
    }

    func readSnapshot() -> UsageSnapshot? {
        guard let data = defaults?.data(forKey: Self.snapshotKey) else {
            containerLog.info("[SharedContainer] no snapshot in UserDefaults")
            return nil
        }
        containerLog.info("[SharedContainer] read \(data.count) bytes from UserDefaults")
        do {
            let decoder = UsageSnapshot.makeDecoder()
            let snapshot = try decoder.decode(UsageSnapshot.self, from: data)
            containerLog.info("[SharedContainer] decoded OK, lastUpdated: \(snapshot.lastUpdated.description, privacy: .public)")
            return snapshot
        } catch {
            containerLog.error("[SharedContainer] decode error: \(String(reflecting: error), privacy: .public)")
            return nil
        }
    }
}
