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
    var size: CGSize {
        switch self {
        case .usage, .settings:
            CGSize(width: 260, height: 400)
        case .debugger:
            CGSize(width: 500, height: 600)
        }
    }
}
