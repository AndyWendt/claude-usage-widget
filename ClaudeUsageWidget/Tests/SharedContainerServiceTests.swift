import XCTest
@testable import ClaudeUsageWidget

final class SharedContainerServiceTests: XCTestCase {
    var service: SharedContainerService!

    override func setUp() {
        // Use the containerURL init which maps to UserDefaults.standard for tests
        service = SharedContainerService(containerURL: nil)
        // Clear any leftover test data
        UserDefaults.standard.removeObject(forKey: "usageSnapshot")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "usageSnapshot")
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

    func testReadSnapshotMissing() {
        XCTAssertNil(service.readSnapshot())
    }

    func testWriteOverwritesPrevious() throws {
        let first = UsageSnapshot(
            fiveHour: UsageMetric(percent: 10.0, resetsAt: Date(timeIntervalSince1970: 1711000000)),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 100, weekTokens: 500, todayMessages: 1, weekMessages: 5),
            lastUpdated: Date(timeIntervalSince1970: 1711000000),
            error: nil
        )
        try service.writeSnapshot(first)

        let second = UsageSnapshot(
            fiveHour: UsageMetric(percent: 90.0, resetsAt: Date(timeIntervalSince1970: 1711000000)),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 9000, weekTokens: 50000, todayMessages: 100, weekMessages: 500),
            lastUpdated: Date(timeIntervalSince1970: 1711000000),
            error: nil
        )
        try service.writeSnapshot(second)

        let read = service.readSnapshot()
        XCTAssertEqual(read?.fiveHour?.percent, 90.0)
        XCTAssertEqual(read?.tokenStats.todayTokens, 9000)
    }
}
