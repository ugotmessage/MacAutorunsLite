import SwiftUI

struct MoveToTrashSheet: View {
    let item: StartupItem
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("將啟動設定移到垃圾桶？")
                .font(.title2.weight(.semibold))

            Text(item.label)
                .font(.body.monospaced().weight(.semibold))

            Text("此項目的執行檔已不存在，MacAutorunsLite 判定它可能是舊 App 的殘留啟動設定。")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("將執行：")
                    .font(.headline)
                Label("若仍載入則先停止", systemImage: "checkmark")
                Label("停用 launchd 項目", systemImage: "checkmark")
                Label("將 plist 移到垃圾桶", systemImage: "checkmark")
            }
            .font(.callout)

            VStack(alignment: .leading, spacing: 6) {
                Text("不會：")
                    .font(.headline)
                Label("刪除其他 App 檔案", systemImage: "xmark")
                Label("修改 Apple 系統服務", systemImage: "xmark")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Text("此操作可從 macOS 垃圾桶手動復原。")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("移到垃圾桶", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
            .textSelection(.disabled)
        }
        .padding(20)
        .frame(minWidth: 480)
        .textSelection(.enabled)
    }
}
