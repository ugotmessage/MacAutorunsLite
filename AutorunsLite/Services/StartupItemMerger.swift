import Foundation

struct StartupItemMerger: Sendable {
    func merge(
        traditional: [StartupItem],
        modern: [StartupItem],
        btmRecords: [BTMRecord],
        helpersByParentPath: [String: [RelatedHelper]] = [:]
    ) -> [StartupItem] {
        var items = traditional
        var indexByPlist = Dictionary(uniqueKeysWithValues: traditional.enumerated().compactMap { offset, item -> (String, Int)? in
            guard !item.plistPath.isEmpty else { return nil }
            return (item.plistPath, offset)
        })
        var indexByLabel = Dictionary(uniqueKeysWithValues: traditional.enumerated().map { ($0.element.label, $0.offset) })

        func attachHelpers(_ item: StartupItem) -> StartupItem {
            let parentPath = item.appBundlePath
                ?? ParentAppResolver.parentApp(for: item.resolvedSourcePath).path
            guard let helpers = helpers(from: helpersByParentPath, parentPath: parentPath), !helpers.isEmpty else {
                return item
            }
            return item.enriching(relatedHelpers: helpers)
        }

        items = items.map(attachHelpers)

        for record in btmRecords {
            let path = record.filePath
            if record.isLegacyTraditional,
               let existingIndex = indexByPlist[path] ?? indexByLabel[record.identifier] ?? indexByLabel[record.name] {
                let existing = items[existingIndex]
                let status: LoadStatus? = existing.loadStatus.isOrphaned ? nil : record.loadStatus
                items[existingIndex] = existing.enriching(
                    btmUUID: record.uuid,
                    teamIdentifier: record.teamIdentifier,
                    developerName: record.developerName,
                    parentBundleIdentifier: existing.parentBundleIdentifier,
                    parentDisplayName: record.parentIdentifier ?? existing.parentDisplayName,
                    associatedBundleIDs: record.associatedBundleIDs,
                    loadStatus: status
                )
                continue
            }

            if let existingIndex = indexByPlist[path] {
                items[existingIndex] = items[existingIndex].enriching(
                    btmUUID: record.uuid,
                    teamIdentifier: record.teamIdentifier,
                    developerName: record.developerName,
                    associatedBundleIDs: record.associatedBundleIDs,
                    loadStatus: items[existingIndex].loadStatus.isOrphaned ? nil : record.loadStatus
                )
                continue
            }

            if let modernIndex = items.enumerated().first(where: { $0.element.resolvedSourcePath == path || $0.element.id.contains(path) })?.offset {
                items[modernIndex] = items[modernIndex].enriching(
                    btmUUID: record.uuid,
                    teamIdentifier: record.teamIdentifier,
                    developerName: record.developerName,
                    parentDisplayName: record.parentIdentifier ?? items[modernIndex].parentDisplayName,
                    associatedBundleIDs: record.associatedBundleIDs,
                    loadStatus: items[modernIndex].loadStatus.isOrphaned ? nil : record.loadStatus
                )
                continue
            }

            items.append(attachHelpers(makeItem(from: record)))
        }

        for item in modern {
            if items.contains(where: { $0.resolvedSourcePath == item.resolvedSourcePath || $0.id == item.id }) {
                continue
            }
            if !item.plistPath.isEmpty, indexByPlist[item.plistPath] != nil {
                continue
            }
            items.append(attachHelpers(item))
            if !item.plistPath.isEmpty {
                indexByPlist[item.plistPath] = items.count - 1
            }
            indexByLabel[item.label] = items.count - 1
        }

        return items.sortedForDisplay()
    }

    private func makeItem(from record: BTMRecord) -> StartupItem {
        let path = record.filePath
        let executable = record.executablePath ?? path
        let exists = FileManager.default.fileExists(atPath: executable) || FileManager.default.fileExists(atPath: path)
        let parent = ParentAppResolver.parentApp(for: path.isEmpty ? executable : path)
        let type = record.inferredType
        let plistPath = path.lowercased().hasSuffix(".plist") ? path : ""
        let loadStatus: LoadStatus = exists ? record.loadStatus : .orphaned
        let origin = ItemOrigin.classify(
            label: record.identifier,
            plistPath: path,
            executablePath: executable
        )
        let id: String
        if let uuid = optionalUUID(record.uuid) {
            id = "btm:\(uuid)"
        } else {
            id = "source:\(type.rawValue):\(path.isEmpty ? record.identifier : path)"
        }

        return StartupItem(
            id: id,
            label: record.identifier.isEmpty ? record.name : record.identifier,
            plistPath: plistPath,
            executablePath: executable,
            arguments: [],
            type: type,
            runAtLoad: type == .loginItem,
            keepAliveDescription: nil,
            executableExists: exists,
            loadStatus: loadStatus,
            workingDirectory: nil,
            environmentVariables: [:],
            standardOutPath: nil,
            standardErrorPath: nil,
            appDisplayName: record.developerName ?? record.name,
            appBundleName: record.parentIdentifier,
            appBundleIdentifier: record.associatedBundleIDs.first ?? record.identifier,
            appBundlePath: parent.path,
            origin: origin,
            launchdLoaded: loadStatus == .loaded && type.supportsLaunchctl,
            persistentlyDisabled: loadStatus == .disabled,
            parentBundleIdentifier: parent.bundleIdentifier,
            parentDisplayName: record.parentIdentifier ?? parent.displayName,
            associatedBundleIDs: record.associatedBundleIDs,
            teamIdentifier: record.teamIdentifier,
            developerName: record.developerName,
            btmUUID: record.uuid,
            sourceURL: path
        )
    }

    private func optionalUUID(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }

    private func helpers(from map: [String: [RelatedHelper]], parentPath: String?) -> [RelatedHelper]? {
        guard let parentPath, !parentPath.isEmpty else { return nil }
        if let exact = map[parentPath] { return exact }
        let resolved = URL(fileURLWithPath: parentPath).resolvingSymlinksInPath().standardizedFileURL.path
        if let match = map[resolved] { return match }
        return map.first {
            URL(fileURLWithPath: $0.key).resolvingSymlinksInPath().standardizedFileURL.path == resolved
        }?.value
    }
}
