import SwiftUI
import AppKit

struct StartupDetailView: View {
    @ObservedObject var viewModel: StartupViewModel

    var body: some View {
        Group {
            if let item = viewModel.selectedItem {
                itemDetail(item)
            } else {
                summaryDashboard
            }
        }
    }

    private var summaryDashboard: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 20) {
                Label("啟動項目摘要", systemImage: "list.bullet.rectangle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 0) {
                    dashboardRow(
                        title: "總計",
                        count: viewModel.totalCount,
                        systemImage: "square.stack.3d.up",
                        color: Color.primary,
                        filter: .all
                    )
                    dashboardRow(
                        title: "已載入",
                        count: viewModel.loadedCount,
                        systemImage: LoadStatus.loaded.systemImage,
                        color: LoadStatus.loaded.color,
                        filter: .loaded
                    )
                    dashboardRow(
                        title: "已停用",
                        count: viewModel.disabledCount,
                        systemImage: LoadStatus.disabled.systemImage,
                        color: LoadStatus.disabled.color,
                        filter: .disabled
                    )
                    dashboardRow(
                        title: "殘留",
                        count: viewModel.orphanedCount,
                        systemImage: LoadStatus.orphaned.systemImage,
                        color: LoadStatus.orphaned.color,
                        filter: .orphaned
                    )
                    dashboardRow(
                        title: "未載入",
                        count: viewModel.unloadedCount,
                        systemImage: LoadStatus.unloaded.systemImage,
                        color: LoadStatus.unloaded.color,
                        filter: nil
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )

                Text("上次掃描：\(viewModel.lastScanDescription(at: context.date))")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.presentSafeActionPreview()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("安全處理", systemImage: "checkmark.shield")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(
                            viewModel.safeActionCount > 0
                                ? "\(viewModel.safeActionCount) 個項目可安全處理"
                                : "目前沒有可自動處理的低風險殘留項目"
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading || viewModel.isPerformingSafeAction)

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func dashboardRow(
        title: String,
        count: Int,
        systemImage: String,
        color: Color,
        filter: StartupFilter?
    ) -> some View {
        Button {
            if let filter {
                viewModel.applyFilter(filter)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count)")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(color)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(filter == nil)
        .accessibilityLabel("\(title) \(count)")
    }

    private func itemDetail(_ item: StartupItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(item)

                if item.isSystemProtected {
                    Label("系統項目預設不允許修改，以避免影響 macOS。", systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if item.loadStatus.isOrphaned {
                    Label {
                        Text("此啟動項目的 plist 仍存在，但執行檔已不存在，可能是已移除 App 的殘留項目。")
                    } icon: {
                        Image(systemName: item.loadStatus.systemImage)
                            .foregroundStyle(item.loadStatus.color)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                infoGrid(item)

                VStack(alignment: .leading, spacing: 6) {
                    Label("停止與停用的差異", systemImage: "info.circle")
                        .font(.headline)
                    Text("停止：僅停止目前執行中的服務，本次或下次可能再次啟動。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("停用：阻止 launchd 自動載入此項目。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                actionButtons(item)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func header(_ item: StartupItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.loadStatus.systemImage)
                .font(.system(size: 28))
                .foregroundStyle(item.loadStatus.color)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.title2.weight(.semibold))
                if let secondary = item.secondaryIdentifier {
                    Text(secondary)
                        .font(.callout)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                } else {
                    Text(item.label)
                        .font(.callout)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    StatusBadge(status: item.loadStatus)
                    TypeBadge(type: item.type)
                }
            }
        }
    }

    private func infoGrid(_ item: StartupItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRow("Label", item.label, systemImage: "tag")
            labeledType(item)
            statusRow(item.loadStatus)
            detailRow("執行檔", item.executablePath ?? "（不存在）", systemImage: "terminal")
            detailRow("plist", item.plistPath, systemImage: "doc")
            detailRow("登入/載入時執行", item.runAtLoad ? "是" : "否", systemImage: "clock")
            detailRow("持續執行", keepAliveDisplay(item.keepAliveDescription), systemImage: "arrow.triangle.2.circlepath")
            detailRow("參數", item.arguments.isEmpty ? "（無）" : item.arguments.joined(separator: "\n"), systemImage: "list.bullet")
            if let workingDirectory = item.workingDirectory {
                detailRow("WorkingDirectory", workingDirectory, systemImage: "folder")
            }
            if let appBundleIdentifier = item.appBundleIdentifier {
                detailRow("Bundle ID", appBundleIdentifier, systemImage: "app.badge")
            }
        }
    }

    private func labeledType(_ item: StartupItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("類型", systemImage: "square.stack")
                .font(.caption)
                .foregroundStyle(.secondary)
            TypeBadge(type: item.type)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButtons(_ item: StartupItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("停止") {
                    Task { await viewModel.stop(item) }
                }
                .disabled(!viewModel.canStop(item))

                Button("啟動") {
                    Task { await viewModel.start(item) }
                }
                .disabled(!viewModel.canStart(item))
            }

            HStack {
                Button("停用") {
                    viewModel.requestDisable(item)
                }
                .disabled(!viewModel.canDisable(item))

                Button("啟用") {
                    Task { await viewModel.enable(item) }
                }
                .disabled(!viewModel.canEnable(item))
            }

            HStack {
                Button("在 Finder 顯示") {
                    viewModel.showInFinder(item)
                }
                Button("開啟 plist") {
                    viewModel.showingPlistViewer = true
                }
            }
        }
        .buttonStyle(.bordered)
    }

    private func statusRow(_ status: LoadStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("狀態", systemImage: status.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            StatusBadge(status: status)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func keepAliveDisplay(_ value: String?) -> String {
        switch value {
        case "Yes":
            return "是"
        case "No", nil:
            return "否"
        case let value?:
            return value
        }
    }

    private func detailRow(_ title: String, _ value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(title == "plist" ? .body.monospaced() : .body)
                .foregroundStyle(title == "plist" ? .secondary : .primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
