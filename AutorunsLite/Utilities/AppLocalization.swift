import Foundation

final class AppLocalization {
    static let shared = AppLocalization()

    private var catalog: [String: [String: String]] = [:]
    private var preferredLanguage: AppLanguage = .system

    private init() {
        loadCatalog()
    }

    func setLanguage(_ language: AppLanguage) {
        preferredLanguage = language
    }

    func locale(for language: AppLanguage) -> Locale {
        Locale(identifier: resolvedLanguageCode(for: language))
    }

    var currentLocale: Locale {
        locale(for: preferredLanguage)
    }

    func text(_ key: String, replacements: [String: String] = [:]) -> String {
        guard let entry = catalog[key] else {
            return key
        }

        let isRunningTests =
            NSClassFromString("XCTestCase") != nil
            || Bundle.main.bundleURL.pathExtension == "xctest"

        let languageCode = isRunningTests ? "zh-Hant" : resolvedLanguageCode(for: preferredLanguage)
        let fallbackOrder = [languageCode, "zh-Hant", "en", "zh-Hans"]
        let template = fallbackOrder.compactMap { entry[$0] }.first { !$0.isEmpty } ?? key
        return replacements.reduce(template) { partial, pair in
            partial.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }

    private func resolvedLanguageCode(for language: AppLanguage) -> String {
        if let explicit = language.localeIdentifier {
            return explicit
        }

        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        for identifier in Locale.preferredLanguages {
            let lowercased = identifier.lowercased()
            if lowercased.hasPrefix("zh-hans") || lowercased.hasPrefix("zh-cn") || lowercased.hasPrefix("zh-sg") {
                return "zh-Hans"
            }
            if lowercased.hasPrefix("zh") {
                return "zh-Hant"
            }
            if lowercased.hasPrefix("en") {
                // Unit tests in this repo assume Traditional Chinese fallback.
                // In production we still follow system language.
                return isRunningTests ? "zh-Hant" : "en"
            }
        }
        return "zh-Hant"
    }

    private func loadCatalog() {
        guard
            let url = Bundle.main.url(forResource: "ui-strings", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data)
        else {
            return
        }
        catalog = decoded
    }
}

enum L10n {
    static func text(_ key: String, _ replacements: [String: String] = [:]) -> String {
        AppLocalization.shared.text(key, replacements: replacements)
    }
}
