import Foundation

final class SharedContainerService: SharedContainerServiceProtocol {
    private let snapshotURL: URL

    static let appGroupID = "group.com.andywendt.claude-usage-widget"
    private static let fileName = "usage-snapshot.json"

    init(containerURL: URL? = nil) {
        let baseURL: URL
        if let url = containerURL {
            baseURL = url
        } else if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            baseURL = groupURL
        } else {
            // Non-sandboxed fallback: construct path manually
            let home = FileManager.default.homeDirectoryForCurrentUser
            baseURL = home
                .appendingPathComponent("Library/Group Containers")
                .appendingPathComponent(Self.appGroupID)
        }
        self.snapshotURL = baseURL.appendingPathComponent(Self.fileName)
    }

    func writeSnapshot(_ snapshot: UsageSnapshot) throws {
        let dir = snapshotURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }

    func readSnapshot() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UsageSnapshot.self, from: data)
    }
}
