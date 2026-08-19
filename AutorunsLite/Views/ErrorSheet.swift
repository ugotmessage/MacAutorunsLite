import SwiftUI

struct ErrorSheet: View {
    let failure: OperationFailure
    let onCopy: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(failure.title)
                .font(.headline)

            GroupBox("launchctl") {
                VStack(alignment: .leading, spacing: 8) {
                    labeled(L10n.text("error.command"), failure.command)
                    labeled(L10n.text("error.exit_code"), "\(failure.exitCode)")
                    labeled(L10n.text("error.stderr"), failure.stderr.isEmpty ? L10n.text("common.empty_technical") : failure.stderr)
                    if !failure.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        labeled(L10n.text("error.stdout"), failure.stdout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(L10n.text("error.copy"), action: onCopy)
                Spacer()
                Button(L10n.text("common.close")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .textSelection(.disabled)
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 280)
        .textSelection(.enabled)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}
