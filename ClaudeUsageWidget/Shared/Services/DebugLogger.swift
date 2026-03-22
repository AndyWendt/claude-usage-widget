import Foundation

/// File-based debug logger that both the app and widget extension can write to
/// via the shared app group container. View logs in Console.app or in the app's debug panel.
final class DebugLogger {
    static let shared = DebugLogger()

    private let fileURL: URL?
    private let queue = DispatchQueue(label: "com.andywendt.claude-usage-widget.debug-log")
    private let maxLines = 200

    private init() {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedContainerService.appGroupID
        ) {
            self.fileURL = containerURL.appendingPathComponent("debug.log")
        } else {
            self.fileURL = nil
            NSLog("[DebugLogger] WARNING: App group container not available — logs will only go to NSLog")
        }
    }

    func log(_ message: String, source: String = "Unknown") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let pid = ProcessInfo.processInfo.processIdentifier
        let processName = ProcessInfo.processInfo.processName
        let line = "[\(timestamp)] [\(processName)/\(pid)] [\(source)] \(message)"

        // Always log to system log too
        NSLog("%@", line)

        queue.async { [weak self] in
            guard let self, let fileURL = self.fileURL else { return }
            do {
                var existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
                existing += line + "\n"

                // Trim to last maxLines
                let lines = existing.components(separatedBy: "\n")
                if lines.count > self.maxLines {
                    let trimmed = lines.suffix(self.maxLines).joined(separator: "\n")
                    try trimmed.write(to: fileURL, atomically: true, encoding: .utf8)
                } else {
                    try existing.write(to: fileURL, atomically: true, encoding: .utf8)
                }
            } catch {
                NSLog("[DebugLogger] Failed to write log: %@", error.localizedDescription)
            }
        }
    }

    func readLogs() -> String {
        guard let fileURL else { return "(app group container not available)" }
        return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "(no logs yet)"
    }

    func clearLogs() {
        guard let fileURL else { return }
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Diagnostic dump of app group container state
    func dumpContainerDiagnostics(source: String) {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedContainerService.appGroupID
        )
        log("--- Container Diagnostics ---", source: source)
        log("App Group ID: \(SharedContainerService.appGroupID)", source: source)
        log("Container URL: \(containerURL?.path ?? "NIL (app group not configured)")", source: source)

        if let containerURL {
            let fm = FileManager.default
            log("Container exists: \(fm.fileExists(atPath: containerURL.path))", source: source)
            if let contents = try? fm.contentsOfDirectory(atPath: containerURL.path) {
                log("Container contents: \(contents)", source: source)
            }

            let snapshotURL = containerURL.appendingPathComponent("usage-snapshot.json")
            if fm.fileExists(atPath: snapshotURL.path) {
                if let data = try? Data(contentsOf: snapshotURL),
                   let str = String(data: data.prefix(500), encoding: .utf8) {
                    log("Snapshot file: \(data.count) bytes", source: source)
                    log("Snapshot preview: \(str)", source: source)
                }
            } else {
                log("Snapshot file: NOT FOUND", source: source)
            }
        }
        log("--- End Diagnostics ---", source: source)
    }
}
