import CoreGraphics

enum MenuBarPanel: Equatable {
    case usage
    case settings
    case debugger
}

struct MenuBarNavigation {
    private(set) var panel: MenuBarPanel = .usage

    mutating func openSettings() {
        panel = .settings
    }

    mutating func openDebugger() {
        panel = .debugger
    }

    mutating func goBack() {
        switch panel {
        case .usage:
            break
        case .settings:
            panel = .usage
        case .debugger:
            panel = .settings
        }
    }
}

extension MenuBarPanel {
    var width: CGFloat {
        switch self {
        case .usage, .settings:
            260
        case .debugger:
            500
        }
    }

    var minimumHeight: CGFloat {
        switch self {
        case .usage, .settings:
            400
        case .debugger:
            600
        }
    }

    var fixedHeight: CGFloat? {
        switch self {
        case .usage:
            nil
        case .settings:
            400
        case .debugger:
            600
        }
    }
}
