import Foundation

enum ItemOrigin: String, Hashable, Sendable {
    case appleSystem
    case thirdParty
    case unknown

    var displayName: String {
        switch self {
        case .appleSystem:
            return L10n.text("origin.apple_system")
        case .thirdParty:
            return L10n.text("origin.third_party")
        case .unknown:
            return L10n.text("origin.unknown")
        }
    }

    static func classify(label: String, plistPath: String, executablePath: String?) -> ItemOrigin {
        if label.lowercased().hasPrefix("com.apple.") {
            return .appleSystem
        }

        let candidates = [plistPath, executablePath].compactMap { $0 }
        for path in candidates {
            if path.hasPrefix("/System/") || path.hasPrefix("/Library/Apple/") {
                return .appleSystem
            }
        }

        if plistPath.hasPrefix("/Users/") || plistPath.contains("/Applications/") {
            return .thirdParty
        }
        if let executablePath, executablePath.contains("/Applications/") {
            return .thirdParty
        }
        if plistPath.hasPrefix("/Library/") {
            return .thirdParty
        }

        return .unknown
    }
}
