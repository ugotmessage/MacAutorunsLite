import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case traditionalChinese
    case simplifiedChinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return L10n.text("settings.language.system")
        case .english:
            return L10n.text("settings.language.en")
        case .traditionalChinese:
            return L10n.text("settings.language.zh_hant")
        case .simplifiedChinese:
            return L10n.text("settings.language.zh_hans")
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .traditionalChinese:
            return "zh-Hant"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }
}
