import SwiftUI

struct MoveToTrashSheet: View {
    let item: StartupItem
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("trash.title"))
                .font(.title2.weight(.semibold))

            Text(item.label)
                .font(.body.monospaced().weight(.semibold))

            Text(L10n.text("trash.intro"))
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("safe_action.will_do"))
                    .font(.headline)
                Label(L10n.text("trash.will_stop_if_loaded"), systemImage: "checkmark")
                Label(L10n.text("trash.will_disable_launchd"), systemImage: "checkmark")
                Label(L10n.text("trash.will_move_plist"), systemImage: "checkmark")
            }
            .font(.callout)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("safe_action.will_not"))
                    .font(.headline)
                Label(L10n.text("trash.will_not_delete_other_files"), systemImage: "xmark")
                Label(L10n.text("trash.will_not_modify_apple"), systemImage: "xmark")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Text(L10n.text("trash.reversible_note"))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button(L10n.text("common.cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.text("trash.confirm"), action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
            .textSelection(.disabled)
        }
        .padding(20)
        .frame(minWidth: 480)
        .textSelection(.enabled)
    }
}
