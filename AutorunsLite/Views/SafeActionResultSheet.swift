import SwiftUI

struct SafeActionResultSheet: View {
    let result: SafeActionBatchResult
    let isUndo: Bool
    let onDone: () -> Void
    let onUndo: () -> Void
    @State private var showingDetails = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isUndo ? L10n.text("safe_action.undo_title") : result.title)
                .font(.title2.weight(.semibold))

            HStack(spacing: 16) {
                summary(L10n.text("safe_action.succeeded"), result.succeeded, .green)
                summary(L10n.text("safe_action.failed"), result.failed, .red)
                summary(L10n.text("safe_action.skipped"), result.skipped, .secondary)
            }

            if showingDetails {
                List(result.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: symbol(for: item.outcome))
                                .foregroundStyle(color(for: item.outcome))
                            Text(item.label)
                                .font(.body.weight(.semibold))
                        }
                        if !item.detail.isEmpty {
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 180)
            }

            HStack {
                Button(L10n.text("common.done"), action: onDone)
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Button(showingDetails ? L10n.text("safe_action.hide_details") : L10n.text("safe_action.show_details")) {
                    showingDetails.toggle()
                }
                if !isUndo, result.snapshot != nil {
                    Button(L10n.text("safe_action.undo"), action: onUndo)
                }
            }
            .textSelection(.disabled)
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: showingDetails ? 480 : 240)
        .textSelection(.enabled)
    }

    private func summary(_ title: String, _ count: Int, _ color: Color) -> some View {
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

    private func symbol(for outcome: SafeActionItemOutcome) -> String {
        switch outcome {
        case .succeeded:
            return "checkmark"
        case .failed:
            return "xmark"
        case .skipped:
            return "minus"
        }
    }

    private func color(for outcome: SafeActionItemOutcome) -> Color {
        switch outcome {
        case .succeeded:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .secondary
        }
    }
}
