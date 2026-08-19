import Foundation

struct SafeActionService: Sendable {
    private let launchctl: LaunchctlService
    private let snapshotStore: SafeActionSnapshotStore
    private let classifier: SafetyClassifier

    init(
        launchctl: LaunchctlService = LaunchctlService(),
        snapshotStore: SafeActionSnapshotStore = SafeActionSnapshotStore(),
        classifier: SafetyClassifier = SafetyClassifier()
    ) {
        self.launchctl = launchctl
        self.snapshotStore = snapshotStore
        self.classifier = classifier
    }

    func lastSnapshot() -> SafeActionSnapshot? {
        snapshotStore.load()
    }

    func perform(safeItems: [StartupItem]) async -> SafeActionBatchResult {
        var results: [SafeActionItemResult] = []
        var entries: [SafeActionSnapshotEntry] = []
        let timestamp = Date()

        for item in safeItems {
            let verdict = classifier.classify(item)
            guard verdict.classification == .safe else {
                results.append(
                    SafeActionItemResult(
                        id: item.id,
                        label: item.label,
                        outcome: .skipped,
                        detail: verdict.reason
                    )
                )
                continue
            }

            let (result, entry) = await process(item: item, timestamp: timestamp)
            results.append(result)
            if let entry {
                entries.append(entry)
            }
        }

        let snapshot = entries.isEmpty ? nil : SafeActionSnapshot(timestamp: timestamp, entries: entries)
        if let snapshot {
            try? snapshotStore.save(snapshot)
        }

        return SafeActionBatchResult(
            id: UUID(),
            succeeded: results.filter { $0.outcome == .succeeded }.count,
            failed: results.filter { $0.outcome == .failed }.count,
            skipped: results.filter { $0.outcome == .skipped }.count,
            items: results,
            snapshot: snapshot
        )
    }

    func undoLast() async -> SafeActionBatchResult {
        guard let snapshot = snapshotStore.load() else {
            return SafeActionBatchResult(
                id: UUID(),
                succeeded: 0,
                failed: 0,
                skipped: 0,
                items: [],
                snapshot: nil
            )
        }

        var results: [SafeActionItemResult] = []
        for entry in snapshot.entries.reversed() {
            results.append(await undo(entry: entry))
        }
        snapshotStore.clear()

        return SafeActionBatchResult(
            id: UUID(),
            succeeded: results.filter { $0.outcome == .succeeded }.count,
            failed: results.filter { $0.outcome == .failed }.count,
            skipped: results.filter { $0.outcome == .skipped }.count,
            items: results,
            snapshot: snapshot
        )
    }

    private func process(
        item: StartupItem,
        timestamp: Date
    ) async -> (SafeActionItemResult, SafeActionSnapshotEntry?) {
        var actions: [String] = []
        var details: [String] = []

        if item.launchdLoaded {
            let bootout = await launchctl.bootout(domain: item.type.launchctlDomain, plistPath: item.plistPath)
            if bootout.succeeded || isAlreadyUnloaded(bootout) {
                actions.append("bootout")
            } else {
                return (
                    SafeActionItemResult(
                        id: item.id,
                        label: item.label,
                        outcome: .failed,
                        detail: "launchctl bootout failed\n\(bootout.combinedOutput)"
                    ),
                    nil
                )
            }
        }

        if item.persistentlyDisabled {
            details.append("原本已停用，略過 disable")
        } else {
            let disable = await launchctl.disable(domain: item.type.launchctlDomain, label: item.label)
            if disable.succeeded {
                actions.append("disable")
            } else {
                return (
                    SafeActionItemResult(
                        id: item.id,
                        label: item.label,
                        outcome: .failed,
                        detail: "launchctl disable failed\n\(disable.combinedOutput)"
                    ),
                    SafeActionSnapshotEntry(
                        label: item.label,
                        plistPath: item.plistPath,
                        type: item.type.rawValue,
                        loadedBefore: item.launchdLoaded,
                        disabledBefore: item.persistentlyDisabled,
                        timestamp: timestamp,
                        actionPerformed: actions
                    )
                )
            }
        }

        let entry = SafeActionSnapshotEntry(
            label: item.label,
            plistPath: item.plistPath,
            type: item.type.rawValue,
            loadedBefore: item.launchdLoaded,
            disabledBefore: item.persistentlyDisabled,
            timestamp: timestamp,
            actionPerformed: actions
        )
        return (
            SafeActionItemResult(
                id: item.id,
                label: item.label,
                outcome: .succeeded,
                detail: (actions + details).joined(separator: "、")
            ),
            entry
        )
    }

    private func undo(entry: SafeActionSnapshotEntry) async -> SafeActionItemResult {
        let type = StartupItemType(rawValue: entry.type) ?? .userLaunchAgent
        let domain = type.launchctlDomain
        var details: [String] = []

        if !entry.disabledBefore {
            let enable = await launchctl.enable(domain: domain, label: entry.label)
            if !enable.succeeded {
                return SafeActionItemResult(
                    id: entry.plistPath,
                    label: entry.label,
                    outcome: .failed,
                    detail: "launchctl enable failed\n\(enable.combinedOutput)"
                )
            }
            details.append("enable")
        }

        if entry.loadedBefore {
            let bootstrap = await launchctl.bootstrap(domain: domain, plistPath: entry.plistPath)
            if !bootstrap.succeeded && !bootstrap.combinedOutput.lowercased().contains("already") {
                return SafeActionItemResult(
                    id: entry.plistPath,
                    label: entry.label,
                    outcome: .failed,
                    detail: "launchctl bootstrap failed\n\(bootstrap.combinedOutput)"
                )
            }
            details.append("bootstrap")
        }

        return SafeActionItemResult(
            id: entry.plistPath,
            label: entry.label,
            outcome: .succeeded,
            detail: details.isEmpty ? "已恢復原狀態" : details.joined(separator: "、")
        )
    }

    private func isAlreadyUnloaded(_ result: LaunchctlResult) -> Bool {
        let output = result.combinedOutput.lowercased()
        return output.contains("could not find service") || output.contains("not found")
    }
}
