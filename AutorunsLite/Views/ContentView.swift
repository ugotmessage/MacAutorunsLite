import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = StartupViewModel()

    var body: some View {
        NavigationSplitView {
            StartupListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 560, ideal: 760)
        } detail: {
            StartupDetailView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        }
        .searchable(text: $viewModel.searchText, prompt: "搜尋 Label、路徑、執行檔")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.presentSafeActionPreview()
                } label: {
                    Label(
                        viewModel.safeActionCount > 0
                            ? "安全處理 \(viewModel.safeActionCount)"
                            : "安全處理",
                        systemImage: "checkmark.shield"
                    )
                }
                .disabled(viewModel.isLoading || viewModel.isPerformingSafeAction)
                .help(
                    viewModel.safeActionCount > 0
                        ? "\(viewModel.safeActionCount) 個項目可安全處理"
                        : "沒有可自動處理的低風險殘留項目"
                )
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("重新整理", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(viewModel.isLoading)
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("重新掃描", systemImage: "arrow.clockwise") {
                        Task { await viewModel.refresh() }
                    }
                    .disabled(viewModel.isLoading)
                    Button("安全處理", systemImage: "checkmark.shield") {
                        viewModel.presentSafeActionPreview()
                    }
                    .disabled(viewModel.isLoading || viewModel.isPerformingSafeAction)
                    Button("復原上次安全處理", systemImage: "arrow.uturn.backward") {
                        Task { await viewModel.undoLastSafeAction() }
                    }
                    .disabled(!viewModel.canUndoSafeAction || viewModel.isPerformingSafeAction)
                    Divider()
                    Button("開啟 macOS Login Items", systemImage: "person.crop.circle") {
                        viewModel.openLoginItems()
                    }
                    Divider()
                    Button("設定…", systemImage: "gearshape") {
                        openAppSettings()
                    }
                    Picker("外觀", selection: settings.appearanceModeBinding) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                    Button("工作階段紀錄", systemImage: "text.alignleft") {
                        viewModel.showingDebugLog = true
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
            }
        }
        .navigationTitle("Autoruns Lite")
        .task {
            // XCTest launches this app as TEST_HOST; skip the automatic scan
            // so tests can drive launchctl themselves.
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
                return
            }
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
        .confirmationDialog(
            disableTitle,
            isPresented: Binding(
                get: { viewModel.pendingDisableItem != nil },
                set: { if !$0 { viewModel.cancelDisable() } }
            ),
            titleVisibility: .visible
        ) {
            Button("停用") {
                Task { await viewModel.confirmDisable() }
            }
            Button("取消", role: .cancel) {
                viewModel.cancelDisable()
            }
        } message: {
            Text("這會阻止 launchd 自動啟動此項目。\n原始 plist 不會被刪除。")
        }
        .overlay {
            if viewModel.isPerformingSafeAction {
                ProgressView("正在安全處理…")
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("正在掃描啟動項目…")
            }
        }
    }

    private var disableTitle: String {
        if let item = viewModel.pendingDisableItem {
            return "停用 \(item.label)？"
        }
        return "停用此項目？"
    }

    private func openAppSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
