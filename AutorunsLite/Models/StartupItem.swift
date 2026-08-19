import Foundation

struct StartupItem: Identifiable, Hashable, Sendable {
    let id: String

    let label: String
    let plistPath: String
    let executablePath: String?
    let arguments: [String]

    let type: StartupItemType

    let runAtLoad: Bool
    let keepAliveDescription: String?

    let executableExists: Bool

    var loadStatus: LoadStatus

    let workingDirectory: String?
    let environmentVariables: [String: String]
    let standardOutPath: String?
    let standardErrorPath: String?

    let appDisplayName: String?
    let appBundleName: String?
    let appBundleIdentifier: String?
    let appBundlePath: String?

    let origin: ItemOrigin

    let launchdLoaded: Bool
    let persistentlyDisabled: Bool

    var displayName: String {
        if let appDisplayName, !appDisplayName.isEmpty {
            return appDisplayName
        }
        if let appBundleName, !appBundleName.isEmpty {
            return appBundleName
        }
        return label
    }

    var secondaryIdentifier: String? {
        if let appBundleIdentifier, !appBundleIdentifier.isEmpty {
            return appBundleIdentifier
        }
        if displayName != label {
            return label
        }
        return nil
    }

    var abbreviatedPlistPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if plistPath.hasPrefix(home) {
            return "~" + plistPath.dropFirst(home.count)
        }
        return plistPath
    }

    var isSystemProtected: Bool {
        label.lowercased().hasPrefix("com.apple.") || origin == .appleSystem
    }

    var statusExplanation: String? {
        switch loadStatus {
        case .orphaned:
            return "此啟動項目的 plist 仍存在，但執行檔已不存在，可能是已移除 App 的殘留項目。"
        case .error(let message):
            return message
        default:
            return nil
        }
    }
}

extension Array where Element == StartupItem {
    func sortedForDisplay() -> [StartupItem] {
        sorted { lhs, rhs in
            if lhs.loadStatus.sortRank != rhs.loadStatus.sortRank {
                return lhs.loadStatus.sortRank < rhs.loadStatus.sortRank
            }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }
}
