import Foundation

enum StartupFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case userLaunchAgents
    case systemLaunchAgents
    case launchDaemons
    case loaded
    case disabled
    case orphaned
    case safeAction
    case reviewRequired

    var id: String { rawValue }

    static var toolbarFilters: [StartupFilter] {
        [.all, .userLaunchAgents, .systemLaunchAgents, .launchDaemons, .loaded, .disabled, .orphaned]
    }

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
        case .safeAction:
            return "可安全處理"
        case .reviewRequired:
            return "建議檢查"
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
        case .safeAction:
            return RecommendationResolver().resolve(item).recommendation == .safeAction
        case .reviewRequired:
            return RecommendationResolver().resolve(item).recommendation == .reviewRequired
        }
    }
}
