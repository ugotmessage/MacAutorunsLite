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
        guard let lastScanDate else { return "尚未掃描" }
        let elapsed = date.timeIntervalSince(lastScanDate)
        if elapsed < 45 {
            return "剛剛"
        }
        if elapsed < 3600 {
            return "\(max(1, Int(elapsed / 60))) 分鐘前"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
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

    func refresh() async {
        isLoading = true
        errorMessage = nil
        log("scan started")
        let scanned = await scanner.scan()
        items = scanned
        lastScanDate = Date()
        if let selectedItemID, !scanned.contains(where: { $0.id == selectedItemID }) {
            self.selectedItemID = nil
        }
        isLoading = false
        log("found \(scanned.count) items")
    }

    func start(_ item: StartupItem) async {
        await runMutation(item: item, title: "無法啟動此項目。") { current in
            await self.launchctl.bootstrap(domain: current.type.launchctlDomain, plistPath: current.plistPath)
        }
    }

    func stop(_ item: StartupItem) async {
        await runMutation(item: item, title: "無法停止此項目。") { current in
            await self.launchctl.bootout(domain: current.type.launchctlDomain, plistPath: current.plistPath)
        }
    }

    func enable(_ item: StartupItem) async {
        await runMutation(item: item, title: "無法啟用此項目。") { current in
            await self.launchctl.enable(domain: current.type.launchctlDomain, label: current.label)
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
        await runMutation(item: item, title: "無法停用此項目。") { current in
            await self.launchctl.disable(domain: current.type.launchctlDomain, label: current.label)
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
                title: "此項目不符合移到垃圾桶的條件。",
                command: "",
                exitCode: -1,
                stdout: "",
                stderr: item.label
            )
            return
        }
        guard TrashEligibility.isAllowedUserLaunchAgentPlist(item) else {
            operationFailure = OperationFailure(
                title: "只能將使用者 LaunchAgent 的 plist 移到垃圾桶。",
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
            let bootout = await launchctl.bootout(domain: item.type.launchctlDomain, plistPath: item.plistPath)
            if !bootout.succeeded
                && !bootout.combinedOutput.lowercased().contains("could not find service")
                && !bootout.combinedOutput.lowercased().contains("not found")
            {
                isPerformingSafeAction = false
                operationFailure = OperationFailure(
                    title: "無法停止此項目，因此沒有移到垃圾桶。",
                    command: bootout.command,
                    exitCode: bootout.exitCode,
                    stdout: bootout.stdout,
                    stderr: bootout.stderr
                )
                return
            }
        }

        if !item.persistentlyDisabled {
            let disable = await launchctl.disable(domain: item.type.launchctlDomain, label: item.label)
            if !disable.succeeded {
                isPerformingSafeAction = false
                operationFailure = OperationFailure(
                    title: "無法停用此項目，因此沒有移到垃圾桶。",
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
                title: "無法將 plist 移到垃圾桶。",
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

    func showInFinder(_ item: StartupItem) {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: item.plistPath)
        ])
    }

    func copyLabel(_ item: StartupItem) {
        copyToPasteboard(item.label)
    }

    func copyPlistPath(_ item: StartupItem) {
        copyToPasteboard(item.plistPath)
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
                    title: "無法建立搜尋網址。",
                    command: result.query,
                    exitCode: -1,
                    stdout: "",
                    stderr: "Search URL builder returned nil"
                )
            }
        }
    }

    func canStart(_ item: StartupItem) -> Bool {
        !item.isSystemProtected && !item.loadStatus.isOrphaned && item.loadStatus != .loaded
    }

    func canStop(_ item: StartupItem) -> Bool {
        !item.isSystemProtected && item.loadStatus == .loaded
    }

    func canEnable(_ item: StartupItem) -> Bool {
        !item.isSystemProtected && item.loadStatus == .disabled
    }

    func canDisable(_ item: StartupItem) -> Bool {
        !item.isSystemProtected && item.loadStatus != .disabled
    }

    func note(for item: StartupItem) -> String {
        notesByPath[item.plistPath] ?? ""
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
            updated.removeValue(forKey: item.plistPath)
        } else {
            updated[item.plistPath] = text
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
                title: "系統項目預設不允許修改，以避免影響 macOS。",
                command: "",
                exitCode: -1,
                stdout: "",
                stderr: "Protected system item: \(item.label)"
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
                title: "此項目需要系統管理員權限才能修改。",
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
            item.arguments.joined(separator: " "),
            item.displayName,
            item.appBundleIdentifier ?? "",
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
