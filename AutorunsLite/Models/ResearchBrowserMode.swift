import Foundation

enum ResearchBrowserMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case embedded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .embedded:
            return "內建瀏覽器"
        case .system:
            return "系統預設瀏覽器"
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
            return "這是什麼"
        case .disableSafety:
            return "能停用嗎"
        case .removalSafety:
            return "能刪除嗎"
        case .community:
            return "網友討論"
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
