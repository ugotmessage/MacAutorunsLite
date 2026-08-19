import SwiftUI

struct SafeActionPreviewSheet: View {
    let dryRun: SafeActionDryRun
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("安全處理建議")
                .font(.title2.weight(.semibold))

            HStack(spacing: 16) {
                countChip("可安全處理", dryRun.safeCount, LoadStatus.orphaned.color)
                countChip("需要人工確認", dryRun.reviewCount, .orange)
                countChip("已保護", dryRun.protectedCount, .secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("將執行：")
                    .font(.headline)
                labeled("停止殘留服務", systemImage: "checkmark")
                labeled("停用自動載入", systemImage: "checkmark")
                labeled("保留 plist", systemImage: "checkmark")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("不會：")
                    .font(.headline)
                labeled("刪除任何檔案", systemImage: "xmark")
                labeled("修改系統服務", systemImage: "xmark")
                labeled("使用 sudo", systemImage: "xmark")
            }

            Text("即將處理的項目")
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
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(dryRun.safeCount == 0 ? "沒有可處理項目" : "安全處理 \(dryRun.safeCount) 個項目") {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(dryRun.safeCount == 0)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 520)
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
