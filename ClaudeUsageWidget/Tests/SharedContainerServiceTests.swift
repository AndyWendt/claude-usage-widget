import XCTest
@testable import ClaudeUsageWidget

final class SharedContainerServiceTests: XCTestCase {
    var service: SharedContainerService!
    var tempDir: URL!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = SharedContainerService(containerURL: tempDir)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    func testWriteAndReadSnapshot() throws {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 45.0, resetsAt: Date(timeIntervalSince1970: 1711000000)),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50),
            lastUpdated: Date(timeIntervalSince1970: 1711000000),
            lastSuccessfulUpdate: nil,
            error: nil
        )

        try service.writeSnapshot(snapshot)
        let read = service.readSnapshot()

        XCTAssertNotNil(read)
        XCTAssertEqual(read?.fiveHour?.percent, 45.0)
        XCTAssertEqual(read?.tokenStats.todayTokens, 5000)
    }

    func testReadSnapshotMissing() {
        XCTAssertNil(service.readSnapshot())
    }

    // MARK: - PaceSettings Tests

    func testWriteAndReadPaceSettings() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let svc = SharedContainerService(containerURL: tempDir)
        let settings = PaceSettings(enabledMetrics: [.fiveHour, .sevenDay])

        try svc.writePaceSettings(settings)
        let read = svc.readPaceSettings()

        XCTAssertEqual(read, settings)
    }

    func testReadPaceSettingsReturnAllEnabledWhenFileMissing() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let svc = SharedContainerService(containerURL: tempDir)
        let settings = svc.readPaceSettings()

        XCTAssertEqual(settings, .allEnabled)
    }

    func testWritePaceSettingsOverwritesPrevious() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let svc = SharedContainerService(containerURL: tempDir)
        let first = PaceSettings(enabledMetrics: [.fiveHour])
        try svc.writePaceSettings(first)

        let second = PaceSettings(enabledMetrics: [.sevenDay, .sevenDayOpus])
        try svc.writePaceSettings(second)

        let read = svc.readPaceSettings()
        XCTAssertEqual(read, second)
    }

    func testPaceSettingsSubsetEncodeDecode() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let svc = SharedContainerService(containerURL: tempDir)
        let settings = PaceSettings(enabledMetrics: [.fiveHour])
        try svc.writePaceSettings(settings)

        let read = svc.readPaceSettings()
        XCTAssertEqual(read.enabledMetrics, [.fiveHour])
    }

    func testPaceSettingsEmptySet() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let svc = SharedContainerService(containerURL: tempDir)
        let settings = PaceSettings(enabledMetrics: [])
        try svc.writePaceSettings(settings)

        let read = svc.readPaceSettings()
        XCTAssertEqual(read.enabledMetrics.count, 0)
    }

    func testWriteOverwritesPrevious() throws {
        let first = UsageSnapshot(
            fiveHour: UsageMetric(percent: 10.0, resetsAt: Date(timeIntervalSince1970: 1711000000)),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 100, weekTokens: 500, todayMessages: 1, weekMessages: 5),
            lastUpdated: Date(timeIntervalSince1970: 1711000000),
            lastSuccessfulUpdate: nil,
            error: nil
        )
        try service.writeSnapshot(first)

        let second = UsageSnapshot(
            fiveHour: UsageMetric(percent: 90.0, resetsAt: Date(timeIntervalSince1970: 1711000000)),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 9000, weekTokens: 50000, todayMessages: 100, weekMessages: 500),
            lastUpdated: Date(timeIntervalSince1970: 1711000000),
            lastSuccessfulUpdate: nil,
            error: nil
        )
        try service.writeSnapshot(second)

        let read = service.readSnapshot()
        XCTAssertEqual(read?.fiveHour?.percent, 90.0)
        XCTAssertEqual(read?.tokenStats.todayTokens, 9000)
    }
}
