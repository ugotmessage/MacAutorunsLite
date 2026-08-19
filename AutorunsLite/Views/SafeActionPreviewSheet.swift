import SwiftUI

struct SafeActionPreviewSheet: View {
    let dryRun: SafeActionDryRun
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("safe_action.preview_title"))
                .font(.title2.weight(.semibold))

            HStack(spacing: 16) {
                countChip(L10n.text("filter.safe_action"), dryRun.safeCount, LoadStatus.orphaned.color)
                countChip(L10n.text("safety.review_required"), dryRun.reviewCount, .orange)
                countChip(L10n.text("safety.protected"), dryRun.protectedCount, .secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("safe_action.will_do"))
                    .font(.headline)
                labeled(L10n.text("safe_action.will_stop_orphaned"), systemImage: "checkmark")
                labeled(L10n.text("safe_action.will_disable_autoload"), systemImage: "checkmark")
                labeled(L10n.text("safe_action.will_keep_plist"), systemImage: "checkmark")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("safe_action.will_not"))
                    .font(.headline)
                labeled(L10n.text("safe_action.will_not_delete_files"), systemImage: "xmark")
                labeled(L10n.text("safe_action.will_not_modify_system"), systemImage: "xmark")
                labeled(L10n.text("safe_action.will_not_use_sudo"), systemImage: "xmark")
            }

            Text(L10n.text("safe_action.pending_items"))
                .font(.headline)

            List(dryRun.safeItems) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.body.weight(.semibold))
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.abbreviatedPlistPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 160)

            HStack {
                Button(L10n.text("common.cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(dryRun.safeCount == 0 ? L10n.text("safe_action.confirm_none") : L10n.text("safe_action.confirm_count", ["count": "\(dryRun.safeCount)"])) {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(dryRun.safeCount == 0)
            }
            .textSelection(.disabled)
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 520)
        .textSelection(.enabled)
    }

    private func countChip(_ title: String, _ count: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeled(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}
