import SwiftUI

struct SafeActionResultSheet: View {
    let result: SafeActionBatchResult
    let isUndo: Bool
    let onDone: () -> Void
    let onUndo: () -> Void
    @State private var showingDetails = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isUndo ? "復原完成" : result.title)
                .font(.title2.weight(.semibold))

            HStack(spacing: 16) {
                summary("成功", result.succeeded, .green)
                summary("失敗", result.failed, .red)
                summary("跳過", result.skipped, .secondary)
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
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 180)
            }

            HStack {
                Button("完成", action: onDone)
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Button(showingDetails ? "隱藏詳細結果" : "查看詳細結果") {
                    showingDetails.toggle()
                }
                if !isUndo, result.snapshot != nil {
                    Button("復原", action: onUndo)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: showingDetails ? 480 : 240)
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
