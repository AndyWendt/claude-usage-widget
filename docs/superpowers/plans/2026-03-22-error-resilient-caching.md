# Error-Resilient Caching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve cached usage data when API fetches fail, displaying an error indicator with "last updated" timestamp instead of replacing data with a full error screen.

**Architecture:** Add `lastSuccessfulUpdate` field and `withError()` helper to `UsageSnapshot`. Modify both error paths in `UsageManager.refresh()` to merge errors into existing snapshots. Update widget views to show an error indicator instead of replacing content, and add "last updated" timestamp to the popover error banner.

**Tech Stack:** Swift, SwiftUI, WidgetKit, XCTest, Xcode

**Spec:** `docs/superpowers/specs/2026-03-22-error-resilient-caching-design.md`

---

## Build & Test Commands

```bash
# Build app target (tests live here)
xcodebuild build -project ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidget -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5

# Run tests
xcodebuild test -project ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidget -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```

---

## Task 1: Add `lastSuccessfulUpdate` and `hasUsageData` to UsageSnapshot

**Files:**
- Modify: `ClaudeUsageWidget/Shared/Models/UsageSnapshot.swift:36-64`
- Test: `ClaudeUsageWidget/Tests/UsageSnapshotTests.swift`

**Dependencies:** None (foundation for all other tasks)

- [ ] **Step 1: Write failing tests for `lastSuccessfulUpdate` field and `hasUsageData` computed property**

Add to `ClaudeUsageWidget/Tests/UsageSnapshotTests.swift`:

```swift
func testLastSuccessfulUpdateEncodeDecode() throws {
    let date = Date(timeIntervalSince1970: 1711000000)
    let snapshot = UsageSnapshot(
        fiveHour: UsageMetric(percent: 45.0, resetsAt: date),
        sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
        tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
        lastUpdated: date,
        lastSuccessfulUpdate: date,
        error: nil
    )
    let data = try UsageSnapshot.makeEncoder().encode(snapshot)
    let decoded = try UsageSnapshot.makeDecoder().decode(UsageSnapshot.self, from: data)
    XCTAssertEqual(decoded.lastSuccessfulUpdate, date)
}

func testLastSuccessfulUpdateNilWhenMissing() throws {
    // Simulate decoding old data that lacks lastSuccessfulUpdate
    let json = """
    {
        "tokenStats": {"todayTokens":0,"weekTokens":0,"todayMessages":0,"weekMessages":0},
        "lastUpdated": "2024-03-21T12:00:00Z"
    }
    """.data(using: .utf8)!
    let decoded = try UsageSnapshot.makeDecoder().decode(UsageSnapshot.self, from: json)
    XCTAssertNil(decoded.lastSuccessfulUpdate)
}

func testHasUsageDataWithFiveHour() {
    let snapshot = UsageSnapshot(
        fiveHour: UsageMetric(percent: 45.0, resetsAt: Date()),
        sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
        tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
        lastUpdated: Date(),
        lastSuccessfulUpdate: nil,
        error: nil
    )
    XCTAssertTrue(snapshot.hasUsageData)
}

func testHasUsageDataWithSevenDay() {
    let snapshot = UsageSnapshot(
        fiveHour: nil,
        sevenDay: UsageMetric(percent: 30.0, resetsAt: Date()),
        sevenDaySonnet: nil, sevenDayOpus: nil,
        tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
        lastUpdated: Date(),
        lastSuccessfulUpdate: nil,
        error: nil
    )
    XCTAssertTrue(snapshot.hasUsageData)
}

func testHasUsageDataWithNoData() {
    let snapshot = UsageSnapshot(
        fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
        tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
        lastUpdated: Date(),
        lastSuccessfulUpdate: nil,
        error: "Some error"
    )
    XCTAssertFalse(snapshot.hasUsageData)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidget -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```

Expected: Build failure — `lastSuccessfulUpdate` parameter doesn't exist yet, `hasUsageData` doesn't exist yet.

- [ ] **Step 3: Add `lastSuccessfulUpdate` field and `hasUsageData` computed property to `UsageSnapshot`**

In `ClaudeUsageWidget/Shared/Models/UsageSnapshot.swift`, modify the `UsageSnapshot` struct:

```swift
struct UsageSnapshot: Codable, Equatable {
    let fiveHour: UsageMetric?
    let sevenDay: UsageMetric?
    let sevenDaySonnet: UsageMetric?
    let sevenDayOpus: UsageMetric?
    let tokenStats: TokenStats
    let lastUpdated: Date
    let lastSuccessfulUpdate: Date?
    let error: String?

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 30 * 60
    }

    var hasUsageData: Bool {
        fiveHour != nil || sevenDay != nil
    }

    // ... makeEncoder() and makeDecoder() unchanged
}
```

- [ ] **Step 4: Fix all existing snapshot construction call sites to include `lastSuccessfulUpdate: nil`**

Every file that constructs a `UsageSnapshot` needs the new parameter. Update these files:

**`ClaudeUsageWidget/Shared/Models/UsageTimelineEntry.swift:9-13`** — add `lastSuccessfulUpdate: nil`:
```swift
let base = snapshot ?? UsageSnapshot(
    fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
    tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
    lastUpdated: Date(),
    lastSuccessfulUpdate: nil,
    error: "No data available. Open the app to refresh."
)
```

**`ClaudeUsageWidget/App/UsageManager.swift:70-75`** — token error path:
```swift
snapshot = UsageSnapshot(
    fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
    tokenStats: stats,
    lastUpdated: Date(),
    lastSuccessfulUpdate: nil,
    error: msg
)
```

**`ClaudeUsageWidget/App/UsageManager.swift:99-104`** — API error path:
```swift
snapshot = UsageSnapshot(
    fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
    tokenStats: stats,
    lastUpdated: Date(),
    lastSuccessfulUpdate: nil,
    error: msg
)
```

**`ClaudeUsageWidget/Tests/UsageSnapshotTests.swift`** — all existing snapshot constructors:
Add `lastSuccessfulUpdate: nil` to every `UsageSnapshot(...)` call in `testEncodeDecodeRoundTrip`, `testWithError`, `testIsStale`.

**`ClaudeUsageWidget/Tests/SharedContainerServiceTests.swift`** — all existing snapshot constructors:
Add `lastSuccessfulUpdate: nil` to every `UsageSnapshot(...)` call.

**`ClaudeUsageWidget/Tests/TimelineProviderTests.swift`** — all existing snapshot constructors:
Add `lastSuccessfulUpdate: nil` to every `UsageSnapshot(...)` call.

**`ClaudeUsageWidget/Tests/UsageManagerTests.swift`** — no snapshot constructors here (uses mocks).

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild test -project ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidget -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```

Expected: ALL tests pass including the new ones.

- [ ] **Step 6: Commit**

```bash
git add ClaudeUsageWidget/Shared/Models/UsageSnapshot.swift \
       ClaudeUsageWidget/Shared/Models/UsageTimelineEntry.swift \
       ClaudeUsageWidget/App/UsageManager.swift \
       ClaudeUsageWidget/Tests/UsageSnapshotTests.swift \
       ClaudeUsageWidget/Tests/SharedContainerServiceTests.swift \
       ClaudeUsageWidget/Tests/TimelineProviderTests.swift
git commit -m "feat: add lastSuccessfulUpdate and hasUsageData to UsageSnapshot"
```

---

## Task 2: Add `withError()` helper to UsageSnapshot

**Files:**
- Modify: `ClaudeUsageWidget/Shared/Models/UsageSnapshot.swift`
- Test: `ClaudeUsageWidget/Tests/UsageSnapshotTests.swift`

**Dependencies:** Task 1

- [ ] **Step 1: Write failing tests for `withError()`**

Add to `ClaudeUsageWidget/Tests/UsageSnapshotTests.swift`:

```swift
func testWithErrorPreservesUsageData() {
    let date = Date(timeIntervalSince1970: 1711000000)
    let snapshot = UsageSnapshot(
        fiveHour: UsageMetric(percent: 45.0, resetsAt: date),
        sevenDay: UsageMetric(percent: 30.0, resetsAt: date),
        sevenDaySonnet: nil, sevenDayOpus: nil,
        tokenStats: TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50),
        lastUpdated: date,
        lastSuccessfulUpdate: date,
        error: nil
    )

    let errorSnapshot = snapshot.withError("Network error")

    XCTAssertEqual(errorSnapshot.fiveHour?.percent, 45.0)
    XCTAssertEqual(errorSnapshot.sevenDay?.percent, 30.0)
    XCTAssertEqual(errorSnapshot.tokenStats.todayTokens, 5000)
    XCTAssertEqual(errorSnapshot.lastSuccessfulUpdate, date)
    XCTAssertEqual(errorSnapshot.error, "Network error")
    // lastUpdated should be recent (not the original date)
    XCTAssertTrue(errorSnapshot.lastUpdated.timeIntervalSince(date) > 0)
}

func testWithErrorUsesFreshTokenStats() {
    let date = Date(timeIntervalSince1970: 1711000000)
    let snapshot = UsageSnapshot(
        fiveHour: UsageMetric(percent: 45.0, resetsAt: date),
        sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
        tokenStats: TokenStats(todayTokens: 1000, weekTokens: 5000, todayMessages: 5, weekMessages: 20),
        lastUpdated: date,
        lastSuccessfulUpdate: date,
        error: nil
    )

    let freshStats = TokenStats(todayTokens: 2000, weekTokens: 10000, todayMessages: 8, weekMessages: 30)
    let errorSnapshot = snapshot.withError("Server error", tokenStats: freshStats)

    XCTAssertEqual(errorSnapshot.tokenStats.todayTokens, 2000, "Should use fresh stats")
    XCTAssertEqual(errorSnapshot.tokenStats.weekTokens, 10000)
}

func testWithErrorFallsBackToCachedTokenStats() {
    let date = Date(timeIntervalSince1970: 1711000000)
    let snapshot = UsageSnapshot(
        fiveHour: UsageMetric(percent: 45.0, resetsAt: date),
        sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
        tokenStats: TokenStats(todayTokens: 1000, weekTokens: 5000, todayMessages: 5, weekMessages: 20),
        lastUpdated: date,
        lastSuccessfulUpdate: date,
        error: nil
    )

    let errorSnapshot = snapshot.withError("Server error")

    XCTAssertEqual(errorSnapshot.tokenStats.todayTokens, 1000, "Should fall back to cached stats when none provided")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Build failure — `withError` method doesn't exist yet.

- [ ] **Step 3: Implement `withError()` helper**

Add to `UsageSnapshot` in `ClaudeUsageWidget/Shared/Models/UsageSnapshot.swift`:

```swift
func withError(_ message: String, tokenStats: TokenStats? = nil) -> UsageSnapshot {
    UsageSnapshot(
        fiveHour: fiveHour,
        sevenDay: sevenDay,
        sevenDaySonnet: sevenDaySonnet,
        sevenDayOpus: sevenDayOpus,
        tokenStats: tokenStats ?? self.tokenStats,
        lastUpdated: Date(),
        lastSuccessfulUpdate: lastSuccessfulUpdate,
        error: message
    )
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: ALL tests pass.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/Shared/Models/UsageSnapshot.swift \
       ClaudeUsageWidget/Tests/UsageSnapshotTests.swift
git commit -m "feat: add withError() helper to UsageSnapshot"
```

---

## Task 3: Update `toSnapshot()` to set `lastSuccessfulUpdate`

**Files:**
- Modify: `ClaudeUsageWidget/Shared/Models/APIModels.swift:9-26`
- Test: `ClaudeUsageWidget/Tests/APIModelsTests.swift`

**Dependencies:** Task 1

- [ ] **Step 1: Write failing test for `lastSuccessfulUpdate` on success**

Add to `ClaudeUsageWidget/Tests/APIModelsTests.swift`:

```swift
func testToSnapshotSetsLastSuccessfulUpdate() {
    let response = UsageApiResponse(
        fiveHour: UsageWindow(utilization: 45.0, resetsAt: "2026-03-21T18:00:00Z"),
        sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil
    )
    let stats = TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0)
    let beforeCall = Date()
    let snapshot = response.toSnapshot(tokenStats: stats)
    let afterCall = Date()

    XCTAssertNotNil(snapshot.lastSuccessfulUpdate)
    XCTAssertGreaterThanOrEqual(snapshot.lastSuccessfulUpdate!, beforeCall)
    XCTAssertLessThanOrEqual(snapshot.lastSuccessfulUpdate!, afterCall)
    XCTAssertNil(snapshot.error)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: `lastSuccessfulUpdate` is `nil` because `toSnapshot()` doesn't set it yet.

- [ ] **Step 3: Update `toSnapshot()` to include `lastSuccessfulUpdate: Date()`**

In `ClaudeUsageWidget/Shared/Models/APIModels.swift`, update the `toSnapshot` method:

```swift
func toSnapshot(tokenStats: TokenStats) -> UsageSnapshot {
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    func parseDate(_ s: String) -> Date {
        isoFormatter.date(from: s) ?? ISO8601DateFormatter().date(from: s) ?? Date()
    }

    return UsageSnapshot(
        fiveHour: fiveHour.map { UsageMetric(percent: $0.utilization, resetsAt: parseDate($0.resetsAt)) },
        sevenDay: sevenDay.map { UsageMetric(percent: $0.utilization, resetsAt: parseDate($0.resetsAt)) },
        sevenDaySonnet: sevenDaySonnet.map { UsageMetric(percent: $0.utilization, resetsAt: parseDate($0.resetsAt)) },
        sevenDayOpus: sevenDayOpus.map { UsageMetric(percent: $0.utilization, resetsAt: parseDate($0.resetsAt)) },
        tokenStats: tokenStats,
        lastUpdated: Date(),
        lastSuccessfulUpdate: Date(),
        error: nil
    )
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: ALL tests pass.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/Shared/Models/APIModels.swift \
       ClaudeUsageWidget/Tests/APIModelsTests.swift
git commit -m "feat: set lastSuccessfulUpdate in toSnapshot()"
```

---

## Task 4: Update UsageManager error paths to preserve cached data

**Files:**
- Modify: `ClaudeUsageWidget/App/UsageManager.swift:67-77,93-105`
- Test: `ClaudeUsageWidget/Tests/UsageManagerTests.swift`

**Dependencies:** Tasks 1, 2, 3

- [ ] **Step 1: Write failing tests for error-path caching behavior**

Add to `ClaudeUsageWidget/Tests/UsageManagerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Tests like `testAPIErrorPreservesCachedData` fail because the error path currently discards usage data.

- [ ] **Step 3: Implement error-path caching in `UsageManager.refresh()`**

Replace the **token error path** (lines 67-77) in `ClaudeUsageWidget/App/UsageManager.swift`:

```swift
} catch {
    let msg = describeError(error)
    debug.log("Token error: \(msg)", source: "App")
    let existing = snapshot ?? containerService.readSnapshot()
    if let existing, existing.hasUsageData {
        snapshot = existing.withError(msg, tokenStats: stats)
        do { try containerService.writeSnapshot(snapshot!) } catch {
            debug.log("WRITE FAILED on token error: \(error)", source: "App")
        }
        widgetReloader()
    } else {
        snapshot = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: stats,
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: msg
        )
    }
    return
}
```

Replace the **API error path** (lines 93-105):

```swift
} catch {
    if case APIError.unauthorized = error { cachedToken = nil }
    if case APIError.forbidden = error { cachedToken = nil }

    let msg = describeError(error)
    debug.log("API error: \(msg)", source: "App")
    let existing = snapshot ?? containerService.readSnapshot()
    if let existing, existing.hasUsageData {
        snapshot = existing.withError(msg, tokenStats: stats)
        do { try containerService.writeSnapshot(snapshot!) } catch {
            debug.log("WRITE FAILED on API error: \(error)", source: "App")
        }
        widgetReloader()
    } else {
        snapshot = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: stats,
            lastUpdated: Date(),
            lastSuccessfulUpdate: nil,
            error: msg
        )
    }
}
```

- [ ] **Step 4: Update existing test expectations**

In `ClaudeUsageWidget/Tests/UsageManagerTests.swift`:

**`testKeychainErrorSetsSnapshotError`** — currently asserts `reloadCount == 0`. After this change, if there is no prior cached data (which is the case in this test since it's the first call), reload still won't happen. No change needed.

**`testAPIErrorSetsSnapshotErrorButKeepsStats`** — currently asserts `reloadCount == 0`. Same situation — no prior cached data. No change needed.

- [ ] **Step 5: Run tests to verify they pass**

Expected: ALL tests pass including the 9 new ones.

- [ ] **Step 6: Commit**

```bash
git add ClaudeUsageWidget/App/UsageManager.swift \
       ClaudeUsageWidget/Tests/UsageManagerTests.swift
git commit -m "feat: preserve cached data on error in UsageManager"
```

---

## Task 5: Add "last updated" timestamp to popover error banner

**Files:**
- Modify: `ClaudeUsageWidget/App/Views/PopoverView.swift:96-98`

**Dependencies:** Task 1

- [ ] **Step 1: Update the error section in `contentView` to include "last updated" timestamp**

In `ClaudeUsageWidget/App/Views/PopoverView.swift`, replace the error block in `contentView`:

```swift
if let error = snapshot.error {
    errorBanner(error)
    if let lastSuccess = snapshot.lastSuccessfulUpdate {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text(lastSuccess, style: .relative)
                .font(.system(size: 9))
        }
        .foregroundStyle(AnthropicColors.creamMuted)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
xcodebuild build -project ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidget -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsageWidget/App/Views/PopoverView.swift
git commit -m "feat: add last-updated timestamp to popover error banner"
```

---

## Task 6: Add error indicator to widget views

**Files:**
- Modify: `ClaudeUsageWidget/Widget/Views/SmallWidgetView.swift`
- Modify: `ClaudeUsageWidget/Widget/Views/MediumWidgetView.swift`
- Modify: `ClaudeUsageWidget/Widget/Views/LargeWidgetView.swift`

**Dependencies:** Task 1

- [ ] **Step 1: Update `SmallWidgetView` — replace stale indicator area with error/stale conditional**

Replace `ClaudeUsageWidget/Widget/Views/SmallWidgetView.swift` content:

```swift
import SwiftUI

struct SmallWidgetView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Claude Usage")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)

            if let fiveHour = snapshot.fiveHour {
                WidgetUsageBar(label: "5-Hour", percent: fiveHour.percent, resetsAt: fiveHour.resetsAt)
            } else {
                Text("No data")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if snapshot.error != nil {
                errorIndicator
            } else if snapshot.isStale {
                staleIndicator
            }
        }
        .padding(12)
    }

    private var errorIndicator: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(AnthropicColors.coral)
            if let lastSuccess = snapshot.lastSuccessfulUpdate {
                Text(lastSuccess, style: .relative)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var staleIndicator: some View {
        HStack(spacing: 2) {
            Image(systemName: "clock")
                .font(.system(size: 8))
            Text(snapshot.lastUpdated, style: .relative)
                .font(.system(size: 8))
        }
        .foregroundStyle(.tertiary)
    }
}
```

- [ ] **Step 2: Update `MediumWidgetView` — same pattern**

Replace `ClaudeUsageWidget/Widget/Views/MediumWidgetView.swift` content:

```swift
import SwiftUI

struct MediumWidgetView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Usage")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnthropicColors.tan)

                if let fiveHour = snapshot.fiveHour {
                    WidgetUsageBar(label: "5-Hour", percent: fiveHour.percent, resetsAt: fiveHour.resetsAt)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(" ")
                    .font(.system(size: 11))

                if let sevenDay = snapshot.sevenDay {
                    WidgetUsageBar(label: "Weekly", percent: sevenDay.percent, resetsAt: sevenDay.resetsAt)
                }

                Spacer()

                if snapshot.error != nil {
                    errorIndicator
                } else if snapshot.isStale {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text(snapshot.lastUpdated, style: .relative)
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
    }

    private var errorIndicator: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(AnthropicColors.coral)
            if let lastSuccess = snapshot.lastSuccessfulUpdate {
                Text(lastSuccess, style: .relative)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
```

- [ ] **Step 3: Update `LargeWidgetView` — same pattern**

Replace `ClaudeUsageWidget/Widget/Views/LargeWidgetView.swift` content:

```swift
import SwiftUI

struct LargeWidgetView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Claude Code Usage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)

            if let fiveHour = snapshot.fiveHour {
                WidgetUsageBar(label: "5-Hour Window", percent: fiveHour.percent, resetsAt: fiveHour.resetsAt)
            }
            if let sevenDay = snapshot.sevenDay {
                WidgetUsageBar(label: "Weekly (All)", percent: sevenDay.percent, resetsAt: sevenDay.resetsAt)
            }
            if let sonnet = snapshot.sevenDaySonnet {
                WidgetUsageBar(label: "Weekly (Sonnet)", percent: sonnet.percent, resetsAt: sonnet.resetsAt)
            }
            if let opus = snapshot.sevenDayOpus {
                WidgetUsageBar(label: "Weekly (Opus)", percent: opus.percent, resetsAt: opus.resetsAt, isOpus: true)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(snapshot.tokenStats.formattedTodayTokens)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("This week")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(snapshot.tokenStats.formattedWeekTokens)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
            }

            Spacer()

            if snapshot.error != nil {
                errorIndicator
            } else if snapshot.isStale {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(snapshot.lastUpdated, style: .relative)
                        .font(.system(size: 8))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
    }

    private var errorIndicator: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(AnthropicColors.coral)
            if let lastSuccess = snapshot.lastSuccessfulUpdate {
                Text(lastSuccess, style: .relative)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
```

- [ ] **Step 4: Build to verify compilation**

```bash
xcodebuild build -project ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidget -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/Widget/Views/SmallWidgetView.swift \
       ClaudeUsageWidget/Widget/Views/MediumWidgetView.swift \
       ClaudeUsageWidget/Widget/Views/LargeWidgetView.swift
git commit -m "feat: add error indicator to widget views"
```

---

## Task 7: Update widget entry point condition to use `hasUsageData`

**Files:**
- Modify: `ClaudeUsageWidget/Widget/ClaudeUsageWidgetBundle.swift:17`

**Dependencies:** Task 1

- [ ] **Step 1: Update the condition in `UsageWidget.body`**

In `ClaudeUsageWidget/Widget/ClaudeUsageWidgetBundle.swift`, change line 17:

From:
```swift
if entry.snapshot.error != nil && entry.snapshot.fiveHour == nil {
```

To:
```swift
if entry.snapshot.error != nil && !entry.snapshot.hasUsageData {
```

- [ ] **Step 2: Build to verify compilation**

```bash
xcodebuild build -project ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidget -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run all tests to verify nothing broken**

```bash
xcodebuild test -project ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidget -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```

Expected: ALL tests pass.

- [ ] **Step 4: Commit**

```bash
git add ClaudeUsageWidget/Widget/ClaudeUsageWidgetBundle.swift
git commit -m "feat: use hasUsageData for widget error-vs-data routing"
```

---

## Task 8: Final integration — full test suite run

**Dependencies:** Tasks 1-7

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -project ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidget -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -30
```

Expected: ALL tests pass.

- [ ] **Step 2: Build the widget extension target to ensure it compiles**

```bash
xcodebuild build -project ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageWidgetExtension -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit if any fixes were needed**

Only if previous steps required fixes.

---

## Task Dependency Graph

```
Task 1 (UsageSnapshot model)
├── Task 2 (withError helper)
├── Task 3 (toSnapshot update)
├── Task 5 (popover UI)
├── Task 6 (widget views)
└── Task 7 (widget entry point)

Task 4 (UsageManager error paths) ← depends on Tasks 1, 2, 3

Task 8 (integration test) ← depends on all
```

**Parallelizable after Task 1:** Tasks 2, 3, 5, 6, 7 can all run in parallel.
**Task 4** must wait for Tasks 1, 2, and 3.
**Task 8** must wait for all.
