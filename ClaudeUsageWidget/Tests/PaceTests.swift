import XCTest
@testable import ClaudeUsageWidget

final class PaceStatusTests: XCTestCase {
    func testPaceStatusEquatable() {
        XCTAssertEqual(PaceStatus.under, PaceStatus.under)
        XCTAssertEqual(PaceStatus.on, PaceStatus.on)
        XCTAssertEqual(PaceStatus.over, PaceStatus.over)
        XCTAssertNotEqual(PaceStatus.under, PaceStatus.on)
        XCTAssertNotEqual(PaceStatus.on, PaceStatus.over)
        XCTAssertNotEqual(PaceStatus.under, PaceStatus.over)
    }

    func testPaceInfoProperties() {
        let info = PaceInfo(projectedPercent: 75.0, status: .on)
        XCTAssertEqual(info.projectedPercent, 75.0)
        XCTAssertEqual(info.status, .on)
    }

    func testClampedProjectedPercentNormal() {
        let info = PaceInfo(projectedPercent: 75.0, status: .on)
        XCTAssertEqual(info.clampedProjectedPercent, 75.0)
    }

    func testClampedProjectedPercentAbove100() {
        let info = PaceInfo(projectedPercent: 160.0, status: .over)
        XCTAssertEqual(info.clampedProjectedPercent, 100.0)
    }

    func testClampedProjectedPercentBelowZero() {
        let info = PaceInfo(projectedPercent: -10.0, status: .under)
        XCTAssertEqual(info.clampedProjectedPercent, 0.0)
    }
}

final class PaceComputeTests: XCTestCase {
    private let windowDuration: TimeInterval = 5 * 3600 // 5 hours
    private let resetsAt = Date(timeIntervalSince1970: 1711018800) // fixed reference

    // MARK: - Projection & Status

    func testComputePaceAt50PercentElapsed() {
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.5)
        let metric = UsageMetric(percent: 30.0, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNotNil(pace)
        // projected = 30 / 0.5 = 60%, expected = 50%. 60 > 55 → over
        XCTAssertEqual(pace!.projectedPercent, 60.0, accuracy: 0.1)
        XCTAssertEqual(pace!.status, .over)
    }

    func testComputePaceAt25PercentElapsed() {
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.75)
        let metric = UsageMetric(percent: 40.0, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNotNil(pace)
        // projected = 40 / 0.25 = 160%, expected = 25%. 160 > 30 → over
        XCTAssertEqual(pace!.projectedPercent, 160.0, accuracy: 0.1)
        XCTAssertEqual(pace!.status, .over)
    }

    func testComputePaceAt75PercentElapsed() {
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.25)
        let metric = UsageMetric(percent: 70.0, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNotNil(pace)
        // projected = 70 / 0.75 ≈ 93.3%, expected = 75%. 93.3 > 80 → over
        XCTAssertEqual(pace!.projectedPercent, 93.33, accuracy: 0.1)
        XCTAssertEqual(pace!.status, .over)
    }

    func testComputePaceReturnsNilWhenTooEarly() {
        // 2% elapsed → below 5% threshold → nil
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.98)
        let metric = UsageMetric(percent: 1.0, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNil(pace)
    }

    func testComputePaceReturnsNilWhenExpired() {
        // resetsAt in the past means fractionElapsed >= 1.0
        let pastResetsAt = Date(timeIntervalSince1970: 1711018800)
        let now = pastResetsAt.addingTimeInterval(100)
        let metric = UsageMetric(percent: 50.0, resetsAt: pastResetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNil(pace)
    }

    func testComputePaceReturnsNilWhenNotStarted() {
        // resetsAt far in future → fractionElapsed negative → nil
        let farFutureResetsAt = Date(timeIntervalSince1970: 1711018800 + 100_000)
        let now = Date(timeIntervalSince1970: 1711018800)
        let metric = UsageMetric(percent: 10.0, resetsAt: farFutureResetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNil(pace)
    }

    func testComputePaceZeroUsage() {
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.5)
        let metric = UsageMetric(percent: 0.0, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNotNil(pace)
        // projected = 0 / 0.5 = 0%, expected = 50%. 0 < 45 → under
        XCTAssertEqual(pace!.projectedPercent, 0.0, accuracy: 0.1)
        XCTAssertEqual(pace!.status, .under)
    }

    // MARK: - Dead Zone Boundaries

    func testComputePaceDeadZoneUnder() {
        // At 50% elapsed, expected = 50. projected = 20/0.5 = 40. 40 < 45 → under
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.5)
        let metric = UsageMetric(percent: 20.0, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNotNil(pace)
        XCTAssertEqual(pace!.status, .under)
    }

    func testComputePaceDeadZoneOver() {
        // At 50% elapsed, expected = 50. projected = 30/0.5 = 60. 60 > 55 → over
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.5)
        let metric = UsageMetric(percent: 30.0, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNotNil(pace)
        XCTAssertEqual(pace!.status, .over)
    }

    func testComputePaceDeadZoneOn() {
        // At 50% elapsed, expected = 50. projected = 25/0.5 = 50. |50-50| = 0 ≤ 5 → on
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.5)
        let metric = UsageMetric(percent: 25.0, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNotNil(pace)
        XCTAssertEqual(pace!.status, .on)
    }

    // MARK: - Different Window Duration

    func testComputePaceSevenDayWindow() {
        let sevenDays: TimeInterval = 7 * 24 * 3600
        let sevenDayResetsAt = Date(timeIntervalSince1970: 1711018800 + sevenDays)
        let now = sevenDayResetsAt.addingTimeInterval(-sevenDays * 0.5)
        let metric = UsageMetric(percent: 25.0, resetsAt: sevenDayResetsAt)

        let pace = computePace(metric: metric, windowDuration: sevenDays, now: now)

        XCTAssertNotNil(pace)
        // projected = 25 / 0.5 = 50, expected = 50. On pace.
        XCTAssertEqual(pace!.projectedPercent, 50.0, accuracy: 0.1)
        XCTAssertEqual(pace!.status, .on)
    }

    // MARK: - PaceSettings

    func testPaceSettingsEncodeDecode() throws {
        let settings = PaceSettings(enabledMetrics: [.fiveHour, .sevenDay])
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(PaceSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testPaceSettingsAllEnabledContainsAllKeys() {
        let all = PaceSettings.allEnabled
        XCTAssertEqual(all.enabledMetrics.count, 4)
        XCTAssertTrue(all.enabledMetrics.contains(.fiveHour))
        XCTAssertTrue(all.enabledMetrics.contains(.sevenDay))
        XCTAssertTrue(all.enabledMetrics.contains(.sevenDaySonnet))
        XCTAssertTrue(all.enabledMetrics.contains(.sevenDayOpus))
    }

    // MARK: - MetricKey Window Duration

    func testMetricKeyWindowDurationFiveHour() {
        XCTAssertEqual(MetricKey.fiveHour.windowDuration, 5 * 3600)
    }

    func testMetricKeyWindowDurationSevenDay() {
        let expected = 7 * 24 * 3600.0
        XCTAssertEqual(MetricKey.sevenDay.windowDuration, expected)
        XCTAssertEqual(MetricKey.sevenDaySonnet.windowDuration, expected)
        XCTAssertEqual(MetricKey.sevenDayOpus.windowDuration, expected)
    }

    // MARK: - Exact Boundary Tests

    func testComputePaceAtExactly5PercentElapsed() {
        // fractionElapsed = exactly 0.05 → should return non-nil
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.95)
        let metric = UsageMetric(percent: 5.0, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNotNil(pace)
    }

    func testComputePaceAtExactlyFractionElapsed1() {
        // fractionElapsed = exactly 1.0 (now == resetsAt) → should return nil
        let now = resetsAt
        let metric = UsageMetric(percent: 50.0, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNil(pace)
    }

    func testComputePaceDeadZoneExactBoundaryUnder() {
        // At 50% elapsed, expected = 50. We want projected = expected - 5 = 45 exactly.
        // projected = percent / fractionElapsed → percent = 45 * 0.5 = 22.5
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.5)
        let metric = UsageMetric(percent: 22.5, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNotNil(pace)
        // projected = 22.5 / 0.5 = 45, expected = 50. 45 is NOT < 45, so .on
        XCTAssertEqual(pace!.status, .on)
    }

    func testComputePaceDeadZoneExactBoundaryOver() {
        // At 50% elapsed, expected = 50. We want projected = expected + 5 = 55 exactly.
        // projected = percent / fractionElapsed → percent = 55 * 0.5 = 27.5
        let now = resetsAt.addingTimeInterval(-windowDuration * 0.5)
        let metric = UsageMetric(percent: 27.5, resetsAt: resetsAt)

        let pace = computePace(metric: metric, windowDuration: windowDuration, now: now)

        XCTAssertNotNil(pace)
        // projected = 27.5 / 0.5 = 55, expected = 50. 55 is NOT > 55, so .on
        XCTAssertEqual(pace!.status, .on)
    }

    func testComputePaceWindowDurationZeroReturnsNil() {
        let metric = UsageMetric(percent: 50.0, resetsAt: resetsAt)
        let pace = computePace(metric: metric, windowDuration: 0, now: resetsAt.addingTimeInterval(-100))
        XCTAssertNil(pace)
    }

    func testComputePaceWindowDurationNegativeReturnsNil() {
        let metric = UsageMetric(percent: 50.0, resetsAt: resetsAt)
        let pace = computePace(metric: metric, windowDuration: -1, now: resetsAt.addingTimeInterval(-100))
        XCTAssertNil(pace)
    }
}
