import SwiftUI
import AppKit

struct StartupDetailView: View {
    @ObservedObject var viewModel: StartupViewModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var researchSession: ServiceResearchSession
    @Environment(\.openWindow) private var openWindow

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

                groupedCard {
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
                        title: "未載入",
                        count: viewModel.unloadedCount,
                        systemImage: LoadStatus.unloaded.systemImage,
                        color: LoadStatus.unloaded.color,
                        filter: nil
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
                }

                Text("處理建議")
                    .font(.headline)

                groupedCard {
                    dashboardRow(
                        title: "可安全處理",
                        count: viewModel.safeActionCount,
                        systemImage: ItemRecommendation.safeAction.systemImage,
                        color: ItemRecommendation.safeAction.color,
                        filter: .safeAction
                    )
                    dashboardRow(
                        title: "建議檢查",
                        count: viewModel.reviewRequiredCount,
                        systemImage: ItemRecommendation.reviewRequired.systemImage,
                        color: ItemRecommendation.reviewRequired.color,
                        filter: .reviewRequired
                    )
                }

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
                .textSelection(.disabled)
                .disabled(viewModel.isLoading || viewModel.isPerformingSafeAction)

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .textSelection(.enabled)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func groupedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
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
        .textSelection(.disabled)
        .disabled(filter == nil)
        .accessibilityLabel("\(title) \(count)")
    }

    private func itemDetail(_ item: StartupItem) -> some View {
        let recommendation = viewModel.recommendation(for: item)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(item)

                statusSection(item)
                recommendationSection(recommendation, item: item)

                Divider()

                if item.isSystemProtected {
                    Label("系統項目預設不允許修改，以避免影響 macOS。", systemImage: "lock.fill")
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
                    Text("停用：阻止 launchd 自動載入此項目。原始 plist 不會被刪除。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                actionButtons(item)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
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
                        .foregroundStyle(.secondary)
                } else {
                    Text(item.label)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    StatusBadge(status: item.loadStatus)
                    TypeBadge(type: item.type)
                }
                .textSelection(.disabled)
            }
        }
    }

    private func statusSection(_ item: StartupItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("狀態")
                    .font(.headline)
                Button {
                    viewModel.showingStatusHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .textSelection(.disabled)
                .help("啟動項目狀態說明")
                .accessibilityLabel("狀態說明")
            }
            StatusBadge(status: item.loadStatus)

            Text("狀態說明")
                .font(.subheadline.weight(.semibold))
            Text(item.loadStatus.detailedDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recommendationSection(_ result: RecommendationResult, item: StartupItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("處理建議")
                .font(.headline)
            Label(result.recommendation.displayName, systemImage: result.recommendation.systemImage)
                .foregroundStyle(result.recommendation.color)
                .font(.body.weight(.semibold))

            Text("原因")
                .font(.subheadline.weight(.semibold))
            Text(result.reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !result.evidence.isEmpty {
                Text("判斷依據")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
                ForEach(result.evidence, id: \.self) { evidence in
                    Label(evidence, systemImage: "checkmark")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Button("查詢此服務") {
                startResearch()
            }
            .textSelection(.disabled)
            .help("在網路上搜尋此服務的用途、停用建議與相關討論。")

            notesSection(item)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func notesSection(_ item: StartupItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("備註")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 8)
            Text("查到這個服務的用途後，可以貼在這裡，下次打開仍會保留。")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: Binding(
                get: { viewModel.note(for: item) },
                set: { viewModel.setNote($0, for: item) }
            ))
                .font(.body)
                .frame(minHeight: 88, maxHeight: 160)
                .padding(4)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .accessibilityLabel("服務備註")
        }
    }

    private func infoGrid(_ item: StartupItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRow("類型", item.type.sourceDescription, systemImage: "square.stack")
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

            Menu {
                Button("複製 Label") {
                    viewModel.copyLabel(item)
                }
                Button("複製路徑") {
                    viewModel.copyPlistPath(item)
                }
                Button("在 Finder 顯示") {
                    viewModel.showInFinder(item)
                }
                Button("開啟 plist") {
                    viewModel.showingPlistViewer = true
                }
                Button("停用") {
                    viewModel.requestDisable(item)
                }
                .disabled(!viewModel.canDisable(item))
                if viewModel.canMoveToTrash(item) {
                    Divider()
                    Button("移到垃圾桶…") {
                        viewModel.requestMoveToTrash(item)
                    }
                }
            } label: {
                Text("更多…")
            }
        }
        .buttonStyle(.bordered)
        .textSelection(.disabled)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startResearch() {
        guard let item = viewModel.selectedItem else { return }
        viewModel.openServiceResearch(
            for: item,
            settings: settings,
            session: researchSession,
            openEmbedded: { openWindow(id: "service-research") }
        )
    }
}
