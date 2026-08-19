import Foundation

enum StartupFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case userLaunchAgents
    case systemLaunchAgents
    case launchDaemons
    case loginItems
    case backgroundTasks
    case smAppServices
    case loaded
    case disabled
    case orphaned
    case safeAction
    case reviewRequired

    var id: String { rawValue }

    static var toolbarFilters: [StartupFilter] {
        [
            .all,
            .userLaunchAgents,
            .systemLaunchAgents,
            .launchDaemons,
            .loginItems,
            .backgroundTasks,
            .smAppServices,
            .loaded,
            .disabled,
            .orphaned
        ]
    }

    var title: String {
        switch self {
        case .all:
            return L10n.text("filter.all")
        case .userLaunchAgents:
            return L10n.text("filter.user_agents")
        case .systemLaunchAgents:
            return L10n.text("filter.system_agents")
        case .launchDaemons:
            return L10n.text("filter.daemons")
        case .loginItems:
            return L10n.text("filter.login_items")
        case .backgroundTasks:
            return L10n.text("filter.background_tasks")
        case .smAppServices:
            return L10n.text("filter.smappservice")
        case .loaded:
            return L10n.text("filter.loaded")
        case .disabled:
            return L10n.text("filter.disabled")
        case .orphaned:
            return L10n.text("filter.orphaned")
        case .safeAction:
            return L10n.text("filter.safe_action")
        case .reviewRequired:
            return L10n.text("filter.review_required")
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
        case .loginItems:
            return item.type == .loginItem
        case .backgroundTasks:
            return item.type == .backgroundTask
        case .smAppServices:
            return item.type == .smAppService
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
