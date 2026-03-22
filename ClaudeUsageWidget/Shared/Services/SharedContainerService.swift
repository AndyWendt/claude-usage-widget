import Foundation
import os.log

private let containerLog = Logger(subsystem: "com.andywendt.claude-usage-widget", category: "SharedContainer")

enum SharedContainerError: Error {
    case noContainer
}

final class SharedContainerService: SharedContainerServiceProtocol {
    static let appGroupID = "KWBZ4HM9UX.com.andywendt.claude-usage-widget"
    private static let snapshotFilename = "usage-snapshot.json"

    private let containerURL: URL?

    init() {
        self.containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        )
        if self.containerURL == nil {
            containerLog.error("[SharedContainer] containerURL is nil — app group may be misconfigured")
        }
    }

    /// Test-only initializer that accepts a containerURL for test isolation
    init(containerURL: URL?) {
        self.containerURL = containerURL
    }

    private var snapshotFileURL: URL? {
        containerURL?.appendingPathComponent(Self.snapshotFilename)
    }

    func writeSnapshot(_ snapshot: UsageSnapshot) throws {
        let debug = DebugLogger.shared
        let encoder = UsageSnapshot.makeEncoder()
        let data = try encoder.encode(snapshot)

        debug.log("Writing snapshot: \(data.count) bytes, error=\(snapshot.error ?? "nil"), fiveHour=\(snapshot.fiveHour?.percent ?? -1)%", source: "SharedContainer")

        guard let fileURL = snapshotFileURL else {
            debug.log("WRITE FAILED: container URL is nil — app group not configured", source: "SharedContainer")
            throw SharedContainerError.noContainer
        }

        try data.write(to: fileURL, options: .atomic)
        containerLog.info("[SharedContainer] wrote snapshot (\(data.count) bytes) to \(fileURL.lastPathComponent)")

        // Read-back verification
        if let readBack = try? Data(contentsOf: fileURL) {
            debug.log("Write verified: read-back got \(readBack.count) bytes (match: \(readBack == data))", source: "SharedContainer")
        } else {
            debug.log("WRITE VERIFICATION FAILED: read-back returned nil!", source: "SharedContainer")
        }
    }

    func readSnapshot() -> UsageSnapshot? {
        let debug = DebugLogger.shared

        guard let fileURL = snapshotFileURL else {
            debug.log("READ FAILED: container URL is nil — app group not configured", source: "SharedContainer")
            return nil
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            debug.log("READ: no snapshot file at \(fileURL.path)", source: "SharedContainer")
            containerLog.info("[SharedContainer] no snapshot file")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            debug.log("READ: got \(data.count) bytes from \(fileURL.lastPathComponent)", source: "SharedContainer")
            containerLog.info("[SharedContainer] read \(data.count) bytes from file")

            let decoder = UsageSnapshot.makeDecoder()
            let snapshot = try decoder.decode(UsageSnapshot.self, from: data)
            debug.log("READ decoded OK: fiveHour=\(snapshot.fiveHour?.percent ?? -1)%, error=\(snapshot.error ?? "nil"), lastUpdated=\(snapshot.lastUpdated)", source: "SharedContainer")
            return snapshot
        } catch {
            debug.log("READ ERROR: \(String(reflecting: error))", source: "SharedContainer")
            containerLog.error("[SharedContainer] read error: \(String(reflecting: error), privacy: .public)")
            return nil
        }
    }
}
