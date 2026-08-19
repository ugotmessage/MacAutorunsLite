import Foundation

enum StartupItemType: String, Hashable, CaseIterable, Sendable {
    case userLaunchAgent
    case systemLaunchAgent
    case launchDaemon

    var displayName: String {
        switch self {
        case .userLaunchAgent:
            return "User Agent"
        case .systemLaunchAgent:
            return "System Agent"
        case .launchDaemon:
            return "Daemon"
        }
    }

    var sourceDescription: String {
        switch self {
        case .userLaunchAgent:
            return "User LaunchAgent"
        case .systemLaunchAgent:
            return "System LaunchAgent"
        case .launchDaemon:
            return "LaunchDaemon"
        }
    }

    var launchctlDomain: String {
        switch self {
        case .userLaunchAgent, .systemLaunchAgent:
            return "gui/\(getuid())"
        case .launchDaemon:
            return "system"
        }
    }
}
