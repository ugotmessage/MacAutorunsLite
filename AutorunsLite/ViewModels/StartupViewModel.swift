import Foundation
import AppKit

struct OperationFailure: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let command: String
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var copyText: String {
        """
        \(title)

        Command:
        \(command)

        Exit code:
        \(exitCode)

        stdout:
        \(stdout.isEmpty ? "(empty)" : stdout)

        stderr:
        \(stderr.isEmpty ? "(empty)" : stderr)
        """
    }

    var permissionDenied: Bool {
        let haystack = (stderr + "\n" + stdout).lowercased()
        return haystack.contains("permission")
            || haystack.contains("not privileged")
            || haystack.contains("input/output error")
            || exitCode == 1 && haystack.contains("denied")
            || exitCode == 5
    }
}

struct SessionLogEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let message: String
}

@MainActor
final class StartupViewModel: ObservableObject {
    @Published var items: [StartupItem] = []
    @Published var searchText = ""
    @Published var selectedFilter: StartupFilter = .all
    @Published var selectedItemID: StartupItem.ID?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var operationFailure: OperationFailure?
    @Published var pendingDisableItem: StartupItem?
    @Published var sessionLog: [SessionLogEntry] = []
    @Published var showingPlistViewer = false
    @Published var showingDebugLog = false
    @Published var lastScanDate: Date?
    @Published var collapsedGroups: Set<StatusGroupKind> = []
    @Published var safeActionDryRun: SafeActionDryRun?
    @Published var showingSafeActionPreview = false
    @Published var safeActionResult: SafeActionBatchResult?
    @Published var showingSafeActionResult = false
    @Published var lastSafeActionWasUndo = false
    @Published var isPerformingSafeAction = false
    @Published var showingStatusHelp = false
    @Published var pendingTrashItem: StartupItem?
    @Published private(set) var notesByPath: [String: String] = [:]
    @Published private(set) var modernSourceWarning: String?
    @Published private(set) var includeSystemItems = false
    @Published private(set) var systemLoadNotice: String?
    @Published private(set) var isLoadingSystemStartupItems = false

    private let scanner: StartupScanner
    private let launchctl: LaunchctlService
    private let classifier = SafetyClassifier()
    private let recommendationResolver = RecommendationResolver()
    private let safeActionService = SafeActionService()
    private let trashService: TrashService
    private let notesStore: ItemNotesStore

    init(
        scanner: StartupScanner = StartupScanner(),
        launchctl: LaunchctlService = LaunchctlService(),
        trashService: TrashService = WorkspaceTrashService(),
        notesStore: ItemNotesStore = ItemNotesStore()
    ) {
        self.scanner = scanner
        self.launchctl = launchctl
        self.trashService = trashService
        self.notesStore = notesStore
        self.notesByPath = notesStore.load()
    }

    var selectedItem: StartupItem? {
        items.first { $0.id == selectedItemID }
    }

    var visibleItems: [StartupItem] {
        items.filter { item in
            selectedFilter.matches(item) && matchesSearch(item)
        }
    }

    var visibleStatusGroups: [StatusGroup] {
        visibleItems.groupedByStatus()
    }

    var totalCount: Int { items.count }
    var loadedCount: Int { items.filter { $0.loadStatus == .loaded }.count }
    var disabledCount: Int { items.filter { $0.loadStatus == .disabled }.count }
    var orphanedCount: Int { items.filter(\.loadStatus.isOrphaned).count }
    var unloadedCount: Int { items.filter { $0.loadStatus == .unloaded }.count }
    var modernSourceCount: Int { items.filter(\.type.isModernSource).count }

    var currentSafeActionDryRun: SafeActionDryRun {
        classifier.dryRun(items: items)
    }

    var safeActionCount: Int {
        currentSafeActionDryRun.safeCount
    }

    var reviewRequiredCount: Int {
        items.filter { recommendation(for: $0).recommendation == .reviewRequired }.count
    }

    func recommendation(for item: StartupItem) -> RecommendationResult {
        recommendationResolver.resolve(item)
    }

    func canMoveToTrash(_ item: StartupItem) -> Bool {
        TrashEligibility.canMoveToTrash(item, recommendation: recommendation(for: item).recommendation)
    }

    var canUndoSafeAction: Bool {
        safeActionService.lastSnapshot() != nil
    }

    func lastScanDescription(at date: Date = Date()) -> String {
        guard let lastScanDate else { return L10n.text("scan.never") }
        let elapsed = date.timeIntervalSince(lastScanDate)
        if elapsed < 45 {
            return L10n.text("scan.just_now")
        }
        if elapsed < 3600 {
            return L10n.text("scan.minutes_ago", ["minutes": "\(max(1, Int(elapsed / 60)))"])
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLocalization.shared.currentLocale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastScanDate, relativeTo: date)
    }

    func applyFilter(_ filter: StartupFilter) {
        selectedFilter = filter
        selectedItemID = nil
    }

    func isGroupExpanded(_ kind: StatusGroupKind) -> Bool {
        !collapsedGroups.contains(kind)
    }

    func setGroupExpanded(_ kind: StatusGroupKind, expanded: Bool) {
        if expanded {
            collapsedGroups.remove(kind)
        } else {
            collapsedGroups.insert(kind)
        }
    }

    var loadingMessage: String {
        if isLoadingSystemStartupItems {
            return L10n.text("app.progress.loading_system_items")
        }
        return L10n.text("app.progress.scanning")
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        log(includeSystemItems ? "scan started (user + system)" : "scan started (user)")
        let scanned = await scanner.scanResult(includeSystemItems: includeSystemItems)
        items = scanned.items
        if includeSystemItems {
            modernSourceWarning = scanned.modernSourceWarning
        } else {
            modernSourceWarning = nil
            systemLoadNotice = nil
        }
        lastScanDate = Date()
        if let selectedItemID, !scanned.items.contains(where: { $0.id == selectedItemID }) {
            self.selectedItemID = nil
        }
        log("found \(scanned.items.count) items")
        if let warning = scanned.modernSourceWarning, includeSystemItems {
            log(warning)
        }
    }

    func loadSystemStartupItems() async {
        guard !includeSystemItems else {
            await refresh()
            return
        }

        isLoading = true
        isLoadingSystemStartupItems = true
        defer {
            isLoading = false
            isLoadingSystemStartupItems = false
        }

        let previousSystemCount = items.filter(\.type.isSystemLaunchd).count
        log("load system startup items requested")
        let scanned = await scanner.scanResult(includeSystemItems: true)
        let systemCount = scanned.items.filter(\.type.isSystemLaunchd).count

        if SystemLoadDecision.shouldCommit(scanned: scanned, previousSystemCount: previousSystemCount) {
            includeSystemItems = true
            items = scanned.items
            modernSourceWarning = scanned.modernSourceWarning
            systemLoadNotice = nil
            lastScanDate = Date()
            if let selectedItemID, !scanned.items.contains(where: { $0.id == selectedItemID }) {
                self.selectedItemID = nil
            }
            log("system startup items loaded (\(systemCount) system launchd items)")
            if let warning = scanned.modernSourceWarning {
                log(warning)
            }
            return
        }

        includeSystemItems = false
        modernSourceWarning = nil
        systemLoadNotice = L10n.text("detail.system_load_notice")
        log("system startup items load cancelled or denied")

        let userScan = await scanner.scanResult(includeSystemItems: false)
        items = userScan.items
        lastScanDate = Date()
        if let selectedItemID, !userScan.items.contains(where: { $0.id == selectedItemID }) {
            self.selectedItemID = nil
        }
        log("found \(userScan.items.count) items (user only)")
    }

    func start(_ item: StartupItem) async {
        await runMutation(item: item, title: L10n.text("error.cannot_start")) { current in
            guard let domain = current.type.launchctlDomain else {
                return LaunchctlResult(command: "", exitCode: -1, stdout: "", stderr: "Not a launchd item")
            }
            return await self.launchctl.bootstrap(domain: domain, plistPath: current.plistPath)
        }
    }

    func stop(_ item: StartupItem) async {
        await runMutation(item: item, title: L10n.text("error.cannot_stop")) { current in
            guard let domain = current.type.launchctlDomain else {
                return LaunchctlResult(command: "", exitCode: -1, stdout: "", stderr: "Not a launchd item")
            }
            return await self.launchctl.bootout(domain: domain, plistPath: current.plistPath)
        }
    }

    func enable(_ item: StartupItem) async {
        await runMutation(item: item, title: L10n.text("error.cannot_enable")) { current in
            guard let domain = current.type.launchctlDomain else {
                return LaunchctlResult(command: "", exitCode: -1, stdout: "", stderr: "Not a launchd item")
            }
            return await self.launchctl.enable(domain: domain, label: current.label)
        }
    }

    func requestDisable(_ item: StartupItem) {
        pendingDisableItem = item
    }

    func confirmDisable() async {
        guard let item = pendingDisableItem else { return }
        pendingDisableItem = nil
        await disable(item)
    }

    func cancelDisable() {
        pendingDisableItem = nil
    }

    func disable(_ item: StartupItem) async {
        await runMutation(item: item, title: L10n.text("error.cannot_disable")) { current in
            guard let domain = current.type.launchctlDomain else {
                return LaunchctlResult(command: "", exitCode: -1, stdout: "", stderr: "Not a launchd item")
            }
            return await self.launchctl.disable(domain: domain, label: current.label)
        }
    }

    func presentSafeActionPreview() {
        let dryRun = classifier.dryRun(items: items)
        safeActionDryRun = dryRun
        showingSafeActionPreview = true
        log("safe action dry run: safe \(dryRun.safeCount), review \(dryRun.reviewCount), protected \(dryRun.protectedCount)")
    }

    func cancelSafeActionPreview() {
        showingSafeActionPreview = false
    }

    func confirmSafeAction() async {
        showingSafeActionPreview = false
        isPerformingSafeAction = true
        let dryRun = classifier.dryRun(items: items)
        safeActionDryRun = dryRun
        let safeItems = dryRun.safeItems
        guard !safeItems.isEmpty else {
            isPerformingSafeAction = false
            log("safe action skipped: no items remained safe after dry run")
            return
        }
        log("safe action started \(safeItems.count)")
        let result = await safeActionService.perform(safeItems: safeItems)
        lastSafeActionWasUndo = false
        safeActionResult = result
        showingSafeActionResult = true
        isPerformingSafeAction = false
        log("safe action finished success \(result.succeeded) failed \(result.failed)")
        await refresh()
    }

    func undoLastSafeAction() async {
        showingSafeActionResult = false
        showingSafeActionPreview = false
        guard canUndoSafeAction else { return }
        isPerformingSafeAction = true
        log("safe action undo started")
        let result = await safeActionService.undoLast()
        lastSafeActionWasUndo = true
        safeActionResult = result
        showingSafeActionResult = true
        isPerformingSafeAction = false
        log("safe action undo finished success \(result.succeeded) failed \(result.failed)")
        await refresh()
    }

    func dismissSafeActionResult() {
        showingSafeActionResult = false
    }

    func requestMoveToTrash(_ item: StartupItem) {
        guard canMoveToTrash(item) else { return }
        pendingTrashItem = item
    }

    func cancelMoveToTrash() {
        pendingTrashItem = nil
    }

    func confirmMoveToTrash() async {
        guard let item = pendingTrashItem else { return }
        pendingTrashItem = nil
        guard canMoveToTrash(item) else {
            operationFailure = OperationFailure(
                title: L10n.text("error.trash_not_eligible"),
                command: "",
                exitCode: -1,
                stdout: "",
                stderr: item.label
            )
            return
        }
        guard TrashEligibility.isAllowedUserLaunchAgentPlist(item) else {
            operationFailure = OperationFailure(
                title: L10n.text("error.trash_user_agent_only"),
                command: "",
                exitCode: -1,
                stdout: "",
                stderr: item.plistPath
            )
            return
        }

        isPerformingSafeAction = true
        log("move to trash started \(item.label)")

        if item.launchdLoaded {
            let domain = item.type.launchctlDomain ?? "gui/\(getuid())"
            let bootout = await launchctl.bootout(domain: domain, plistPath: item.plistPath)
            if !bootout.succeeded
                && !bootout.combinedOutput.lowercased().contains("could not find service")
                && !bootout.combinedOutput.lowercased().contains("not found")
            {
                isPerformingSafeAction = false
                operationFailure = OperationFailure(
                    title: L10n.text("error.trash_stop_failed"),
                    command: bootout.command,
                    exitCode: bootout.exitCode,
                    stdout: bootout.stdout,
                    stderr: bootout.stderr
                )
                return
            }
        }

        if !item.persistentlyDisabled {
            let disable = await launchctl.disable(domain: item.type.launchctlDomain ?? "gui/\(getuid())", label: item.label)
            if !disable.succeeded {
                isPerformingSafeAction = false
                operationFailure = OperationFailure(
                    title: L10n.text("error.trash_disable_failed"),
                    command: disable.command,
                    exitCode: disable.exitCode,
                    stdout: disable.stdout,
                    stderr: disable.stderr
                )
                return
            }
        }

        do {
            try await trashService.trash(url: URL(fileURLWithPath: item.plistPath))
            log("moved to trash \(item.label)")
        } catch {
            isPerformingSafeAction = false
            operationFailure = OperationFailure(
                title: L10n.text("error.trash_move_failed"),
                command: "NSWorkspace.recycle",
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription
            )
            await refreshTarget(item)
            return
        }

        isPerformingSafeAction = false
        await refresh()
        if selectedItemID == item.id {
            selectedItemID = nil
        }
    }

    func relatedItems(for item: StartupItem) -> [StartupItem] {
        AppRelationMatcher.related(to: item, in: items)
    }

    func showInFinder(_ item: StartupItem) {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: item.resolvedSourcePath)
        ])
    }

    func copyLabel(_ item: StartupItem) {
        copyToPasteboard(item.label)
    }

    func copyPlistPath(_ item: StartupItem) {
        copyToPasteboard(item.resolvedSourcePath)
    }

    func copyExecutablePath(_ item: StartupItem) {
        copyToPasteboard(item.executablePath ?? "")
    }

    func copyError() {
        guard let operationFailure else { return }
        copyToPasteboard(operationFailure.copyText)
    }

    func openLoginItems() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            let ok = NSWorkspace.shared.open(url)
            if ok { return }
        }
        if let settings = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(settings)
        }
    }

    func openServiceResearch(
        for item: StartupItem,
        settings: AppSettings,
        session: ServiceResearchSession,
        openEmbedded: () -> Void
    ) {
        session.item = item
        session.initialQueryType = .overview
        let research = ServiceResearchService()
        let result = research.query(item: item, type: .overview, settings: settings)
        switch settings.researchBrowserMode {
        case .embedded:
            openEmbedded()
        case .system:
            if let url = research.searchURL(for: result.query) {
                NSWorkspace.shared.open(url)
            } else {
                log("unable to build search URL for \(result.query)")
                operationFailure = OperationFailure(
                    title: L10n.text("error.cannot_build_search_url"),
                    command: result.query,
                    exitCode: -1,
                    stdout: "",
                    stderr: "Search URL builder returned nil"
                )
            }
        }
    }

    func canStart(_ item: StartupItem) -> Bool {
        item.type.supportsLaunchctl
            && !item.isSystemProtected
            && !item.loadStatus.isOrphaned
            && item.loadStatus != .loaded
    }

    func canStop(_ item: StartupItem) -> Bool {
        item.type.supportsLaunchctl && !item.isSystemProtected && item.loadStatus == .loaded
    }

    func canEnable(_ item: StartupItem) -> Bool {
        item.type.supportsLaunchctl && !item.isSystemProtected && item.loadStatus == .disabled
    }

    func canDisable(_ item: StartupItem) -> Bool {
        item.type.supportsLaunchctl && !item.isSystemProtected && item.loadStatus != .disabled
    }

    func note(for item: StartupItem) -> String {
        notesByPath[item.id] ?? notesByPath[item.plistPath] ?? ""
    }

    func notePreview(for item: StartupItem) -> String? {
        let trimmed = note(for: item)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    func setNote(_ text: String, for item: StartupItem) {
        var updated = notesByPath
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            updated.removeValue(forKey: item.id)
            if !item.plistPath.isEmpty {
                updated.removeValue(forKey: item.plistPath)
            }
        } else {
            updated[item.id] = text
            if !item.plistPath.isEmpty, item.plistPath != item.id {
                updated.removeValue(forKey: item.plistPath)
            }
        }
        notesByPath = updated
        notesStore.save(updated)
    }

    private func runMutation(
        item: StartupItem,
        title: String,
        operation: (StartupItem) async -> LaunchctlResult
    ) async {
        if item.isSystemProtected {
            operationFailure = OperationFailure(
                title: L10n.text("error.protected_item"),
                command: "",
                exitCode: -1,
                stdout: "",
                stderr: "Protected system item: \(item.label)"
            )
            return
        }
        if !item.type.supportsLaunchctl {
            operationFailure = OperationFailure(
                title: L10n.text("error.manage_in_system_settings"),
                command: "",
                exitCode: -1,
                stdout: "",
                stderr: "Modern startup source: \(item.label)"
            )
            return
        }

        let result = await operation(item)
        if result.succeeded {
            log("\(title) \(item.label)")
            await refreshTarget(item)
            return
        }

        var failure = OperationFailure(
            title: title,
            command: result.command,
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr
        )
        if failure.permissionDenied {
            failure = OperationFailure(
                title: L10n.text("error.needs_admin"),
                command: result.command,
                exitCode: result.exitCode,
                stdout: result.stdout,
                stderr: result.stderr
            )
        }
        operationFailure = failure
        log("error \(item.label): \(result.combinedOutput)")
        await refreshTarget(item)
    }

    private func refreshTarget(_ item: StartupItem) async {
        if let updated = await scanner.refreshItem(item) {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = updated
            } else {
                items.append(updated)
            }
            items = items.sortedForDisplay()
            selectedItemID = updated.id
        } else if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            if selectedItemID == item.id {
                selectedItemID = nil
            }
        }
    }

    private func matchesSearch(_ item: StartupItem) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let haystack = [
            item.label,
            item.executablePath ?? "",
            item.plistPath,
            item.resolvedSourcePath,
            item.arguments.joined(separator: " "),
            item.displayName,
            item.appBundleIdentifier ?? "",
            item.parentBundleIdentifier ?? "",
            item.teamIdentifier ?? "",
            note(for: item)
        ].joined(separator: "\n")
        return haystack.localizedCaseInsensitiveContains(query)
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func log(_ message: String) {
        sessionLog.append(SessionLogEntry(date: Date(), message: message))
    }
}
