# Claude Usage Widget — Swift macOS App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native Swift/SwiftUI macOS menu bar app with WidgetKit desktop widgets that displays Claude Code usage metrics.

**Architecture:** Pure SwiftUI app with `MenuBarExtra` popover + WidgetKit extension. XcodeGen generates the Xcode project. Protocol-based DI enables TDD. Non-sandboxed main app reads Keychain; sandboxed widget extension reads from shared App Group container.

**Tech Stack:** Swift 5 language mode (Xcode 26.3 / Swift 6.2 compiler), SwiftUI, WidgetKit, Security framework, URLSession, XcodeGen, XCTest

**Spec:** `docs/superpowers/specs/2026-03-21-swift-macos-widget-design.md`

---

## Task 1: Project Scaffolding

**Files:**
- Create: `ClaudeUsageWidget/project.yml`
- Create: `ClaudeUsageWidget/App/Info.plist`
- Create: `ClaudeUsageWidget/App/App.entitlements`
- Create: `ClaudeUsageWidget/Widget/Info.plist`
- Create: `ClaudeUsageWidget/Widget/Widget.entitlements`

- [ ] **Step 1: Create directory structure**

```bash
cd /Users/andywendt/Desktop/code/claude-usage-widget
mkdir -p ClaudeUsageWidget/{Shared/{Models,Services,Theme},App/Views,Widget/Views,Tests}
```

- [ ] **Step 2: Create App Info.plist**

Create `ClaudeUsageWidget/App/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>claudeusage</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Create App entitlements**

Create `ClaudeUsageWidget/App/App.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.andywendt.claude-usage-widget</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Create Widget Info.plist**

Create `ClaudeUsageWidget/Widget/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
```

- [ ] **Step 5: Create Widget entitlements**

Create `ClaudeUsageWidget/Widget/Widget.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.andywendt.claude-usage-widget</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 6: Create project.yml for XcodeGen**

Create `ClaudeUsageWidget/project.yml`:
```yaml
name: ClaudeUsageWidget
options:
  bundleIdPrefix: com.andywendt
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "26.3"

settings:
  base:
    SWIFT_VERSION: "5"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    SWIFT_STRICT_CONCURRENCY: targeted

targets:
  ClaudeUsageWidget:
    type: application
    platform: macOS
    sources:
      - path: App
      - path: Shared
      - path: Assets.xcassets
    info:
      path: App/Info.plist
    entitlements:
      path: App/App.entitlements
    settings:
      base:
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
        PRODUCT_BUNDLE_IDENTIFIER: com.andywendt.claude-usage-widget
        INFOPLIST_FILE: App/Info.plist
        PRODUCT_NAME: "Claude Usage Widget"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    dependencies:
      - target: ClaudeUsageWidgetExtension
        embed: true
        codeSign: true

  ClaudeUsageWidgetExtension:
    type: app-extension
    platform: macOS
    product: ClaudeUsageWidgetExtension
    sources:
      - path: Widget
      - path: Shared
    info:
      path: Widget/Info.plist
    entitlements:
      path: Widget/Widget.entitlements
    settings:
      base:
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
        PRODUCT_BUNDLE_IDENTIFIER: com.andywendt.claude-usage-widget.widget
        INFOPLIST_FILE: Widget/Info.plist
        PRODUCT_NAME: ClaudeUsageWidgetExtension
        LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/../Frameworks @executable_path/../../../../Frameworks"

  ClaudeUsageWidgetTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests
    dependencies:
      - target: ClaudeUsageWidget
    settings:
      base:
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
        PRODUCT_BUNDLE_IDENTIFIER: com.andywendt.claude-usage-widget.tests
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Claude Usage Widget.app/Contents/MacOS/Claude Usage Widget"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

Note: We use Swift 5 language mode to avoid Swift 6 strict concurrency requirements that complicate mocks and test patterns. The compiler is still Swift 6.2 (Xcode 26.3) — this only affects the language mode. Can be upgraded to Swift 6 later.

- [ ] **Step 7: Create Assets.xcassets with AppIcon placeholder**

```bash
mkdir -p ClaudeUsageWidget/Assets.xcassets/AppIcon.appiconset
```

Create `ClaudeUsageWidget/Assets.xcassets/Contents.json`:
```json
{
  "info": { "version": 1, "author": "xcode" }
}
```

Create `ClaudeUsageWidget/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images": [
    { "idiom": "mac", "scale": "1x", "size": "128x128" },
    { "idiom": "mac", "scale": "2x", "size": "128x128" },
    { "idiom": "mac", "scale": "1x", "size": "256x256" },
    { "idiom": "mac", "scale": "2x", "size": "256x256" },
    { "idiom": "mac", "scale": "1x", "size": "512x512" },
    { "idiom": "mac", "scale": "2x", "size": "512x512" }
  ],
  "info": { "version": 1, "author": "xcode" }
}
```

Note: Icon images can be added later. Xcode will show a placeholder.

- [ ] **Step 8: Create minimal placeholder files so XcodeGen succeeds**

Create `ClaudeUsageWidget/App/ClaudeUsageWidgetApp.swift`:
```swift
import SwiftUI

@main
struct ClaudeUsageWidgetApp: App {
    var body: some Scene {
        MenuBarExtra("Claude Usage", systemImage: "gauge.medium") {
            Text("Loading...")
        }
        .menuBarExtraStyle(.window)
    }
}
```

Create `ClaudeUsageWidget/Widget/ClaudeUsageWidgetBundle.swift`:
```swift
import SwiftUI
import WidgetKit

@main
struct ClaudeUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        UsageWidget()
    }
}

struct UsageWidget: Widget {
    let kind = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { entry in
            Text("Claude Usage")
        }
        .configurationDisplayName("Claude Usage")
        .description("Monitor your Claude Code usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: Date())], policy: .atEnd))
    }
}
```

Create `ClaudeUsageWidget/Tests/PlaceholderTest.swift`:
```swift
import XCTest

final class PlaceholderTest: XCTestCase {
    func testProjectBuilds() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 8: Generate Xcode project and verify build**

```bash
cd /Users/andywendt/Desktop/code/claude-usage-widget/ClaudeUsageWidget
xcodegen
xcodebuild build -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidget -destination 'platform=macOS' -quiet
```

Expected: Build succeeds with no errors.

- [ ] **Step 9: Run placeholder test**

```bash
cd /Users/andywendt/Desktop/code/claude-usage-widget/ClaudeUsageWidget
xcodebuild test -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidgetTests -destination 'platform=macOS' -quiet
```

Expected: 1 test passes.

- [ ] **Step 10: Commit**

```bash
git add ClaudeUsageWidget/
git commit -m "scaffold: Xcode project with XcodeGen, app + widget + test targets"
```

---

## Task 2: Shared Data Models (TDD)

**Files:**
- Create: `ClaudeUsageWidget/Shared/Models/UsageSnapshot.swift`
- Create: `ClaudeUsageWidget/Tests/UsageSnapshotTests.swift`

- [ ] **Step 1: Write failing tests for UsageMetric**

Create `ClaudeUsageWidget/Tests/UsageSnapshotTests.swift`:
```swift
import XCTest
@testable import ClaudeUsageWidget

final class UsageMetricTests: XCTestCase {
    func testEncodeDecode() throws {
        let metric = UsageMetric(percent: 45.5, resetsAt: Date(timeIntervalSince1970: 1711000000))
        let data = try JSONEncoder().encode(metric)
        let decoded = try JSONDecoder().decode(UsageMetric.self, from: data)
        XCTAssertEqual(decoded.percent, 45.5)
        XCTAssertEqual(decoded.resetsAt, metric.resetsAt)
    }

    func testPercentClamped() {
        let metric = UsageMetric(percent: 150.0, resetsAt: Date())
        XCTAssertEqual(metric.clampedPercent, 100.0)

        let negative = UsageMetric(percent: -5.0, resetsAt: Date())
        XCTAssertEqual(negative.clampedPercent, 0.0)

        let normal = UsageMetric(percent: 72.3, resetsAt: Date())
        XCTAssertEqual(normal.clampedPercent, 72.3)
    }
}

final class TokenStatsTests: XCTestCase {
    func testEncodeDecode() throws {
        let stats = TokenStats(todayTokens: 15000, weekTokens: 85000, todayMessages: 42, weekMessages: 210)
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(TokenStats.self, from: data)
        XCTAssertEqual(decoded.todayTokens, 15000)
        XCTAssertEqual(decoded.weekTokens, 85000)
        XCTAssertEqual(decoded.todayMessages, 42)
        XCTAssertEqual(decoded.weekMessages, 210)
    }

    func testFormattedTokens() {
        let stats = TokenStats(todayTokens: 1_500_000, weekTokens: 42_000, todayMessages: 500, weekMessages: 3500)
        XCTAssertEqual(stats.formattedTodayTokens, "1.5M")
        XCTAssertEqual(stats.formattedWeekTokens, "42.0K")
    }

    func testFormattedTokensSmallValues() {
        let stats = TokenStats(todayTokens: 750, weekTokens: 0, todayMessages: 3, weekMessages: 10)
        XCTAssertEqual(stats.formattedTodayTokens, "750")
        XCTAssertEqual(stats.formattedWeekTokens, "0")
    }
}

final class UsageSnapshotTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 45.0, resetsAt: Date(timeIntervalSince1970: 1711000000)),
            sevenDay: UsageMetric(percent: 30.0, resetsAt: Date(timeIntervalSince1970: 1711500000)),
            sevenDaySonnet: nil,
            sevenDayOpus: UsageMetric(percent: 88.0, resetsAt: Date(timeIntervalSince1970: 1711500000)),
            tokenStats: TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50),
            lastUpdated: Date(timeIntervalSince1970: 1711000000),
            error: nil
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(UsageSnapshot.self, from: data)
        XCTAssertEqual(decoded.fiveHour?.percent, 45.0)
        XCTAssertNil(decoded.sevenDaySonnet)
        XCTAssertEqual(decoded.sevenDayOpus?.percent, 88.0)
        XCTAssertNil(decoded.error)
    }

    func testWithError() throws {
        let snapshot = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: "API error 401: Unauthorized"
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(UsageSnapshot.self, from: data)
        XCTAssertEqual(decoded.error, "API error 401: Unauthorized")
        XCTAssertNil(decoded.fiveHour)
    }

    func testIsStale() {
        let fresh = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: nil
        )
        XCTAssertFalse(fresh.isStale)

        let stale = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date().addingTimeInterval(-31 * 60),
            error: nil
        )
        XCTAssertTrue(stale.isStale)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/andywendt/Desktop/code/claude-usage-widget/ClaudeUsageWidget
xcodebuild test -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidgetTests -destination 'platform=macOS' -quiet 2>&1 | tail -20
```

Expected: FAIL — `UsageMetric`, `TokenStats`, `UsageSnapshot` not defined.

- [ ] **Step 3: Implement data models**

Create `ClaudeUsageWidget/Shared/Models/UsageSnapshot.swift`:
```swift
import Foundation

struct UsageMetric: Codable, Equatable {
    let percent: Double
    let resetsAt: Date

    var clampedPercent: Double {
        min(max(percent, 0.0), 100.0)
    }
}

struct TokenStats: Codable, Equatable {
    let todayTokens: Int
    let weekTokens: Int
    let todayMessages: Int
    let weekMessages: Int

    var formattedTodayTokens: String {
        Self.formatNumber(todayTokens)
    }

    var formattedWeekTokens: String {
        Self.formatNumber(weekTokens)
    }

    static func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

struct UsageSnapshot: Codable, Equatable {
    let fiveHour: UsageMetric?
    let sevenDay: UsageMetric?
    let sevenDaySonnet: UsageMetric?
    let sevenDayOpus: UsageMetric?
    let tokenStats: TokenStats
    let lastUpdated: Date
    let error: String?

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 30 * 60
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/andywendt/Desktop/code/claude-usage-widget/ClaudeUsageWidget
xcodebuild test -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidgetTests -destination 'platform=macOS' -quiet 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/Shared/Models/UsageSnapshot.swift ClaudeUsageWidget/Tests/UsageSnapshotTests.swift
git commit -m "feat: add UsageSnapshot, UsageMetric, TokenStats data models with tests"
```

---

## Task 3: API Response Models (TDD)

**Files:**
- Create: `ClaudeUsageWidget/Shared/Models/APIModels.swift`
- Create: `ClaudeUsageWidget/Tests/APIModelsTests.swift`

- [ ] **Step 1: Write failing tests for API response parsing**

Create `ClaudeUsageWidget/Tests/APIModelsTests.swift`:
```swift
import XCTest
@testable import ClaudeUsageWidget

final class APIModelsTests: XCTestCase {

    func testDecodeFullResponse() throws {
        let json = """
        {
            "five_hour": {"utilization": 45.5, "resets_at": "2026-03-21T18:00:00Z"},
            "seven_day": {"utilization": 30.0, "resets_at": "2026-03-25T00:00:00Z"},
            "seven_day_sonnet": {"utilization": 22.0, "resets_at": "2026-03-25T00:00:00Z"},
            "seven_day_opus": {"utilization": 88.0, "resets_at": "2026-03-25T00:00:00Z"}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(UsageApiResponse.self, from: json)

        XCTAssertEqual(response.fiveHour?.utilization, 45.5)
        XCTAssertEqual(response.sevenDay?.utilization, 30.0)
        XCTAssertEqual(response.sevenDaySonnet?.utilization, 22.0)
        XCTAssertEqual(response.sevenDayOpus?.utilization, 88.0)
    }

    func testDecodePartialResponse() throws {
        let json = """
        {
            "five_hour": {"utilization": 10.0, "resets_at": "2026-03-21T18:00:00Z"}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(UsageApiResponse.self, from: json)

        XCTAssertEqual(response.fiveHour?.utilization, 10.0)
        XCTAssertNil(response.sevenDay)
        XCTAssertNil(response.sevenDaySonnet)
        XCTAssertNil(response.sevenDayOpus)
    }

    func testDecodeStatsCacheJson() throws {
        let json = """
        {
            "dailyActivity": [
                {"date": "2026-03-21", "messageCount": 42, "sessionCount": 5, "toolCallCount": 120},
                {"date": "2026-03-20", "messageCount": 30, "sessionCount": 3, "toolCallCount": 80}
            ],
            "dailyModelTokens": [
                {"date": "2026-03-21", "tokensByModel": {"claude-sonnet": 10000, "claude-opus": 5000}},
                {"date": "2026-03-20", "tokensByModel": {"claude-sonnet": 8000}}
            ],
            "lastComputedDate": "2026-03-21"
        }
        """.data(using: .utf8)!

        let cache = try JSONDecoder().decode(StatsCache.self, from: json)

        XCTAssertEqual(cache.dailyActivity?.count, 2)
        XCTAssertEqual(cache.dailyActivity?.first?.messageCount, 42)
        XCTAssertEqual(cache.dailyModelTokens?.first?.tokensByModel["claude-sonnet"], 10000)
    }

    func testDecodeEmptyStatsCache() throws {
        let json = "{}".data(using: .utf8)!
        let cache = try JSONDecoder().decode(StatsCache.self, from: json)
        XCTAssertNil(cache.dailyActivity)
        XCTAssertNil(cache.dailyModelTokens)
    }

    func testToUsageSnapshot() {
        let response = UsageApiResponse(
            fiveHour: UsageWindow(utilization: 45.0, resetsAt: "2026-03-21T18:00:00Z"),
            sevenDay: UsageWindow(utilization: 30.0, resetsAt: "2026-03-25T00:00:00Z"),
            sevenDaySonnet: nil,
            sevenDayOpus: nil
        )
        let stats = TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50)
        let snapshot = response.toSnapshot(tokenStats: stats)

        XCTAssertEqual(snapshot.fiveHour?.percent, 45.0)
        XCTAssertEqual(snapshot.sevenDay?.percent, 30.0)
        XCTAssertNil(snapshot.sevenDaySonnet)
        XCTAssertNil(snapshot.error)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `UsageApiResponse`, `UsageWindow`, `StatsCache` not defined.

- [ ] **Step 3: Implement API models**

Create `ClaudeUsageWidget/Shared/Models/APIModels.swift`:
```swift
import Foundation

struct UsageApiResponse: Codable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDaySonnet: UsageWindow?
    let sevenDayOpus: UsageWindow?

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
            error: nil
        )
    }
}

struct UsageWindow: Codable {
    let utilization: Double
    let resetsAt: String
}

// MARK: - Local Stats Cache

struct StatsCache: Codable {
    let dailyActivity: [DailyActivity]?
    let dailyModelTokens: [DailyTokens]?
    let lastComputedDate: String?
}

struct DailyActivity: Codable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
}

struct DailyTokens: Codable {
    let date: String
    let tokensByModel: [String: Int]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/Shared/Models/APIModels.swift ClaudeUsageWidget/Tests/APIModelsTests.swift
git commit -m "feat: add API response and stats cache models with tests"
```

---

## Task 4: Service Protocols (TDD)

**Files:**
- Create: `ClaudeUsageWidget/Shared/Services/ServiceProtocols.swift`
- Create: `ClaudeUsageWidget/Tests/Mocks.swift`

- [ ] **Step 1: Create service protocols and mock implementations**

Create `ClaudeUsageWidget/Shared/Services/ServiceProtocols.swift`:
```swift
import Foundation

protocol KeychainServiceProtocol {
    func readToken() throws -> String
}

protocol APIServiceProtocol {
    func fetchUsage(token: String) async throws -> UsageApiResponse
}

protocol StatsServiceProtocol {
    func readStats() -> TokenStats
}

protocol SharedContainerServiceProtocol {
    func writeSnapshot(_ snapshot: UsageSnapshot) throws
    func readSnapshot() -> UsageSnapshot?
}

enum KeychainError: Error, Equatable {
    case notFound
    case accessDenied
    case invalidData(String)
}

enum APIError: Error, Equatable {
    case unauthorized
    case forbidden
    case serverError(Int)
    case networkError(String)
    case decodingError(String)
}
```

Create `ClaudeUsageWidget/Tests/Mocks.swift`:
```swift
import Foundation
@testable import ClaudeUsageWidget

final class MockKeychainService: KeychainServiceProtocol {
    var tokenToReturn: String?
    var errorToThrow: Error?
    var readTokenCallCount = 0

    func readToken() throws -> String {
        readTokenCallCount += 1
        if let error = errorToThrow { throw error }
        guard let token = tokenToReturn else { throw KeychainError.notFound }
        return token
    }
}

final class MockAPIService: APIServiceProtocol {
    var responseToReturn: UsageApiResponse?
    var errorToThrow: Error?
    var lastTokenUsed: String?

    func fetchUsage(token: String) async throws -> UsageApiResponse {
        lastTokenUsed = token
        if let error = errorToThrow { throw error }
        guard let response = responseToReturn else {
            throw APIError.serverError(500)
        }
        return response
    }
}

final class MockStatsService: StatsServiceProtocol {
    var statsToReturn = TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0)

    func readStats() -> TokenStats {
        statsToReturn
    }
}

final class MockSharedContainerService: SharedContainerServiceProtocol {
    var storedSnapshot: UsageSnapshot?
    var writeError: Error?

    func writeSnapshot(_ snapshot: UsageSnapshot) throws {
        if let error = writeError { throw error }
        storedSnapshot = snapshot
    }

    func readSnapshot() -> UsageSnapshot? {
        storedSnapshot
    }
}

final class MockWidgetReloader {
    var reloadCount = 0
    func reload() { reloadCount += 1 }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidgetTests -destination 'platform=macOS' -quiet
```

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsageWidget/Shared/Services/ServiceProtocols.swift ClaudeUsageWidget/Tests/Mocks.swift
git commit -m "feat: add service protocols and mock implementations for TDD"
```

---

## Task 5: KeychainService (TDD)

**Files:**
- Create: `ClaudeUsageWidget/Shared/Services/KeychainService.swift`
- Create: `ClaudeUsageWidget/Tests/KeychainServiceTests.swift`

- [ ] **Step 1: Write failing tests for credential JSON parsing**

Create `ClaudeUsageWidget/Tests/KeychainServiceTests.swift`:
```swift
import XCTest
@testable import ClaudeUsageWidget

final class KeychainParsingTests: XCTestCase {

    func testExtractTokenFromValidJSON() throws {
        let json = """
        {
            "claudeAiOauth": {
                "accessToken": "sk-ant-oaut-test-token-12345"
            }
        }
        """.data(using: .utf8)!

        let token = try KeychainService.extractToken(from: json)
        XCTAssertEqual(token, "sk-ant-oaut-test-token-12345")
    }

    func testExtractTokenMissingOAuthKey() {
        let json = """
        {"someOtherKey": {"accessToken": "token"}}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try KeychainService.extractToken(from: json)) { error in
            XCTAssertEqual(error as? KeychainError, .invalidData("No OAuth token found in credentials"))
        }
    }

    func testExtractTokenMissingAccessToken() {
        let json = """
        {"claudeAiOauth": {"refreshToken": "rt-123"}}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try KeychainService.extractToken(from: json)) { error in
            XCTAssertEqual(error as? KeychainError, .invalidData("No OAuth token found in credentials"))
        }
    }

    func testExtractTokenInvalidJSON() {
        let json = "not json at all".data(using: .utf8)!

        XCTAssertThrowsError(try KeychainService.extractToken(from: json)) { error in
            guard case KeychainError.invalidData = error as? KeychainError else {
                XCTFail("Expected invalidData error")
                return
            }
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `KeychainService.extractToken(from:)` not defined.

- [ ] **Step 3: Implement KeychainService**

Create `ClaudeUsageWidget/Shared/Services/KeychainService.swift`:
```swift
import Foundation
import Security

final class KeychainService: KeychainServiceProtocol {

    func readToken() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecAttrAccount as String: NSUserName(),
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData("Unexpected Keychain data format")
            }
            return try Self.extractToken(from: data)
        case errSecItemNotFound:
            throw KeychainError.notFound
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw KeychainError.accessDenied
        default:
            throw KeychainError.invalidData("Keychain error: \(status)")
        }
    }

    static func extractToken(from data: Data) throws -> String {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw KeychainError.invalidData("Failed to parse credentials JSON: \(error.localizedDescription)")
        }

        guard let dict = json as? [String: Any],
              let oauth = dict["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            throw KeychainError.invalidData("No OAuth token found in credentials")
        }

        return token
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/Shared/Services/KeychainService.swift ClaudeUsageWidget/Tests/KeychainServiceTests.swift
git commit -m "feat: add KeychainService with credential JSON parsing and tests"
```

---

## Task 6: APIService (TDD)

**Files:**
- Create: `ClaudeUsageWidget/Shared/Services/APIService.swift`
- Create: `ClaudeUsageWidget/Tests/APIServiceTests.swift`

- [ ] **Step 1: Write failing tests using URLProtocol mock**

Create `ClaudeUsageWidget/Tests/APIServiceTests.swift`:
```swift
import XCTest
@testable import ClaudeUsageWidget

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class APIServiceTests: XCTestCase {
    var service: APIService!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        service = APIService(session: URLSession(configuration: config))
    }

    func testFetchUsageSuccess() async throws {
        let responseJSON = """
        {
            "five_hour": {"utilization": 45.5, "resets_at": "2026-03-21T18:00:00Z"},
            "seven_day": {"utilization": 30.0, "resets_at": "2026-03-25T00:00:00Z"}
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJSON)
        }

        let result = try await service.fetchUsage(token: "test-token")
        XCTAssertEqual(result.fiveHour?.utilization, 45.5)
        XCTAssertEqual(result.sevenDay?.utilization, 30.0)
    }

    func testFetchUsage401ThrowsUnauthorized() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.fetchUsage(token: "bad-token")
            XCTFail("Expected unauthorized error")
        } catch APIError.unauthorized {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchUsage403ThrowsForbidden() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.fetchUsage(token: "bad-token")
            XCTFail("Expected forbidden error")
        } catch APIError.forbidden {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchUsage500ThrowsServerError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.fetchUsage(token: "token")
            XCTFail("Expected server error")
        } catch APIError.serverError(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `APIService` init and `fetchUsage` not matching expected signatures.

- [ ] **Step 3: Implement APIService**

Create `ClaudeUsageWidget/Shared/Services/APIService.swift`:
```swift
import Foundation

final class APIService: APIServiceProtocol {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage(token: String) async throws -> UsageApiResponse {
        var request = URLRequest(url: baseURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(UsageApiResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/Shared/Services/APIService.swift ClaudeUsageWidget/Tests/APIServiceTests.swift
git commit -m "feat: add APIService with URLSession, auth headers, error handling, and tests"
```

---

## Task 7: StatsService (TDD)

**Files:**
- Create: `ClaudeUsageWidget/Shared/Services/StatsService.swift`
- Create: `ClaudeUsageWidget/Tests/StatsServiceTests.swift`
- Create: `ClaudeUsageWidget/Tests/Fixtures/stats-cache.json`

- [ ] **Step 1: Write failing tests**

Create `ClaudeUsageWidget/Tests/Fixtures/` directory and `ClaudeUsageWidget/Tests/Fixtures/stats-cache.json`:
```json
{
    "dailyActivity": [
        {"date": "TODAY_PLACEHOLDER", "messageCount": 42, "sessionCount": 5, "toolCallCount": 120},
        {"date": "YESTERDAY_PLACEHOLDER", "messageCount": 30, "sessionCount": 3, "toolCallCount": 80},
        {"date": "OLD_PLACEHOLDER", "messageCount": 100, "sessionCount": 10, "toolCallCount": 300}
    ],
    "dailyModelTokens": [
        {"date": "TODAY_PLACEHOLDER", "tokensByModel": {"claude-sonnet": 10000, "claude-opus": 5000}},
        {"date": "YESTERDAY_PLACEHOLDER", "tokensByModel": {"claude-sonnet": 8000}},
        {"date": "OLD_PLACEHOLDER", "tokensByModel": {"claude-sonnet": 50000}}
    ],
    "lastComputedDate": "TODAY_PLACEHOLDER"
}
```

Create `ClaudeUsageWidget/Tests/StatsServiceTests.swift`:
```swift
import XCTest
@testable import ClaudeUsageWidget

final class StatsServiceTests: XCTestCase {

    func testCalculateTokenStatsFromCache() {
        let today = Self.dateString(daysAgo: 0)
        let yesterday = Self.dateString(daysAgo: 1)
        let twoWeeksAgo = Self.dateString(daysAgo: 14)

        let cache = StatsCache(
            dailyActivity: [
                DailyActivity(date: today, messageCount: 42, sessionCount: 5, toolCallCount: 120),
                DailyActivity(date: yesterday, messageCount: 30, sessionCount: 3, toolCallCount: 80),
                DailyActivity(date: twoWeeksAgo, messageCount: 100, sessionCount: 10, toolCallCount: 300)
            ],
            dailyModelTokens: [
                DailyTokens(date: today, tokensByModel: ["claude-sonnet": 10000, "claude-opus": 5000]),
                DailyTokens(date: yesterday, tokensByModel: ["claude-sonnet": 8000]),
                DailyTokens(date: twoWeeksAgo, tokensByModel: ["claude-sonnet": 50000])
            ],
            lastComputedDate: today
        )

        let stats = StatsService.calculateTokenStats(from: cache)

        XCTAssertEqual(stats.todayTokens, 15000)    // 10000 + 5000
        XCTAssertEqual(stats.weekTokens, 23000)      // 15000 + 8000 (twoWeeksAgo excluded)
        XCTAssertEqual(stats.todayMessages, 42)
        XCTAssertEqual(stats.weekMessages, 72)        // 42 + 30 (twoWeeksAgo excluded)
    }

    func testCalculateTokenStatsEmptyCache() {
        let cache = StatsCache(dailyActivity: nil, dailyModelTokens: nil, lastComputedDate: nil)
        let stats = StatsService.calculateTokenStats(from: cache)

        XCTAssertEqual(stats.todayTokens, 0)
        XCTAssertEqual(stats.weekTokens, 0)
        XCTAssertEqual(stats.todayMessages, 0)
        XCTAssertEqual(stats.weekMessages, 0)
    }

    func testReadStatsFromFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let today = Self.dateString(daysAgo: 0)
        let json = """
        {
            "dailyActivity": [{"date": "\(today)", "messageCount": 10, "sessionCount": 1, "toolCallCount": 5}],
            "dailyModelTokens": [{"date": "\(today)", "tokensByModel": {"claude-sonnet": 3000}}]
        }
        """
        let filePath = tmpDir.appendingPathComponent("stats-cache.json")
        try json.write(to: filePath, atomically: true, encoding: .utf8)

        let service = StatsService(statsFilePath: filePath.path)
        let stats = service.readStats()

        XCTAssertEqual(stats.todayTokens, 3000)
        XCTAssertEqual(stats.todayMessages, 10)
    }

    func testReadStatsMissingFile() {
        let service = StatsService(statsFilePath: "/nonexistent/path/stats-cache.json")
        let stats = service.readStats()

        XCTAssertEqual(stats.todayTokens, 0)
        XCTAssertEqual(stats.weekTokens, 0)
    }

    private static func dateString(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `StatsService` not defined.

- [ ] **Step 3: Implement StatsService**

Create `ClaudeUsageWidget/Shared/Services/StatsService.swift`:
```swift
import Foundation

final class StatsService: StatsServiceProtocol {
    private let statsFilePath: String

    init(statsFilePath: String? = nil) {
        if let path = statsFilePath {
            self.statsFilePath = path
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.statsFilePath = home.appendingPathComponent(".claude/stats-cache.json").path
        }
    }

    func readStats() -> TokenStats {
        guard let data = FileManager.default.contents(atPath: statsFilePath),
              let cache = try? JSONDecoder().decode(StatsCache.self, from: data) else {
            return TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0)
        }
        return Self.calculateTokenStats(from: cache)
    }

    static func calculateTokenStats(from cache: StatsCache) -> TokenStats {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let weekAgo = formatter.string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!)

        var todayTokens = 0
        var weekTokens = 0
        var todayMessages = 0
        var weekMessages = 0

        if let dailyTokens = cache.dailyModelTokens {
            for day in dailyTokens {
                let dayTotal = day.tokensByModel.values.reduce(0, +)
                if day.date == today { todayTokens = dayTotal }
                if day.date >= weekAgo { weekTokens += dayTotal }
            }
        }

        if let dailyActivity = cache.dailyActivity {
            for day in dailyActivity {
                if day.date == today { todayMessages = day.messageCount }
                if day.date >= weekAgo { weekMessages += day.messageCount }
            }
        }

        return TokenStats(
            todayTokens: todayTokens,
            weekTokens: weekTokens,
            todayMessages: todayMessages,
            weekMessages: weekMessages
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/Shared/Services/StatsService.swift ClaudeUsageWidget/Tests/StatsServiceTests.swift ClaudeUsageWidget/Tests/Fixtures/
git commit -m "feat: add StatsService with stats-cache.json parsing and tests"
```

---

## Task 8: SharedContainerService (TDD)

**Files:**
- Create: `ClaudeUsageWidget/Shared/Services/SharedContainerService.swift`
- Create: `ClaudeUsageWidget/Tests/SharedContainerServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Create `ClaudeUsageWidget/Tests/SharedContainerServiceTests.swift`:
```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `SharedContainerService` not defined.

- [ ] **Step 3: Implement SharedContainerService**

Create `ClaudeUsageWidget/Shared/Services/SharedContainerService.swift`:
```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/Shared/Services/SharedContainerService.swift ClaudeUsageWidget/Tests/SharedContainerServiceTests.swift
git commit -m "feat: add SharedContainerService with App Group read/write and tests"
```

---

## Task 9: UsageManager (TDD)

**Files:**
- Create: `ClaudeUsageWidget/App/UsageManager.swift`
- Create: `ClaudeUsageWidget/Tests/UsageManagerTests.swift`

- [ ] **Step 1: Write failing tests**

Create `ClaudeUsageWidget/Tests/UsageManagerTests.swift`:
```swift
import XCTest
@testable import ClaudeUsageWidget

final class UsageManagerTests: XCTestCase {
    var manager: UsageManager!
    var mockKeychain: MockKeychainService!
    var mockAPI: MockAPIService!
    var mockStats: MockStatsService!
    var mockContainer: MockSharedContainerService!
    var mockReloader: MockWidgetReloader!

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

    func testKeychainErrorSetsSnapshotError() async {
        mockKeychain.errorToThrow = KeychainError.notFound

        await manager.refresh()

        XCTAssertNotNil(manager.snapshot?.error)
        XCTAssertTrue(manager.snapshot!.error!.contains("not found") || manager.snapshot!.error!.contains("Keychain"))
    }

    func testAPIErrorSetsSnapshotErrorButKeepsStats() async {
        mockKeychain.tokenToReturn = "test-token"
        mockAPI.errorToThrow = APIError.serverError(500)
        mockStats.statsToReturn = TokenStats(todayTokens: 3000, weekTokens: 15000, todayMessages: 5, weekMessages: 20)

        await manager.refresh()

        XCTAssertNotNil(manager.snapshot?.error)
        XCTAssertEqual(manager.snapshot?.tokenStats.todayTokens, 3000) // stats still populated
    }

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
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `UsageManager` not defined with expected init signature.

- [ ] **Step 3: Implement UsageManager**

Create `ClaudeUsageWidget/App/UsageManager.swift`:
```swift
import Foundation
import WidgetKit

@MainActor
final class UsageManager: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var isLoading = false

    private let keychainService: KeychainServiceProtocol
    private let apiService: APIServiceProtocol
    private let statsService: StatsServiceProtocol
    private let containerService: SharedContainerServiceProtocol
    private let widgetReloader: () -> Void
    private var cachedToken: String?
    private var timer: Timer?

    init(
        keychainService: KeychainServiceProtocol = KeychainService(),
        apiService: APIServiceProtocol = APIService(),
        statsService: StatsServiceProtocol = StatsService(),
        containerService: SharedContainerServiceProtocol = SharedContainerService(),
        widgetReloader: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsageWidget") }
    ) {
        self.keychainService = keychainService
        self.apiService = apiService
        self.statsService = statsService
        self.containerService = containerService
        self.widgetReloader = widgetReloader
    }

    func startTimer(interval: TimeInterval = 300) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let stats = statsService.readStats()

        // Get token
        let token: String
        do {
            if let cached = cachedToken {
                token = cached
            } else {
                token = try keychainService.readToken()
                cachedToken = token
            }
        } catch {
            snapshot = UsageSnapshot(
                fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
                tokenStats: stats,
                lastUpdated: Date(),
                error: describeError(error)
            )
            return
        }

        // Fetch API
        do {
            let response = try await apiService.fetchUsage(token: token)
            let newSnapshot = response.toSnapshot(tokenStats: stats)
            snapshot = newSnapshot
            try? containerService.writeSnapshot(newSnapshot)
            widgetReloader()
        } catch {
            if case APIError.unauthorized = error { cachedToken = nil }
            if case APIError.forbidden = error { cachedToken = nil }

            snapshot = UsageSnapshot(
                fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
                tokenStats: stats,
                lastUpdated: Date(),
                error: describeError(error)
            )
        }
    }

    private func describeError(_ error: Error) -> String {
        switch error {
        case KeychainError.notFound:
            return "No credentials found. Please sign in to Claude Code first."
        case KeychainError.accessDenied:
            return "Keychain access denied. Please allow access when prompted."
        case KeychainError.invalidData(let msg):
            return "Invalid credentials: \(msg)"
        case APIError.unauthorized:
            return "Authentication failed. Token may have expired."
        case APIError.forbidden:
            return "Access forbidden."
        case APIError.serverError(let code):
            return "Server error (\(code))."
        case APIError.networkError(let msg):
            return "Network error: \(msg)"
        default:
            return "Error: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/App/UsageManager.swift ClaudeUsageWidget/Tests/UsageManagerTests.swift
git commit -m "feat: add UsageManager with refresh lifecycle, token caching, error handling, tests"
```

---

## Task 10: Anthropic Theme Colors

**Files:**
- Create: `ClaudeUsageWidget/Shared/Theme/AnthropicColors.swift`

- [ ] **Step 1: Implement color definitions**

Create `ClaudeUsageWidget/Shared/Theme/AnthropicColors.swift`:
```swift
import SwiftUI

enum AnthropicColors {
    static let tan = Color(red: 0.831, green: 0.647, blue: 0.455)           // #D4A574
    static let tanLight = Color(red: 0.910, green: 0.831, blue: 0.737)      // #E8D4BC
    static let tanDark = Color(red: 0.722, green: 0.584, blue: 0.416)       // #B8956A
    static let coral = Color(red: 0.878, green: 0.478, blue: 0.373)         // #E07A5F
    static let coralLight = Color(red: 0.941, green: 0.627, blue: 0.565)    // #F0A090
    static let charcoal = Color(red: 0.176, green: 0.165, blue: 0.149)      // #2D2A26
    static let cream = Color(red: 0.980, green: 0.969, blue: 0.949)         // #FAF7F2
    static let creamMuted = Color(red: 0.980, green: 0.969, blue: 0.949).opacity(0.6)
    static let dangerDark = Color(red: 0.659, green: 0.314, blue: 0.251)    // #A85040
    static let opusBrown = Color(red: 0.545, green: 0.451, blue: 0.333)     // #8B7355

    // Gradients
    static let normalGradient = LinearGradient(
        colors: [tanDark, tan], startPoint: .leading, endPoint: .trailing
    )
    static let opusGradient = LinearGradient(
        colors: [opusBrown, tanLight], startPoint: .leading, endPoint: .trailing
    )
    static let warningGradient = LinearGradient(
        colors: [coral, coralLight], startPoint: .leading, endPoint: .trailing
    )
    static let dangerGradient = LinearGradient(
        colors: [dangerDark, coral], startPoint: .leading, endPoint: .trailing
    )
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidget -destination 'platform=macOS' -quiet
```

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsageWidget/Shared/Theme/AnthropicColors.swift
git commit -m "feat: add Anthropic brand color definitions and gradients"
```

---

## Task 11: UsageBarView, ResetTimerView, TokenStatsView

**Files:**
- Create: `ClaudeUsageWidget/App/Views/ResetTimerView.swift`
- Create: `ClaudeUsageWidget/App/Views/UsageBarView.swift`
- Create: `ClaudeUsageWidget/App/Views/TokenStatsView.swift`

- [ ] **Step 1: Create ResetTimerView first (UsageBarView depends on it)**

Create `ClaudeUsageWidget/App/Views/ResetTimerView.swift`:
```swift
import SwiftUI

struct ResetTimerView: View {
    let resetsAt: Date

    var body: some View {
        Text(timerText)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(AnthropicColors.creamMuted)
    }

    private var timerText: String {
        let remaining = resetsAt.timeIntervalSince(Date())
        guard remaining > 0 else { return "Resetting..." }

        let totalMinutes = Int(remaining) / 60
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "Resets in \(days)d \(hours)h"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }
}
```

- [ ] **Step 2: Implement progress bar view**

Create `ClaudeUsageWidget/App/Views/UsageBarView.swift`:
```swift
import SwiftUI

struct UsageBarView: View {
    let label: String
    let metric: UsageMetric?
    var isOpus: Bool = false

    var body: some View {
        if let metric {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AnthropicColors.creamMuted)

                    Spacer()

                    Text("\(Int(metric.clampedPercent))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AnthropicColors.cream)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AnthropicColors.tan.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(gradient(for: metric.clampedPercent))
                            .frame(width: geo.size.width * metric.clampedPercent / 100)
                            .opacity(metric.clampedPercent >= 90 ? pulseOpacity : 1.0)
                            .onAppear {
                                if metric.clampedPercent >= 90 {
                                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                        pulseOpacity = 0.7
                                    }
                                }
                            }
                    }
                }
                .frame(height: 8)

                ResetTimerView(resetsAt: metric.resetsAt)
            }
        }
    }

    @State private var pulseOpacity: Double = 1.0

    private func gradient(for percent: Double) -> LinearGradient {
        if percent >= 90 {
            return AnthropicColors.dangerGradient
        } else if percent >= 70 {
            return AnthropicColors.warningGradient
        } else if isOpus {
            return AnthropicColors.opusGradient
        } else {
            return AnthropicColors.normalGradient
        }
    }
}
```

- [ ] **Step 3: Implement TokenStatsView**

Create `ClaudeUsageWidget/App/Views/TokenStatsView.swift`:
```swift
import SwiftUI

struct TokenStatsView: View {
    let stats: TokenStats

    var body: some View {
        VStack(spacing: 4) {
            statsRow(label: "Today:", value: stats.formattedTodayTokens)
            statsRow(label: "This week:", value: stats.formattedWeekTokens)
        }
    }

    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AnthropicColors.creamMuted)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(AnthropicColors.cream)
        }
    }
}
```

- [ ] **Step 4: Verify build**

```bash
xcodebuild build -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidget -destination 'platform=macOS' -quiet
```

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/App/Views/ResetTimerView.swift ClaudeUsageWidget/App/Views/UsageBarView.swift ClaudeUsageWidget/App/Views/TokenStatsView.swift
git commit -m "feat: add UsageBarView, ResetTimerView, TokenStatsView UI components"
```

---

## Task 12: PopoverView

**Files:**
- Create: `ClaudeUsageWidget/App/Views/PopoverView.swift`

- [ ] **Step 1: Implement PopoverView**

Create `ClaudeUsageWidget/App/Views/PopoverView.swift`:
```swift
import SwiftUI

struct PopoverView: View {
    @ObservedObject var manager: UsageManager
    let onRefresh: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if manager.isLoading && manager.snapshot == nil {
                loadingView
            } else if let snapshot = manager.snapshot {
                contentView(snapshot)
            } else {
                emptyView
            }
        }
        .frame(width: 260, height: 400)
        .background(AnthropicColors.charcoal.opacity(0.95))
        .task {
            if manager.snapshot == nil {
                await onRefresh()
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("Claude Code Usage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)
            Spacer()
            Button(action: { Task { await onRefresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(AnthropicColors.tan)
                    .rotationEffect(.degrees(manager.isLoading ? 360 : 0))
                    .animation(manager.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isLoading)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .background(AnthropicColors.tan.opacity(0.15))
            .cornerRadius(6)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .font(.system(size: 11))
                .foregroundStyle(AnthropicColors.creamMuted)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            Text("Click refresh to load usage data")
                .font(.system(size: 11))
                .foregroundStyle(AnthropicColors.creamMuted)
            Spacer()
        }
    }

    private func contentView(_ snapshot: UsageSnapshot) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                UsageBarView(label: "5-Hour Window", metric: snapshot.fiveHour)
                UsageBarView(label: "Weekly (All Models)", metric: snapshot.sevenDay)
                UsageBarView(label: "Weekly (Sonnet)", metric: snapshot.sevenDaySonnet)
                UsageBarView(label: "Weekly (Opus)", metric: snapshot.sevenDayOpus, isOpus: true)

                divider

                TokenStatsView(stats: snapshot.tokenStats)

                if let error = snapshot.error {
                    errorBanner(error)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, AnthropicColors.tan.opacity(0.3), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(AnthropicColors.coral)
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(AnthropicColors.coral)
                .lineLimit(2)
        }
        .padding(8)
        .background(AnthropicColors.coral.opacity(0.1))
        .cornerRadius(6)
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidget -destination 'platform=macOS' -quiet
```

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsageWidget/App/Views/PopoverView.swift
git commit -m "feat: add PopoverView with full usage dashboard layout"
```

---

## Task 14: SettingsView

**Files:**
- Create: `ClaudeUsageWidget/App/Views/SettingsView.swift`

- [ ] **Step 1: Implement SettingsView**

Create `ClaudeUsageWidget/App/Views/SettingsView.swift`:
```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Int = 300
    @State private var launchAtLogin: Bool = false

    var onIntervalChanged: ((Int) -> Void)?

    private let intervalOptions: [(String, Int)] = [
        ("1 min", 60),
        ("2 min", 120),
        ("5 min", 300),
        ("10 min", 600),
        ("15 min", 900),
    ]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Refresh interval:")
                    .font(.system(size: 11))
                    .foregroundStyle(AnthropicColors.creamMuted)
                Spacer()
                Picker("", selection: $refreshInterval) {
                    ForEach(intervalOptions, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 80)
                .onChange(of: refreshInterval) { _, newValue in
                    onIntervalChanged?(newValue)
                }
            }

            HStack {
                Text("Launch at login:")
                    .font(.system(size: 11))
                    .foregroundStyle(AnthropicColors.creamMuted)
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
```

- [ ] **Step 2: Verify build**

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsageWidget/App/Views/SettingsView.swift
git commit -m "feat: add SettingsView with refresh interval picker and launch-at-login toggle"
```

---

## Task 15: Main App Entry Point

**Files:**
- Modify: `ClaudeUsageWidget/App/ClaudeUsageWidgetApp.swift`

- [ ] **Step 1: Update the app entry point with MenuBarExtra**

Replace `ClaudeUsageWidget/App/ClaudeUsageWidgetApp.swift`:
```swift
import SwiftUI

@main
struct ClaudeUsageWidgetApp: App {
    @StateObject private var manager = UsageManager()
    @AppStorage("refreshInterval") private var refreshInterval: Int = 300

    var body: some Scene {
        MenuBarExtra("Claude Usage", systemImage: "gauge.medium") {
            MenuBarContentView(
                manager: manager,
                refreshInterval: $refreshInterval
            )
        }
        .menuBarExtraStyle(.window)
    }
}

/// Wrapper view needed because Scene modifiers like .onAppear, .onChange, .onOpenURL
/// are View-level modifiers — they must live inside the MenuBarExtra content, not on the Scene.
struct MenuBarContentView: View {
    @ObservedObject var manager: UsageManager
    @Binding var refreshInterval: Int

    var body: some View {
        VStack(spacing: 0) {
            PopoverView(manager: manager, onRefresh: { await manager.refresh() })

            Divider()
                .background(AnthropicColors.tan.opacity(0.2))

            SettingsView(onIntervalChanged: { interval in
                manager.startTimer(interval: TimeInterval(interval))
            })
        }
        .frame(width: 260)
        .background(AnthropicColors.charcoal.opacity(0.95))
        .task {
            manager.startTimer(interval: TimeInterval(refreshInterval))
            await manager.refresh()
        }
        .onOpenURL { url in
            // Handle claudeusage://open — app is already activated by macOS
            if url.scheme == "claudeusage" {
                Task { await manager.refresh() }
            }
        }
    }
}
```

Note: `.task`, `.onOpenURL` are View modifiers — they must be inside the `MenuBarExtra` content view, not chained on the `MenuBarExtra` Scene. The `MenuBarContentView` wrapper provides the correct scope for these modifiers.

Note: The Widget target has its own `@main` in `ClaudeUsageWidgetBundle.swift` — this is fine because each target has exactly one `@main`.

- [ ] **Step 2: Build and verify**

```bash
cd /Users/andywendt/Desktop/code/claude-usage-widget/ClaudeUsageWidget
xcodegen
xcodebuild build -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidget -destination 'platform=macOS' -quiet
```

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsageWidget/App/ClaudeUsageWidgetApp.swift
git commit -m "feat: wire up MenuBarExtra with popover, settings, and auto-refresh timer"
```

---

## Task 16: WidgetKit Timeline Provider (TDD)

**Files:**
- Modify: `ClaudeUsageWidget/Widget/ClaudeUsageWidgetBundle.swift`
- Create: `ClaudeUsageWidget/Widget/UsageTimelineProvider.swift`
- Create: `ClaudeUsageWidget/Tests/TimelineProviderTests.swift`

- [ ] **Step 1: Write failing tests for timeline construction**

Create `ClaudeUsageWidget/Tests/TimelineProviderTests.swift`:
```swift
import XCTest
@testable import ClaudeUsageWidget

final class TimelineProviderTests: XCTestCase {

    func testBuildTimelineFromSnapshot() {
        let snapshot = UsageSnapshot(
            fiveHour: UsageMetric(percent: 45.0, resetsAt: Date().addingTimeInterval(3600)),
            sevenDay: UsageMetric(percent: 30.0, resetsAt: Date().addingTimeInterval(86400)),
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 5000, weekTokens: 25000, todayMessages: 10, weekMessages: 50),
            lastUpdated: Date(),
            error: nil
        )

        let entries = UsageTimelineEntry.buildTimeline(from: snapshot)

        // Should have entries spaced 15 minutes apart
        XCTAssertGreaterThanOrEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.snapshot.fiveHour?.percent, 45.0)

        // Verify 15-minute spacing
        if entries.count >= 2 {
            let interval = entries[1].date.timeIntervalSince(entries[0].date)
            XCTAssertEqual(interval, 15 * 60, accuracy: 1)
        }
    }

    func testBuildTimelineWithNoSnapshot() {
        let entries = UsageTimelineEntry.buildTimeline(from: nil)

        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries.first?.snapshot.fiveHour)
    }

    func testEntryIsStale() {
        let staleSnapshot = UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date().addingTimeInterval(-31 * 60),
            error: nil
        )
        let entry = UsageTimelineEntry(date: Date(), snapshot: staleSnapshot)
        XCTAssertTrue(entry.snapshot.isStale)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `UsageTimelineEntry` not defined.

- [ ] **Step 3: Implement timeline provider**

Create `ClaudeUsageWidget/Widget/UsageTimelineProvider.swift`:
```swift
import Foundation
import WidgetKit

struct UsageTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot

    static func buildTimeline(from snapshot: UsageSnapshot?) -> [UsageTimelineEntry] {
        let base = snapshot ?? UsageSnapshot(
            fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil, sevenDayOpus: nil,
            tokenStats: TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0),
            lastUpdated: Date(),
            error: nil
        )

        guard snapshot != nil else {
            return [UsageTimelineEntry(date: Date(), snapshot: base)]
        }

        // Generate entries every 15 minutes for the next hour
        var entries: [UsageTimelineEntry] = []
        let now = Date()
        for i in 0..<4 {
            let entryDate = now.addingTimeInterval(TimeInterval(i * 15 * 60))
            entries.append(UsageTimelineEntry(date: entryDate, snapshot: base))
        }
        return entries
    }
}

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageTimelineEntry {
        UsageTimelineEntry(date: Date(), snapshot: UsageSnapshot(
            fiveHour: UsageMetric(percent: 45.0, resetsAt: Date().addingTimeInterval(3600)),
            sevenDay: UsageMetric(percent: 30.0, resetsAt: Date().addingTimeInterval(86400)),
            sevenDaySonnet: UsageMetric(percent: 22.0, resetsAt: Date().addingTimeInterval(86400)),
            sevenDayOpus: UsageMetric(percent: 15.0, resetsAt: Date().addingTimeInterval(86400)),
            tokenStats: TokenStats(todayTokens: 12000, weekTokens: 85000, todayMessages: 25, weekMessages: 150),
            lastUpdated: Date(),
            error: nil
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageTimelineEntry) -> Void) {
        let container = SharedContainerService()
        let snapshot = container.readSnapshot()
        let entry = UsageTimelineEntry(
            date: Date(),
            snapshot: snapshot ?? placeholder(in: context).snapshot
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageTimelineEntry>) -> Void) {
        let container = SharedContainerService()
        let snapshot = container.readSnapshot()
        let entries = UsageTimelineEntry.buildTimeline(from: snapshot)
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageWidget/Widget/UsageTimelineProvider.swift ClaudeUsageWidget/Tests/TimelineProviderTests.swift
git commit -m "feat: add UsageTimelineProvider with 15-min timeline entries and tests"
```

---

## Task 17: Widget Views

**Files:**
- Create: `ClaudeUsageWidget/Widget/Views/SmallWidgetView.swift`
- Create: `ClaudeUsageWidget/Widget/Views/MediumWidgetView.swift`
- Create: `ClaudeUsageWidget/Widget/Views/LargeWidgetView.swift`
- Create: `ClaudeUsageWidget/Widget/Views/PlaceholderView.swift`
- Create: `ClaudeUsageWidget/Widget/Views/ErrorView.swift`
- Modify: `ClaudeUsageWidget/Widget/ClaudeUsageWidgetBundle.swift`

- [ ] **Step 1: Create widget-compatible UsageBarWidget (shared bar for widgets)**

Create `ClaudeUsageWidget/Widget/Views/WidgetUsageBar.swift`:
```swift
import SwiftUI

struct WidgetUsageBar: View {
    let label: String
    let percent: Double
    let resetsAt: Date
    var isOpus: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(min(max(percent, 0), 100)))%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gradient)
                        .frame(width: geo.size.width * min(max(percent, 0), 100) / 100)
                }
            }
            .frame(height: 6)

            Text(resetsAt, style: .relative)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private var gradient: LinearGradient {
        if percent >= 90 {
            return AnthropicColors.dangerGradient
        } else if percent >= 70 {
            return AnthropicColors.warningGradient
        } else if isOpus {
            return AnthropicColors.opusGradient
        } else {
            return AnthropicColors.normalGradient
        }
    }
}
```

- [ ] **Step 2: Create SmallWidgetView**

Create `ClaudeUsageWidget/Widget/Views/SmallWidgetView.swift`:
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

            if snapshot.isStale {
                staleIndicator
            }
        }
        .padding(12)
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

- [ ] **Step 3: Create MediumWidgetView**

Create `ClaudeUsageWidget/Widget/Views/MediumWidgetView.swift`:
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

                if snapshot.isStale {
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
}
```

- [ ] **Step 4: Create LargeWidgetView**

Create `ClaudeUsageWidget/Widget/Views/LargeWidgetView.swift`:
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

            if snapshot.isStale {
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
}
```

- [ ] **Step 5: Create PlaceholderView and ErrorView**

Create `ClaudeUsageWidget/Widget/Views/PlaceholderView.swift`:
```swift
import SwiftUI

struct WidgetPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Claude Usage")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(height: 8)
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(height: 8)
        }
        .padding(12)
        .redacted(reason: .placeholder)
    }
}
```

Create `ClaudeUsageWidget/Widget/Views/ErrorView.swift`:
```swift
import SwiftUI

struct WidgetErrorView: View {
    let message: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: message != nil ? "exclamationmark.triangle" : "gauge.medium")
                .font(.system(size: 20))
                .foregroundStyle(message != nil ? AnthropicColors.coral : AnthropicColors.tan)
            Text(message ?? "Open Claude Usage Widget to get started")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }
}
```

Note: Uses warning icon (triangle) for error states, gauge icon for no-data states per spec.

- [ ] **Step 6: Update widget bundle**

Replace `ClaudeUsageWidget/Widget/ClaudeUsageWidgetBundle.swift`:
```swift
import SwiftUI
import WidgetKit

@main
struct ClaudeUsageWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        UsageWidget()
    }
}

struct UsageWidget: Widget {
    let kind = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            Group {
                if entry.snapshot.error != nil && entry.snapshot.fiveHour == nil {
                    WidgetErrorView(message: entry.snapshot.error)
                } else {
                    WidgetContentView(entry: entry)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "claudeusage://open"))
        }
        .configurationDisplayName("Claude Usage")
        .description("Monitor your Claude Code usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetContentView: View {
    @Environment(\.widgetFamily) var family
    let entry: UsageTimelineEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(snapshot: entry.snapshot)
        case .systemMedium:
            MediumWidgetView(snapshot: entry.snapshot)
        case .systemLarge:
            LargeWidgetView(snapshot: entry.snapshot)
        default:
            SmallWidgetView(snapshot: entry.snapshot)
        }
    }
}
```

- [ ] **Step 7: Regenerate project and build**

```bash
cd /Users/andywendt/Desktop/code/claude-usage-widget/ClaudeUsageWidget
xcodegen
xcodebuild build -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidget -destination 'platform=macOS' -quiet
```

- [ ] **Step 8: Commit**

```bash
git add ClaudeUsageWidget/Widget/
git commit -m "feat: add WidgetKit views (small/medium/large) with placeholder and error states"
```

---

## Task 18: Run All Tests and Fix Issues

- [ ] **Step 1: Regenerate project**

```bash
cd /Users/andywendt/Desktop/code/claude-usage-widget/ClaudeUsageWidget
xcodegen
```

- [ ] **Step 2: Run full test suite**

```bash
xcodebuild test -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidgetTests -destination 'platform=macOS' 2>&1 | grep -E "(Test Case|Test Suite|error:|FAIL|PASS)"
```

- [ ] **Step 3: Fix any failing tests**

Address compilation errors or test failures. Common issues:
- Import paths may need adjustment
- `@testable import ClaudeUsageWidget` must match the main app target name
- Models used in widget target need to be in the Shared/ folder (included in both targets)

- [ ] **Step 4: Verify clean build of both targets**

```bash
xcodebuild build -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidget -destination 'platform=macOS' -quiet
xcodebuild build -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidgetExtension -destination 'platform=macOS' -quiet
```

- [ ] **Step 5: Commit fixes if any**

```bash
git add -A ClaudeUsageWidget/
git commit -m "fix: resolve build and test issues across all targets"
```

---

## Task 19: Delete Placeholder Test

- [ ] **Step 1: Remove the placeholder test from Task 1**

Delete `ClaudeUsageWidget/Tests/PlaceholderTest.swift`.

- [ ] **Step 2: Run tests to verify nothing broke**

```bash
xcodebuild test -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidgetTests -destination 'platform=macOS' -quiet
```

- [ ] **Step 3: Commit**

```bash
git rm ClaudeUsageWidget/Tests/PlaceholderTest.swift
git commit -m "chore: remove placeholder test"
```
