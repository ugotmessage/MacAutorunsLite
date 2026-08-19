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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                Label(L10n.text("detail.summary_title"), systemImage: "list.bullet.rectangle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                groupedCard {
                    dashboardRow(
                        title: L10n.text("detail.total"),
                        count: viewModel.totalCount,
                        systemImage: "square.stack.3d.up",
                        color: Color.primary,
                        filter: .all
                    )
                    dashboardRow(
                        title: L10n.text("status.loaded.name"),
                        count: viewModel.loadedCount,
                        systemImage: LoadStatus.loaded.systemImage,
                        color: LoadStatus.loaded.color,
                        filter: .loaded
                    )
                    dashboardRow(
                        title: L10n.text("detail.unloaded"),
                        count: viewModel.unloadedCount,
                        systemImage: LoadStatus.unloaded.systemImage,
                        color: LoadStatus.unloaded.color,
                        filter: nil
                    )
                    dashboardRow(
                        title: L10n.text("status.disabled.name"),
                        count: viewModel.disabledCount,
                        systemImage: LoadStatus.disabled.systemImage,
                        color: LoadStatus.disabled.color,
                        filter: .disabled
                    )
                    dashboardRow(
                        title: L10n.text("status.orphaned.name"),
                        count: viewModel.orphanedCount,
                        systemImage: LoadStatus.orphaned.systemImage,
                        color: LoadStatus.orphaned.color,
                        filter: .orphaned
                    )
                    dashboardRow(
                        title: L10n.text("detail.modern_sources"),
                        count: viewModel.modernSourceCount,
                        systemImage: "sparkles",
                        color: Color.accentColor,
                        filter: nil
                    )
                }

                Text(L10n.text("detail.recommendations"))
                    .font(.headline)

                groupedCard {
                    dashboardRow(
                        title: L10n.text("filter.safe_action"),
                        count: viewModel.safeActionCount,
                        systemImage: ItemRecommendation.safeAction.systemImage,
                        color: ItemRecommendation.safeAction.color,
                        filter: .safeAction
                    )
                    dashboardRow(
                        title: L10n.text("filter.review_required"),
                        count: viewModel.reviewRequiredCount,
                        systemImage: ItemRecommendation.reviewRequired.systemImage,
                        color: ItemRecommendation.reviewRequired.color,
                        filter: .reviewRequired
                    )
                }

                Text(L10n.text("detail.last_scan", ["time": viewModel.lastScanDescription(at: context.date)]))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !viewModel.includeSystemItems {
                    if let notice = viewModel.systemLoadNotice {
                        Text(notice)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button {
                        Task { await viewModel.loadSystemStartupItems() }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(L10n.text("detail.load_system_items"), systemImage: "externaldrive.badge.plus")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(L10n.text("detail.load_system_items_help"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
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
                } else if let warning = viewModel.modernSourceWarning {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    viewModel.presentSafeActionPreview()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(L10n.text("app.toolbar.safe_action"), systemImage: "checkmark.shield")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(
                            viewModel.safeActionCount > 0
                                ? L10n.text("app.toolbar.safe_action_help_available", ["count": "\(viewModel.safeActionCount)"])
                                : L10n.text("detail.safe_action_none")
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
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    Label(L10n.text("detail.system_protected_notice"), systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                infoGrid(item)
                ownershipSection(item)
                relatedSection(item)

                if item.type.supportsLaunchctl {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(L10n.text("detail.stop_vs_disable_title"), systemImage: "info.circle")
                            .font(.headline)
                        Text(L10n.text("detail.stop_vs_disable_stop"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(L10n.text("detail.stop_vs_disable_disable"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(L10n.text("recommendation.reason.modern_source"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                Text(L10n.text("detail.status"))
                    .font(.headline)
                Button {
                    viewModel.showingStatusHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .textSelection(.disabled)
                .help(L10n.text("detail.status_help"))
                .accessibilityLabel(L10n.text("detail.status_help_accessibility"))
            }
            StatusBadge(status: item.loadStatus)

            Text(L10n.text("detail.status_explanation"))
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
            Text(L10n.text("detail.recommendations"))
                .font(.headline)
            Label(result.recommendation.displayName, systemImage: result.recommendation.systemImage)
                .foregroundStyle(result.recommendation.color)
                .font(.body.weight(.semibold))

            Text(L10n.text("detail.reason"))
                .font(.subheadline.weight(.semibold))
            Text(result.reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !result.evidence.isEmpty {
                Text(L10n.text("detail.evidence"))
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
                ForEach(result.evidence, id: \.self) { evidence in
                    Label(evidence, systemImage: "checkmark")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Button(L10n.text("detail.research_this_service")) {
                startResearch()
            }
            .textSelection(.disabled)
            .help(L10n.text("detail.research_this_service_help"))

            notesSection(item)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func notesSection(_ item: StartupItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("detail.notes"))
                .font(.subheadline.weight(.semibold))
                .padding(.top, 8)
            Text(L10n.text("detail.notes_hint"))
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
                .accessibilityLabel(L10n.text("detail.notes_accessibility"))
        }
    }

    private func infoGrid(_ item: StartupItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRow(L10n.text("detail.field.type"), item.type.sourceDescription, systemImage: "square.stack")
            detailRow(L10n.text("detail.field.executable"), item.executablePath ?? L10n.text("common.missing"), systemImage: "terminal")
            if !item.plistPath.isEmpty {
                detailRow(L10n.text("detail.field.plist"), item.plistPath, systemImage: "doc")
            } else {
                detailRow(L10n.text("detail.path"), item.resolvedSourcePath, systemImage: "doc")
            }
            if item.type.supportsLaunchctl {
                detailRow(L10n.text("detail.field.run_at_load"), item.runAtLoad ? L10n.text("common.yes") : L10n.text("common.no"), systemImage: "clock")
                detailRow(L10n.text("detail.field.keep_alive"), keepAliveDisplay(item.keepAliveDescription), systemImage: "arrow.triangle.2.circlepath")
                detailRow(L10n.text("detail.field.arguments"), item.arguments.isEmpty ? L10n.text("common.none") : item.arguments.joined(separator: "\n"), systemImage: "list.bullet")
            }
            if let workingDirectory = item.workingDirectory {
                detailRow(L10n.text("detail.field.working_directory"), workingDirectory, systemImage: "folder")
            }
            if let appBundleIdentifier = item.appBundleIdentifier {
                detailRow(L10n.text("detail.field.bundle_id"), appBundleIdentifier, systemImage: "app.badge")
            }
        }
    }

    private func ownershipSection(_ item: StartupItem) -> some View {
        let hasOwnership = item.appBundlePath != nil
            || item.parentDisplayName != nil
            || item.teamIdentifier != nil
            || !item.associatedBundleIDs.isEmpty
        return Group {
            if hasOwnership {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("detail.ownership"))
                        .font(.headline)
                    if let name = item.parentDisplayName ?? item.appDisplayName {
                        detailRow(L10n.text("detail.field.name"), name, systemImage: "app")
                    }
                    if let parentID = item.parentBundleIdentifier {
                        detailRow(L10n.text("detail.field.parent_bundle_id"), parentID, systemImage: "link")
                    }
                    if let appPath = item.appBundlePath {
                        detailRow(L10n.text("detail.field.app_path"), appPath, systemImage: "folder")
                    }
                    if let team = item.teamIdentifier {
                        detailRow(L10n.text("detail.field.team_id"), team, systemImage: "person.badge.key")
                    }
                    if let developer = item.developerName {
                        detailRow(L10n.text("detail.field.developer"), developer, systemImage: "signature")
                    }
                    if !item.associatedBundleIDs.isEmpty {
                        detailRow(
                            L10n.text("detail.field.associated_bundle_ids"),
                            item.associatedBundleIDs.joined(separator: "\n"),
                            systemImage: "square.stack.3d.up"
                        )
                    }
                }
            }
        }
    }

    private func relatedSection(_ item: StartupItem) -> some View {
        let related = viewModel.relatedItems(for: item)
        return Group {
            if !related.isEmpty || !item.relatedHelpers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("detail.related_items"))
                        .font(.headline)
                    ForEach(related) { other in
                        Button {
                            viewModel.selectedItemID = other.id
                        } label: {
                            Label("\(other.displayName)（\(other.type.displayName)）", systemImage: "arrow.right.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .textSelection(.disabled)
                    }
                    ForEach(item.relatedHelpers) { helper in
                        Label("\(helper.name) · \(helper.kindDisplayName)", systemImage: "puzzlepiece.extension")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .help(helper.path)
                    }
                }
            }
        }
    }

    private func actionButtons(_ item: StartupItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.type.supportsLaunchctl {
                HStack {
                    Button(L10n.text("common.stop")) {
                        Task { await viewModel.stop(item) }
                    }
                    .disabled(!viewModel.canStop(item))

                    Button(L10n.text("common.start")) {
                        Task { await viewModel.start(item) }
                    }
                    .disabled(!viewModel.canStart(item))
                }

                HStack {
                    Button(L10n.text("common.disable")) {
                        viewModel.requestDisable(item)
                    }
                    .disabled(!viewModel.canDisable(item))

                    Button(L10n.text("common.enable")) {
                        Task { await viewModel.enable(item) }
                    }
                    .disabled(!viewModel.canEnable(item))
                }
            } else {
                Button(L10n.text("detail.manage_in_system_settings")) {
                    viewModel.openLoginItems()
                }
            }

            Menu {
                Button(L10n.text("detail.copy_label")) {
                    viewModel.copyLabel(item)
                }
                Button(L10n.text("detail.copy_path")) {
                    viewModel.copyPlistPath(item)
                }
                Button(L10n.text("detail.show_in_finder")) {
                    viewModel.showInFinder(item)
                }
                if !item.plistPath.isEmpty, FileManager.default.fileExists(atPath: item.plistPath) {
                    Button(L10n.text("detail.open_plist")) {
                        viewModel.showingPlistViewer = true
                    }
                }
                if item.type.supportsLaunchctl {
                    Button(L10n.text("common.disable")) {
                        viewModel.requestDisable(item)
                    }
                    .disabled(!viewModel.canDisable(item))
                } else {
                    Button(L10n.text("detail.manage_in_system_settings")) {
                        viewModel.openLoginItems()
                    }
                }
                if viewModel.canMoveToTrash(item) {
                    Divider()
                    Button(L10n.text("list.move_to_trash")) {
                        viewModel.requestMoveToTrash(item)
                    }
                }
            } label: {
                Text(L10n.text("common.more_ellipsis"))
            }
        }
        .buttonStyle(.bordered)
        .textSelection(.disabled)
    }

    private func keepAliveDisplay(_ value: String?) -> String {
        switch value {
        case "Yes":
            return L10n.text("common.yes")
        case "No", nil:
            return L10n.text("common.no")
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
                .font(title == L10n.text("detail.field.plist") ? .body.monospaced() : .body)
                .foregroundStyle(title == L10n.text("detail.field.plist") ? .secondary : .primary)
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
