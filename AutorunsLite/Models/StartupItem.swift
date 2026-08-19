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

    let parentBundleIdentifier: String?
    let parentDisplayName: String?
    let associatedBundleIDs: [String]
    let teamIdentifier: String?
    let developerName: String?
    let btmUUID: String?
    let sourceURL: String
    let relatedHelpers: [RelatedHelper]

    init(
        id: String,
        label: String,
        plistPath: String,
        executablePath: String?,
        arguments: [String],
        type: StartupItemType,
        runAtLoad: Bool,
        keepAliveDescription: String?,
        executableExists: Bool,
        loadStatus: LoadStatus,
        workingDirectory: String?,
        environmentVariables: [String: String],
        standardOutPath: String?,
        standardErrorPath: String?,
        appDisplayName: String?,
        appBundleName: String?,
        appBundleIdentifier: String?,
        appBundlePath: String?,
        origin: ItemOrigin,
        launchdLoaded: Bool,
        persistentlyDisabled: Bool,
        parentBundleIdentifier: String? = nil,
        parentDisplayName: String? = nil,
        associatedBundleIDs: [String] = [],
        teamIdentifier: String? = nil,
        developerName: String? = nil,
        btmUUID: String? = nil,
        sourceURL: String = "",
        relatedHelpers: [RelatedHelper] = []
    ) {
        self.id = id
        self.label = label
        self.plistPath = plistPath
        self.executablePath = executablePath
        self.arguments = arguments
        self.type = type
        self.runAtLoad = runAtLoad
        self.keepAliveDescription = keepAliveDescription
        self.executableExists = executableExists
        self.loadStatus = loadStatus
        self.workingDirectory = workingDirectory
        self.environmentVariables = environmentVariables
        self.standardOutPath = standardOutPath
        self.standardErrorPath = standardErrorPath
        self.appDisplayName = appDisplayName
        self.appBundleName = appBundleName
        self.appBundleIdentifier = appBundleIdentifier
        self.appBundlePath = appBundlePath
        self.origin = origin
        self.launchdLoaded = launchdLoaded
        self.persistentlyDisabled = persistentlyDisabled
        self.parentBundleIdentifier = parentBundleIdentifier
        self.parentDisplayName = parentDisplayName
        self.associatedBundleIDs = associatedBundleIDs
        self.teamIdentifier = teamIdentifier
        self.developerName = developerName
        self.btmUUID = btmUUID
        self.sourceURL = sourceURL
        self.relatedHelpers = relatedHelpers
    }

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

    var resolvedSourcePath: String {
        if !sourceURL.isEmpty {
            return sourceURL
        }
        return plistPath
    }

    var abbreviatedPlistPath: String {
        abbreviatedPath(resolvedSourcePath)
    }

    var abbreviatedSourcePath: String {
        abbreviatedPlistPath
    }

    var isSystemProtected: Bool {
        label.lowercased().hasPrefix("com.apple.") || origin == .appleSystem
    }

    var relationKeys: Set<String> {
        var keys = Set<String>()
        if let appBundleIdentifier, !appBundleIdentifier.isEmpty {
            keys.insert(appBundleIdentifier)
        }
        if let parentBundleIdentifier, !parentBundleIdentifier.isEmpty {
            keys.insert(parentBundleIdentifier)
        }
        associatedBundleIDs.filter { !$0.isEmpty }.forEach { keys.insert($0) }
        return keys
    }

    var statusExplanation: String? {
        switch loadStatus {
        case .orphaned:
            if type.isModernSource {
                return L10n.text("status.orphaned.explanation_modern")
            }
            return L10n.text("status.orphaned.explanation_launchd")
        case .error(let message):
            return message
        default:
            return nil
        }
    }

    func enriching(
        btmUUID: String? = nil,
        teamIdentifier: String? = nil,
        developerName: String? = nil,
        parentBundleIdentifier: String? = nil,
        parentDisplayName: String? = nil,
        associatedBundleIDs: [String] = [],
        loadStatus: LoadStatus? = nil,
        relatedHelpers: [RelatedHelper]? = nil
    ) -> StartupItem {
        StartupItem(
            id: id,
            label: label,
            plistPath: plistPath,
            executablePath: executablePath,
            arguments: arguments,
            type: type,
            runAtLoad: runAtLoad,
            keepAliveDescription: keepAliveDescription,
            executableExists: executableExists,
            loadStatus: loadStatus ?? self.loadStatus,
            workingDirectory: workingDirectory,
            environmentVariables: environmentVariables,
            standardOutPath: standardOutPath,
            standardErrorPath: standardErrorPath,
            appDisplayName: appDisplayName,
            appBundleName: appBundleName,
            appBundleIdentifier: appBundleIdentifier,
            appBundlePath: appBundlePath,
            origin: origin,
            launchdLoaded: launchdLoaded,
            persistentlyDisabled: persistentlyDisabled,
            parentBundleIdentifier: parentBundleIdentifier ?? self.parentBundleIdentifier,
            parentDisplayName: parentDisplayName ?? self.parentDisplayName,
            associatedBundleIDs: associatedBundleIDs.isEmpty ? self.associatedBundleIDs : associatedBundleIDs,
            teamIdentifier: teamIdentifier ?? self.teamIdentifier,
            developerName: developerName ?? self.developerName,
            btmUUID: btmUUID ?? self.btmUUID,
            sourceURL: sourceURL,
            relatedHelpers: relatedHelpers ?? self.relatedHelpers
        )
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
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

enum AppRelationMatcher {
    static func related(to item: StartupItem, in items: [StartupItem]) -> [StartupItem] {
        let keys = item.relationKeys
        guard !keys.isEmpty else { return [] }
        return items.filter { other in
            other.id != item.id && !other.relationKeys.isDisjoint(with: keys)
        }
    }
}
