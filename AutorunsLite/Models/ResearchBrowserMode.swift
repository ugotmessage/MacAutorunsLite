import Foundation

enum ResearchBrowserMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case embedded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .embedded:
            return L10n.text("settings.browser_mode.embedded")
        case .system:
            return L10n.text("settings.browser_mode.system")
        }
    }
}

enum ServiceResearchQueryType: String, CaseIterable, Identifiable, Sendable {
    case overview
    case disableSafety
    case removalSafety
    case community

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview:
            return L10n.text("research.query.overview")
        case .disableSafety:
            return L10n.text("research.query.disable_safety")
        case .removalSafety:
            return L10n.text("research.query.removal_safety")
        case .community:
            return L10n.text("research.query.community")
        }
    }
}

enum ResearchSearchDefaults {
    static let template = "\"{label}\" {type} {keyword}"
    static let overviewKeyword = "macOS"
    static let disableKeyword = "safe to disable"
    static let removeKeyword = "safe to remove"
    static let communityKeyword = "reddit"
    static let previewLabel = "com.example.service"
    static let previewType = "LaunchDaemon"
}
