import XCTest
@testable import ClaudeUsageWidget

final class SharedContainerServiceTests: XCTestCase {
    var service: SharedContainerService!
    var tmpDir: URL!

    override func setUp() {
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        service = SharedContainerService(containerURL: tmpDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testWriteAndReadSnapshot() throws {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 45.0, resetsAt: Date(timeIntervalSince1970: 1711000000)),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50),
            lastUpdated: Date(timeIntervalSince1970: 1711000000),
            error: nil
        )

        try service.writeSnapshot(snapshot)
        let read = service.readSnapshot()

        XCTAssertNotNil(read)
        XCTAssertEqual(read?.fiveHour?.percent, 45.0)
        XCTAssertEqual(read?.tokenStats.todayTokens, 5000)
    }

    func testReadSnapshotMissingFile() {
        let emptyDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let emptyService = SharedContainerService(containerURL: emptyDir)
        XCTAssertNil(emptyService.readSnapshot())
    }

    func testWriteCreatesDirectory() throws {
        let nestedDir = tmpDir.appendingPathComponent("nested/deep")
        let nestedService = SharedContainerService(containerURL: nestedDir)

        let snapshot = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: nil
        )

        try nestedService.writeSnapshot(snapshot)
        XCTAssertNotNil(nestedService.readSnapshot())
    }
}
