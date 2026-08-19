import SwiftUI
import AppKit

struct StartupListView: View {
    @ObservedObject var viewModel: StartupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FilterBar(selectedFilter: $viewModel.selectedFilter)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            List(selection: $viewModel.selectedItemID) {
                ForEach(viewModel.visibleStatusGroups) { group in
                    Section {
                        if viewModel.isGroupExpanded(group.kind) {
                            ForEach(group.items) { item in
                                StartupItemRow(item: item, notePreview: viewModel.notePreview(for: item))
                                    .tag(item.id)
                                    .contextMenu { itemContextMenu(item) }
                            }
                        }
                    } header: {
                        groupHeader(group)
                    }
                }
            }
            .listStyle(.inset)
            .id(viewModel.selectedFilter)
        }
    }

    private func groupHeader(_ group: StatusGroup) -> some View {
        let status = group.kind.representativeStatus
        let expanded = viewModel.isGroupExpanded(group.kind)
        return Button {
            viewModel.setGroupExpanded(group.kind, expanded: !expanded)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Image(systemName: status.systemImage)
                    .foregroundStyle(status.color)
                    .frame(width: 16)
                Text("\(status.displayName) (\(group.items.count))")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .textSelection(.disabled)
        .accessibilityLabel("\(status.displayName)，\(group.items.count) 個項目")
        .accessibilityAddTraits(.isHeader)
        .help(status.shortDescription)
    }

    @ViewBuilder
    private func itemContextMenu(_ item: StartupItem) -> some View {
        Button("啟動") {
            Task { await viewModel.start(item) }
        }
        .disabled(!viewModel.canStart(item))

        Button("停止") {
            Task { await viewModel.stop(item) }
        }
        .disabled(!viewModel.canStop(item))

        Button("啟用") {
            Task { await viewModel.enable(item) }
        }
        .disabled(!viewModel.canEnable(item))

        Button("停用") {
            viewModel.requestDisable(item)
        }
        .disabled(!viewModel.canDisable(item))

        Divider()

        Button("在 Finder 顯示") {
            viewModel.showInFinder(item)
        }
        Button("開啟 plist") {
            viewModel.selectedItemID = item.id
            viewModel.showingPlistViewer = true
        }

        Divider()

        Button("複製路徑") {
            viewModel.copyPlistPath(item)
        }
        Button("複製 Label") {
            viewModel.copyLabel(item)
        }
        Button("複製執行檔路徑") {
            viewModel.copyExecutablePath(item)
        }

        if viewModel.canMoveToTrash(item) {
            Divider()
            Button("移到垃圾桶…") {
                viewModel.requestMoveToTrash(item)
            }
        }
    }
}

struct StartupItemRow: View {
    let item: StartupItem
    var notePreview: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: item.loadStatus.systemImage)
                .foregroundStyle(item.loadStatus.color)
                .frame(width: 16, height: 16)
                .help(item.loadStatus.shortDescription)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let secondary = item.secondaryIdentifier {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let notePreview {
                    Label(notePreview, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 80, maxWidth: 280, alignment: .leading)
            .textSelection(.enabled)

            TypeBadge(type: item.type)

            Text(item.abbreviatedPlistPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(item.plistPath)
                .textSelection(.enabled)
                .frame(minWidth: 48, maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 36, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [item.displayName, item.loadStatus.displayName, item.type.displayName]
        if let secondary = item.secondaryIdentifier {
            parts.insert(secondary, at: 1)
        }
        parts.append(item.plistPath)
        if let notePreview {
            parts.append("備註：\(notePreview)")
        }
        return parts.joined(separator: "，")
    }
}

struct TypeBadge: View {
    let type: StartupItemType

    var body: some View {
        Text(type.displayName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .fixedSize()
            .textSelection(.disabled)
            .help(type.sourceDescription)
    }
}
