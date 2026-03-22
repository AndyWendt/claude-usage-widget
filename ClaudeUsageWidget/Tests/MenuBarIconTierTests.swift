import XCTest
@testable import ClaudeUsageWidget

final class MenuBarIconTierFromPercentTests: XCTestCase {

    func testZeroPercentIsLow() {
        XCTAssertEqual(MenuBarIconTier.from(percent: 0), .low)
    }

    func testThirtyNinePercentIsLow() {
        XCTAssertEqual(MenuBarIconTier.from(percent: 39), .low)
    }

    func testFortyPercentIsModerate() {
        XCTAssertEqual(MenuBarIconTier.from(percent: 40), .moderate)
    }

    func testSixtyNinePercentIsModerate() {
        XCTAssertEqual(MenuBarIconTier.from(percent: 69), .moderate)
    }

    func testSeventyPercentIsHigh() {
        XCTAssertEqual(MenuBarIconTier.from(percent: 70), .high)
    }

    func testEightyNinePercentIsHigh() {
        XCTAssertEqual(MenuBarIconTier.from(percent: 89), .high)
    }

    func testNinetyPercentIsCritical() {
        XCTAssertEqual(MenuBarIconTier.from(percent: 90), .critical)
    }

    func testOneHundredPercentIsCritical() {
        XCTAssertEqual(MenuBarIconTier.from(percent: 100), .critical)
    }
}

final class MenuBarIconTierPropertiesTests: XCTestCase {

    func testIdleSymbolName() {
        XCTAssertEqual(MenuBarIconTier.idle.symbolName, "gauge.medium")
    }

    func testLowSymbolName() {
        XCTAssertEqual(MenuBarIconTier.low.symbolName, "gauge.open.with.lines.needle.33percent")
    }

    func testModerateSymbolName() {
        XCTAssertEqual(MenuBarIconTier.moderate.symbolName, "gauge.open.with.lines.needle.50percent")
    }

    func testHighSymbolName() {
        XCTAssertEqual(MenuBarIconTier.high.symbolName, "gauge.open.with.lines.needle.67percent")
    }

    func testCriticalSymbolName() {
        XCTAssertEqual(MenuBarIconTier.critical.symbolName, "gauge.open.with.lines.needle.84percent")
    }

    func testAllTiersHaveNonEmptyAccessibilityLabel() {
        let tiers: [MenuBarIconTier] = [.idle, .low, .moderate, .high, .critical]
        for tier in tiers {
            XCTAssertFalse(tier.accessibilityLabel.isEmpty, "\(tier) should have a non-empty accessibility label")
        }
    }

    func testIdleAccessibilityLabel() {
        XCTAssertEqual(MenuBarIconTier.idle.accessibilityLabel, "Claude Usage")
    }

    func testCriticalAccessibilityLabel() {
        XCTAssertEqual(MenuBarIconTier.critical.accessibilityLabel, "Claude Usage: Critical")
    }
}
