import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings
    @StateObject private var viewModel = StartupViewModel()

    var body: some View {
        NavigationSplitView {
            StartupListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 560, ideal: 760)
        } detail: {
            StartupDetailView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        }
        .searchable(text: $viewModel.searchText, prompt: L10n.text("app.search_prompt"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await viewModel.loadSystemStartupItems() }
                } label: {
                    Label(
                        viewModel.includeSystemItems ? L10n.text("app.toolbar.system_items_loaded") : L10n.text("app.toolbar.load_system_items"),
                        systemImage: viewModel.includeSystemItems ? "checkmark.seal" : "externaldrive.badge.plus"
                    )
                }
                .disabled(viewModel.isLoading || viewModel.isPerformingSafeAction || viewModel.includeSystemItems)
                .help(L10n.text("app.toolbar.load_system_items_help"))
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.presentSafeActionPreview()
                } label: {
                    Label(
                        viewModel.safeActionCount > 0
                            ? L10n.text("app.toolbar.safe_action_count", ["count": "\(viewModel.safeActionCount)"])
                            : L10n.text("app.toolbar.safe_action"),
                        systemImage: "checkmark.shield"
                    )
                }
                .disabled(viewModel.isLoading || viewModel.isPerformingSafeAction)
                .help(
                    viewModel.safeActionCount > 0
                        ? L10n.text("app.toolbar.safe_action_help_available", ["count": "\(viewModel.safeActionCount)"])
                        : L10n.text("app.toolbar.safe_action_help_none")
                )
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label(L10n.text("app.toolbar.refresh"), systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(viewModel.isLoading)
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(L10n.text("app.menu.rescan"), systemImage: "arrow.clockwise") {
                        Task { await viewModel.refresh() }
                    }
                    .disabled(viewModel.isLoading)
                    Button(L10n.text("app.toolbar.load_system_items"), systemImage: "externaldrive.badge.plus") {
                        Task { await viewModel.loadSystemStartupItems() }
                    }
                    .disabled(viewModel.isLoading || viewModel.includeSystemItems)
                    Button(L10n.text("app.toolbar.safe_action"), systemImage: "checkmark.shield") {
                        viewModel.presentSafeActionPreview()
                    }
                    .disabled(viewModel.isLoading || viewModel.isPerformingSafeAction)
                    Button(L10n.text("app.menu.undo_last_safe_action"), systemImage: "arrow.uturn.backward") {
                        Task { await viewModel.undoLastSafeAction() }
                    }
                    .disabled(!viewModel.canUndoSafeAction || viewModel.isPerformingSafeAction)
                    Divider()
                    Button(L10n.text("app.menu.open_login_items"), systemImage: "person.crop.circle") {
                        viewModel.openLoginItems()
                    }
                    Divider()
                    Button(L10n.text("app.menu.settings"), systemImage: "gearshape") {
                        openAppSettings()
                    }
                    Picker(L10n.text("app.menu.appearance"), selection: settings.appearanceModeBinding) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                    Button(L10n.text("app.menu.session_log"), systemImage: "text.alignleft") {
                        viewModel.showingDebugLog = true
                    }
                } label: {
                    Label(L10n.text("common.more"), systemImage: "ellipsis.circle")
                }
            }
        }
        .navigationTitle(L10n.text("app.window_title"))
        .task {
            // XCTest launches this app as TEST_HOST; skip the automatic scan
            // so tests can drive launchctl themselves.
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
                return
            }
            // Let the window appear before the first scan starts.
            await Task.yield()
            await viewModel.refresh()
        }
        .sheet(item: $viewModel.operationFailure) { failure in
            ErrorSheet(failure: failure, onCopy: viewModel.copyError)
        }
        .sheet(isPresented: $viewModel.showingPlistViewer) {
            if let item = viewModel.selectedItem {
                PlistViewerSheet(plistPath: item.plistPath)
            }
        }
        .sheet(isPresented: $viewModel.showingDebugLog) {
            SessionLogSheet(entries: viewModel.sessionLog)
        }
        .sheet(isPresented: $viewModel.showingSafeActionPreview) {
            if let dryRun = viewModel.safeActionDryRun {
                SafeActionPreviewSheet(
                    dryRun: dryRun,
                    onCancel: viewModel.cancelSafeActionPreview,
                    onConfirm: {
                        Task { await viewModel.confirmSafeAction() }
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showingSafeActionResult) {
            if let result = viewModel.safeActionResult {
                SafeActionResultSheet(
                    result: result,
                    isUndo: viewModel.lastSafeActionWasUndo,
                    onDone: viewModel.dismissSafeActionResult,
                    onUndo: {
                        Task { await viewModel.undoLastSafeAction() }
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showingStatusHelp) {
            StatusHelpSheet()
        }
        .sheet(item: $viewModel.pendingTrashItem) { item in
            MoveToTrashSheet(
                item: item,
                onCancel: viewModel.cancelMoveToTrash,
                onConfirm: {
                    Task { await viewModel.confirmMoveToTrash() }
                }
            )
        }
        .confirmationDialog(
            disableTitle,
            isPresented: Binding(
                get: { viewModel.pendingDisableItem != nil },
                set: { if !$0 { viewModel.cancelDisable() } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.text("common.disable")) {
                Task { await viewModel.confirmDisable() }
            }
            Button(L10n.text("common.cancel"), role: .cancel) {
                viewModel.cancelDisable()
            }
        } message: {
            Text(L10n.text("disable_confirm.message"))
        }
        .overlay {
            if viewModel.isPerformingSafeAction {
                ProgressView(L10n.text("app.progress.working"))
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if viewModel.isLoading {
                ProgressView(viewModel.loadingMessage)
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var disableTitle: String {
        if let item = viewModel.pendingDisableItem {
            return L10n.text("disable_confirm.title_with_label", ["label": item.label])
        }
        return L10n.text("disable_confirm.title_generic")
    }

    private func openAppSettings() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .environmentObject(ServiceResearchSession())
}
