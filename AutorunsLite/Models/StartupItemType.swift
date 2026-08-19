import Foundation

enum StartupItemType: String, Hashable, CaseIterable, Sendable {
    case userLaunchAgent
    case systemLaunchAgent
    case launchDaemon
    case loginItem
    case backgroundTask
    case smAppService

    var displayName: String {
        switch self {
        case .userLaunchAgent:
            return L10n.text("type.user_agent")
        case .systemLaunchAgent:
            return L10n.text("type.system_agent")
        case .launchDaemon:
            return L10n.text("type.daemon")
        case .loginItem:
            return L10n.text("type.login_item")
        case .backgroundTask:
            return L10n.text("type.background_task")
        case .smAppService:
            return L10n.text("type.smappservice")
        }
    }

    var sourceDescription: String {
        switch self {
        case .userLaunchAgent:
            return L10n.text("type.source_user_launch_agent")
        case .systemLaunchAgent:
            return L10n.text("type.source_system_launch_agent")
        case .launchDaemon:
            return L10n.text("type.source_launch_daemon")
        case .loginItem:
            return L10n.text("type.source_login_item")
        case .backgroundTask:
            return L10n.text("type.source_background_task")
        case .smAppService:
            return L10n.text("type.source_smappservice")
        }
    }

    var supportsLaunchctl: Bool {
        switch self {
        case .userLaunchAgent, .systemLaunchAgent, .launchDaemon:
            return true
        case .loginItem, .backgroundTask, .smAppService:
            return false
        }
    }

    var isModernSource: Bool {
        !supportsLaunchctl
    }

    var launchctlDomain: String? {
        switch self {
        case .userLaunchAgent, .systemLaunchAgent:
            return "gui/\(getuid())"
        case .launchDaemon:
            return "system"
        case .loginItem, .backgroundTask, .smAppService:
            return nil
        }
    }

    var researchTypeKeyword: String {
        switch self {
        case .userLaunchAgent, .systemLaunchAgent:
            return "LaunchAgent"
        case .launchDaemon:
            return "LaunchDaemon"
        case .loginItem:
            return "login item"
        case .backgroundTask:
            return "background task"
        case .smAppService:
            return "SMAppService"
        }
    }

    var isSystemLaunchd: Bool {
        self == .systemLaunchAgent || self == .launchDaemon
    }
}
