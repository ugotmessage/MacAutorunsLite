import Foundation

enum StartupFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case userLaunchAgents
    case systemLaunchAgents
    case launchDaemons
    case loaded
    case disabled
    case orphaned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .userLaunchAgents:
            return "User Agents"
        case .systemLaunchAgents:
            return "System Agents"
        case .launchDaemons:
            return "Daemons"
        case .loaded:
            return "已載入"
        case .disabled:
            return "已停用"
        case .orphaned:
            return "殘留"
        }
    }

    func matches(_ item: StartupItem) -> Bool {
        switch self {
        case .all:
            return true
        case .userLaunchAgents:
            return item.type == .userLaunchAgent
        case .systemLaunchAgents:
            return item.type == .systemLaunchAgent
        case .launchDaemons:
            return item.type == .launchDaemon
        case .loaded:
            return item.loadStatus == .loaded
        case .disabled:
            return item.loadStatus == .disabled
        case .orphaned:
            return item.loadStatus.isOrphaned
        }
    }
}
