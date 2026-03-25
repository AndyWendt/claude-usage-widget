import XCTest
@testable import ClaudeUsageWidget

final class MenuBarNavigationTests: XCTestCase {
    func testStartsOnUsagePanel() {
        let navigation = MenuBarNavigation()

        XCTAssertEqual(navigation.panel, .usage)
    }

    func testOpenSettingsShowsSettingsPanel() {
        var navigation = MenuBarNavigation()

        navigation.openSettings()

        XCTAssertEqual(navigation.panel, .settings)
    }

    func testOpenDebuggerFromSettingsShowsDebuggerPanel() {
        var navigation = MenuBarNavigation()

        navigation.openSettings()
        navigation.openDebugger()

        XCTAssertEqual(navigation.panel, .debugger)
    }

    func testBackFromDebuggerReturnsToSettings() {
        var navigation = MenuBarNavigation()

        navigation.openSettings()
        navigation.openDebugger()
        navigation.goBack()

        XCTAssertEqual(navigation.panel, .settings)
    }

    func testBackFromSettingsReturnsToUsage() {
        var navigation = MenuBarNavigation()

        navigation.openSettings()
        navigation.goBack()

        XCTAssertEqual(navigation.panel, .usage)
    }

    func testBackFromUsageLeavesUsageSelected() {
        var navigation = MenuBarNavigation()

        navigation.goBack()

        XCTAssertEqual(navigation.panel, .usage)
    }

    func testOpenSettingsFromDebuggerReturnsToSettingsPanel() {
        var navigation = MenuBarNavigation()

        navigation.openDebugger()
        navigation.openSettings()

        XCTAssertEqual(navigation.panel, .settings)
    }

    func testUsagePanelSizeMatchesCompactPopover() {
        XCTAssertEqual(MenuBarPanel.usage.size.width, 260)
        XCTAssertEqual(MenuBarPanel.usage.size.height, 400)
    }

    func testSettingsPanelSizeMatchesCompactPopover() {
        XCTAssertEqual(MenuBarPanel.settings.size.width, 260)
        XCTAssertEqual(MenuBarPanel.settings.size.height, 400)
    }

    func testDebuggerPanelSizeMatchesExpandedPopover() {
        XCTAssertEqual(MenuBarPanel.debugger.size.width, 500)
        XCTAssertEqual(MenuBarPanel.debugger.size.height, 600)
    }
}
