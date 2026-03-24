import XCTest
@testable import ClaudeUsageWidget

final class UsageManagerTests: XCTestCase {
    var manager: UsageManager!
    var mockKeychain: MockKeychainService!
    var mockAPI: MockAPIService!
    var mockStats: MockStatsService!
    var mockCodexAuth: MockCodexAuthService!
    var mockCodexAPI: MockCodexAPIService!
    var mockCodexStats: MockStatsService!
    var mockContainer: MockSharedContainerService!
    var mockReloader: MockWidgetReloader!

    @MainActor
    override func setUp() {
        mockKeychain = MockKeychainService()
        mockAPI = MockAPIService()
        mockStats = MockStatsService()
        mockCodexAuth = MockCodexAuthService()
        mockCodexAPI = MockCodexAPIService()
        mockCodexStats = MockStatsService()
        mockContainer = MockSharedContainerService()
        mockReloader = MockWidgetReloader()
        manager = UsageManager(
            keychainService: mockKeychain,
            apiService: mockAPI,
            statsService: mockStats,
            codexAuthService: mockCodexAuth,
            codexAPIService: mockCodexAPI,
            codexStatsService: mockCodexStats,
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
        XCTAssertEqual(mockReloader.reloadCount, 1, "Widget should be reloaded on successful fetch")
    }

    @MainActor
    func testFetchSuccessMergesCodexSnapshot() async {
        mockKeychain.tokenToReturn = "claude-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 45.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: UsageWindow(utilization: 54.0, resetsAt: "2026-03-28T18:00:00Z"),
            sevenDaySonnet: nil,
            sevenDayOpus: nil
        )
        mockStats.statsToReturn = TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50)
        mockCodexAuth.credentialsToReturn = CodexAuthCredentials(accessToken: "codex-token", accountID: "account-123")
        mockCodexAPI.responseToReturn = CodexUsageResponse(
            rateLimit: CodexRateLimitEnvelope(
                allowed: true,
                limitReached: false,
                primaryWindow: CodexRateWindow(usedPercent: 15, limitWindowSeconds: 18000, resetAfterSeconds: 4180, resetAt: 1_774_388_998),
                secondaryWindow: CodexRateWindow(usedPercent: 10, limitWindowSeconds: 604800, resetAfterSeconds: 257905, resetAt: 1_774_642_723)
            ),
            codeReviewRateLimit: nil,
            additionalRateLimits: [
                CodexAdditionalRateLimit(
                    limitName: "GPT-5.3-Codex-Spark",
                    meteredFeature: "codex_bengalfox",
                    rateLimit: CodexRateLimitEnvelope(
                        allowed: true,
                        limitReached: false,
                        primaryWindow: CodexRateWindow(usedPercent: 1, limitWindowSeconds: 18000, resetAfterSeconds: 18000, resetAt: 1_774_402_818),
                        secondaryWindow: nil
                    )
                )
            ]
        )
        mockCodexStats.statsToReturn = TokenStats(todayTokens: 2000, weekTokens: 9000, todayMessages: 2, weekMessages: 7)

        await manager.refresh()

        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 45.0)
        XCTAssertEqual(manager.snapshot?.codex?.fiveHour?.percent, 15)
        XCTAssertEqual(manager.snapshot?.codex?.sevenDay?.percent, 10)
        XCTAssertEqual(manager.snapshot?.codex?.extraLabel, "GPT-5.3-Codex-Spark")
        XCTAssertEqual(manager.snapshot?.codex?.extraMetric?.percent, 1)
        XCTAssertEqual(manager.snapshot?.codex?.tokenStats.todayTokens, 2000)
        XCTAssertEqual(mockCodexAPI.lastCredentialsUsed?.accountID, "account-123")
        XCTAssertEqual(mockContainer.storedSnapshot?.codex?.sevenDay?.percent, 10)
        XCTAssertNil(manager.snapshot?.error)
    }

    @MainActor
    func testMissingCodexAuthDoesNotBlockClaudeRefresh() async {
        mockKeychain.tokenToReturn = "claude-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 22.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil,
            sevenDaySonnet: nil,
            sevenDayOpus: nil
        )
        mockCodexAuth.errorToThrow = CodexAuthError.notConfigured

        await manager.refresh()

        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 22.0)
        XCTAssertNil(manager.snapshot?.codex)
        XCTAssertNil(manager.snapshot?.error)
    }

    @MainActor
    func testCodexErrorPreservesCachedCodexData() async {
        mockKeychain.tokenToReturn = "claude-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 45.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil,
            sevenDaySonnet: nil,
            sevenDayOpus: nil
        )
        mockCodexAuth.credentialsToReturn = CodexAuthCredentials(accessToken: "codex-token", accountID: "account-123")
        mockCodexAPI.responseToReturn = CodexUsageResponse(
            rateLimit: CodexRateLimitEnvelope(
                allowed: true,
                limitReached: false,
                primaryWindow: CodexRateWindow(usedPercent: 12, limitWindowSeconds: 18000, resetAfterSeconds: 3600, resetAt: 1_774_388_998),
                secondaryWindow: CodexRateWindow(usedPercent: 8, limitWindowSeconds: 604800, resetAfterSeconds: 257905, resetAt: 1_774_642_723)
            ),
            codeReviewRateLimit: nil,
            additionalRateLimits: nil
        )

        await manager.refresh()

        mockCodexAPI.responseToReturn = nil
        mockCodexAPI.errorToThrow = APIError.serverError(500)

        await manager.refresh()

        XCTAssertEqual(manager.snapshot?.codex?.fiveHour?.percent, 12)
        XCTAssertEqual(manager.snapshot?.codex?.sevenDay?.percent, 8)
        XCTAssertNotNil(manager.snapshot?.codex?.error)
        XCTAssertTrue(manager.snapshot?.codex?.error?.contains("500") ?? false)
        XCTAssertNil(manager.snapshot?.error)
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
        XCTAssertEqual(mockReloader.reloadCount, 0, "Widget should NOT be reloaded on keychain error")
    }

    @MainActor
    func testAPIErrorSetsSnapshotErrorButKeepsStats() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.errorToThrow = APIError.serverError(500)
        mockStats.statsToReturn = TokenStats(todayTokens: 3000, weekTokens: 15000, todayMessages: 5, weekMessages: 20)

        await manager.refresh()

        XCTAssertNotNil(manager.snapshot?.error)
        XCTAssertEqual(manager.snapshot?.tokenStats.todayTokens, 3000) // stats still populated
        XCTAssertEqual(mockReloader.reloadCount, 0, "Widget should NOT be reloaded on API error")
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
    func testForbiddenClearsTokenCache() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.errorToThrow = APIError.forbidden

        await manager.refresh()

        XCTAssertEqual(mockKeychain.readTokenCallCount, 1, "First refresh reads from keychain")
        XCTAssertNotNil(manager.snapshot?.error)

        // Second call should re-read from keychain (token cache was cleared)
        mockAPI.errorToThrow = nil
        mockAPI.responseToReturn = UsageApiResponse(fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil)

        await manager.refresh()

        XCTAssertEqual(mockKeychain.readTokenCallCount, 2, "Token cache was cleared on forbidden, so keychain was re-read")
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
    func testTokenIsCachedBetweenRefreshes() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil)

        await manager.refresh()
        XCTAssertEqual(mockKeychain.readTokenCallCount, 1, "First refresh reads from keychain")

        await manager.refresh()
        XCTAssertEqual(mockKeychain.readTokenCallCount, 1, "Second refresh uses cached token, no keychain read")

        await manager.refresh()
        XCTAssertEqual(mockKeychain.readTokenCallCount, 1, "Third refresh still uses cached token")
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

    // MARK: - iconTier integration

    @MainActor
    func testIconTierStartsAsIdle() {
        XCTAssertEqual(manager.iconTier, .idle)
    }

    @MainActor
    func testIconTierUpdatesAfterSuccessfulRefresh() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 75.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )

        await manager.refresh()

        XCTAssertEqual(manager.iconTier, .high)
    }

    @MainActor
    func testIconTierIsIdleAfterError() async {
        mockKeychain.errorToThrow = KeychainError.notFound

        await manager.refresh()

        XCTAssertEqual(manager.iconTier, .idle)
    }

    @MainActor
    func testIconTierResetsToIdleAfterSuccessThenError() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 85.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        await manager.refresh()
        XCTAssertEqual(manager.iconTier, .high)

        // Now error — but cached data is preserved, so iconTier stays based on cached usage
        mockAPI.responseToReturn = nil
        mockAPI.errorToThrow = APIError.serverError(500)
        await manager.refresh()
        XCTAssertEqual(manager.iconTier, .high, "iconTier should reflect cached data, not reset to idle on error")
    }

    @MainActor
    func testIconTierReflectsMaxMetric() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 20.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: UsageWindow(utilization: 95.0, resetsAt: "2026-03-27T18:00:00Z"),
            sevenDaySonnet: nil,
            sevenDayOpus: nil
        )

        await manager.refresh()

        XCTAssertEqual(manager.iconTier, .critical)
    }

    // MARK: - Error-resilient caching

    @MainActor
    func testAPIErrorPreservesCachedData() async {
        // First: successful fetch
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 45.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: UsageWindow(utilization: 30.0, resetsAt: "2026-03-22T18:00:00Z"),
            sevenDaySonnet: nil, sevenDayOpus: nil
        )
        await manager.refresh()
        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 45.0)

        // Second: API error
        mockAPI.responseToReturn = nil
        mockAPI.errorToThrow = APIError.serverError(500)
        await manager.refresh()

        // Usage data should be preserved from the first fetch
        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 45.0)
        XCTAssertEqual(manager.snapshot?.sevenDay?.percent, 30.0)
        XCTAssertNotNil(manager.snapshot?.error)
        XCTAssertTrue(manager.snapshot!.error!.contains("500"))
    }

    @MainActor
    func testAPIErrorWithNoPriorDataShowsErrorOnly() async {
        // First-ever fetch fails — no cached data
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.errorToThrow = APIError.networkError("timeout")

        await manager.refresh()

        XCTAssertNil(manager.snapshot?.fiveHour)
        XCTAssertNil(manager.snapshot?.sevenDay)
        XCTAssertNotNil(manager.snapshot?.error)
        XCTAssertEqual(mockReloader.reloadCount, 0, "Widget should NOT be reloaded when there is no cached data")
    }

    @MainActor
    func testLastSuccessfulUpdateCarriesForwardOnError() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 10.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        let beforeSuccess = Date()
        await manager.refresh()
        let successTime = manager.snapshot?.lastSuccessfulUpdate

        XCTAssertNotNil(successTime)
        XCTAssertGreaterThanOrEqual(successTime!, beforeSuccess)

        // Now error
        mockAPI.responseToReturn = nil
        mockAPI.errorToThrow = APIError.serverError(500)
        await manager.refresh()

        XCTAssertEqual(manager.snapshot?.lastSuccessfulUpdate, successTime,
                       "lastSuccessfulUpdate should carry forward from the last success")
    }

    @MainActor
    func testSuccessClearsError() async {
        mockKeychain.tokenToReturn = "test-token"

        // First: error
        mockAPI.errorToThrow = APIError.serverError(500)
        await manager.refresh()
        XCTAssertNotNil(manager.snapshot?.error)

        // Second: success
        mockAPI.errorToThrow = nil
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 20.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        await manager.refresh()

        XCTAssertNil(manager.snapshot?.error)
        XCTAssertNotNil(manager.snapshot?.lastSuccessfulUpdate)
        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 20.0)
    }

    @MainActor
    func testContainerWrittenOnErrorWithCachedData() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 45.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        await manager.refresh()
        mockContainer.storedSnapshot = nil // Clear to detect new write

        mockAPI.responseToReturn = nil
        mockAPI.errorToThrow = APIError.serverError(500)
        await manager.refresh()

        XCTAssertNotNil(mockContainer.storedSnapshot, "Container should be written on error when cached data exists")
        XCTAssertEqual(mockContainer.storedSnapshot?.fiveHour?.percent, 45.0)
        XCTAssertNotNil(mockContainer.storedSnapshot?.error)
    }

    @MainActor
    func testWidgetReloadOnErrorWithCachedData() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 45.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        await manager.refresh()
        let reloadCountAfterSuccess = mockReloader.reloadCount

        mockAPI.responseToReturn = nil
        mockAPI.errorToThrow = APIError.serverError(500)
        await manager.refresh()

        XCTAssertEqual(mockReloader.reloadCount, reloadCountAfterSuccess + 1,
                       "Widget should be reloaded on error when there is cached data")
    }

    @MainActor
    func testAppRestartWithContainerDataAndAPIFailure() async {
        // Simulate: container has data from previous session, in-memory snapshot is nil
        let cachedSnapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 60.0, resetsAt: Date()),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 3000, weekTokens: 15000, todayMessages: 5, weekMessages: 20),
            lastUpdated: Date().addingTimeInterval(-600),
            lastSuccessfulUpdate: Date().addingTimeInterval(-600),
            error: nil
        )
        mockContainer.storedSnapshot = cachedSnapshot

        mockKeychain.tokenToReturn = "test-token"
        mockAPI.errorToThrow = APIError.networkError("no internet")

        await manager.refresh()

        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 60.0, "Should use container data")
        XCTAssertNotNil(manager.snapshot?.error)
    }

    @MainActor
    func testTokenErrorPreservesCachedData() async {
        // First: successful fetch
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 75.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        await manager.refresh()
        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 75.0)

        // Trigger 401 to clear cachedToken, then set keychain to fail
        mockAPI.responseToReturn = nil
        mockAPI.errorToThrow = APIError.unauthorized
        await manager.refresh()
        // cachedToken is now cleared due to 401

        // Now set keychain to throw on next read
        mockKeychain.errorToThrow = KeychainError.notFound
        mockAPI.errorToThrow = nil
        await manager.refresh()

        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 75.0, "Token error should preserve cached usage data")
        XCTAssertNotNil(manager.snapshot?.error)
        XCTAssertTrue(manager.snapshot!.error!.contains("credentials") || manager.snapshot!.error!.contains("sign in"),
                      "Error should be from keychain, not API")
    }

    @MainActor
    func testContainerWriteFailureOnErrorPathStillSetsSnapshot() async {
        // First: successful fetch
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 40.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        await manager.refresh()

        // Set up: container write will fail, API will error
        mockContainer.writeError = NSError(domain: "test", code: 1)
        mockAPI.responseToReturn = nil
        mockAPI.errorToThrow = APIError.serverError(500)
        await manager.refresh()

        // Snapshot should still be set with cached data + error despite write failure
        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 40.0)
        XCTAssertNotNil(manager.snapshot?.error)
    }

    @MainActor
    func testTokenErrorWithContainerFallback() async {
        // Simulate cold start: no in-memory snapshot, container has data
        let cachedSnapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 55.0, resetsAt: Date()),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 1000, weekTokens: 5000, todayMessages: 5, weekMessages: 20),
            lastUpdated: Date().addingTimeInterval(-600),
            lastSuccessfulUpdate: Date().addingTimeInterval(-600),
            error: nil
        )
        mockContainer.storedSnapshot = cachedSnapshot
        mockKeychain.errorToThrow = KeychainError.notFound

        await manager.refresh()

        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 55.0, "Should use container data on token error")
        XCTAssertNotNil(manager.snapshot?.error)
    }

    @MainActor
    func testFreshTokenStatsUsedOnError() async {
        mockKeychain.tokenToReturn = "test-token"
        mockStats.statsToReturn = TokenStats(todayTokens: 1000, weekTokens: 5000, todayMessages: 5, weekMessages: 20)
        mockAPI.responseToReturn = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 50.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
        )
        await manager.refresh()

        // Update stats, then error
        mockStats.statsToReturn = TokenStats(todayTokens: 2000, weekTokens: 10000, todayMessages: 8, weekMessages: 30)
        mockAPI.responseToReturn = nil
        mockAPI.errorToThrow = APIError.serverError(500)
        await manager.refresh()

        XCTAssertEqual(manager.snapshot?.tokenStats.todayTokens, 2000, "Should use fresh stats from statsService")
        XCTAssertEqual(manager.snapshot?.fiveHour?.percent, 50.0, "Usage data should be preserved")
    }

    // MARK: - Pace Settings

    @MainActor
    func testUpdatePaceSettingsUpdatesInMemory() {
        let newSettings = PaceSettings(enabledMetrics: [.fiveHour])
        manager.updatePaceSettings(newSettings)
        XCTAssertEqual(manager.paceSettings, newSettings)
    }

    @MainActor
    func testUpdatePaceSettingsPersistsToContainer() {
        let newSettings = PaceSettings(enabledMetrics: [.sevenDay, .sevenDayOpus])
        manager.updatePaceSettings(newSettings)
        XCTAssertEqual(mockContainer.storedPaceSettings, newSettings)
    }

    @MainActor
    func testInitLoadsPaceSettingsFromContainer() {
        let customSettings = PaceSettings(enabledMetrics: [.fiveHour, .sevenDaySonnet])
        mockContainer.storedPaceSettings = customSettings

        let newManager = UsageManager(
            keychainService: mockKeychain,
            apiService: mockAPI,
            statsService: mockStats,
            codexAuthService: mockCodexAuth,
            codexAPIService: mockCodexAPI,
            codexStatsService: mockCodexStats,
            containerService: mockContainer,
            widgetReloader: mockReloader.reload
        )

        XCTAssertEqual(newManager.paceSettings, customSettings)
    }

    @MainActor
    func testUpdatePaceSettingsStillUpdatesInMemoryOnWriteFailure() {
        mockContainer.writeError = NSError(domain: "test", code: 1, userInfo: nil)
        let newSettings = PaceSettings(enabledMetrics: [.sevenDay])
        manager.updatePaceSettings(newSettings)
        XCTAssertEqual(manager.paceSettings, newSettings)
    }

    @MainActor
    func testUpdatePaceSettingsReloadsWidget() {
        let newSettings = PaceSettings(enabledMetrics: [.fiveHour])
        manager.updatePaceSettings(newSettings)
        XCTAssertEqual(mockReloader.reloadCount, 1, "Widget should be reloaded when pace settings change")
    }
}
