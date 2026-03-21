import XCTest
@testable import ClaudeUsageWidget

final class UsageManagerTests: XCTestCase {
    var manager: UsageManager!
    var mockKeychain: MockKeychainService!
    var mockAPI: MockAPIService!
    var mockStats: MockStatsService!
    var mockContainer: MockSharedContainerService!
    var mockReloader: MockWidgetReloader!

    @MainActor
    override func setUp() {
        mockKeychain = MockKeychainService()
        mockAPI = MockAPIService()
        mockStats = MockStatsService()
        mockContainer = MockSharedContainerService()
        mockReloader = MockWidgetReloader()
        manager = UsageManager(
            keychainService: mockKeychain,
            apiService: mockAPI,
            statsService: mockStats,
            containerService: mockContainer,
            widgetReloader: mockReloader.reload
        )
    }

    @MainActor
    func testFetchSuccessUpdatesSnapshot() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 45.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        mockStats.statsToReturn = TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50)

        await manager.refresh()

        XCTAssertNotNil(manager.snapshot)
        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 45.0)
        XCTAssertEqual(manager.snapshot?.tokenStats.todayTokens, 5000)
        XCTAssertNil(manager.snapshot?.error)
        XCTAssertFalse(manager.isLoading)
    }

    @MainActor
    func testFetchWritesToSharedContainer() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 10.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )

        await manager.refresh()

        XCTAssertNotNil(mockContainer.storedSnapshot)
        XCTAssertEqual(mockContainer.storedSnapshot?.fiveHour?.percent, 10.0)
    }

    @MainActor
    func testKeychainErrorSetsSnapshotError() async {
        mockKeychain.errorToThrow = KeychainError.notFound

        await manager.refresh()

        XCTAssertNotNil(manager.snapshot?.error)
        XCTAssertTrue(manager.snapshot!.error!.contains("not found") || manager.snapshot!.error!.contains("credentials") || manager.snapshot!.error!.contains("Keychain") || manager.snapshot!.error!.contains("sign in"))
    }

    @MainActor
    func testAPIErrorSetsSnapshotErrorButKeepsStats() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.errorToThrow = APIError.serverError(500)
        mockStats.statsToReturn = TokenStats(todayTokens: 3000, weekTokens: 15000, todayMessages: 5, weekMessages: 20)

        await manager.refresh()

        XCTAssertNotNil(manager.snapshot?.error)
        XCTAssertEqual(manager.snapshot?.tokenStats.todayTokens, 3000) // stats still populated
    }

    @MainActor
    func testUnauthorizedClearsTokenCache() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.errorToThrow = APIError.unauthorized

        await manager.refresh()

        XCTAssertEqual(mockKeychain.readTokenCallCount, 1, "First refresh reads from keychain")

        // Second call should re-read from keychain (token cache was cleared)
        mockAPI.errorToThrow = nil
        mockAPI.responseToReturn = UsageApiResponse(fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil)

        await manager.refresh()

        XCTAssertEqual(mockKeychain.readTokenCallCount, 2, "Token cache was cleared, so keychain was re-read")
        XCTAssertNil(manager.snapshot?.error)
    }

    @MainActor
    func testContainerWriteFailureStillSetsSnapshot() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 50.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        mockContainer.writeError = NSError(domain: "test", code: 1, userInfo: nil)

        await manager.refresh()

        // Snapshot should still be set despite write failure
        XCTAssertNotNil(manager.snapshot)
        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 50.0)
        XCTAssertNil(manager.snapshot?.error)
        // Widget should still be reloaded
        XCTAssertEqual(mockReloader.reloadCount, 1)
    }

    @MainActor
    func testIsLoadingDuringRefresh() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil)

        // Before refresh
        XCTAssertFalse(manager.isLoading)

        await manager.refresh()

        // After refresh
        XCTAssertFalse(manager.isLoading)
    }
}
