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
                    labeled("Command", failure.command)
                    labeled("Exit code", "\(failure.exitCode)")
                    labeled("stderr", failure.stderr.isEmpty ? "(empty)" : failure.stderr)
                    if !failure.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        labeled("stdout", failure.stdout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("複製錯誤", action: onCopy)
                Spacer()
                Button("關閉") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 280)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
