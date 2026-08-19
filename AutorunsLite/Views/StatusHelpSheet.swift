import SwiftUI

struct StatusHelpSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("啟動項目狀態說明")
                    .font(.title2.weight(.semibold))

                Text("Mac 的自動啟動由 launchd 管理。")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("plist")
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.secondary)
                    Text("launchd 載入設定")
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.secondary)
                    Text("等待啟動條件")
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.secondary)
                    Text("執行程式")
                }
                .font(.callout)

                Group {
                    Text("已載入不代表程式一定正在執行。")
                    Text("未載入也不代表此項目無用。")
                    Text("MacAutorunsLite 會另外提供「處理建議」，協助你判斷是否需要停用或清理。")
                }
                .font(.callout)

                Divider()

                Text("什麼是 LaunchAgent？")
                    .font(.headline)
                Text("LaunchAgent 通常是在使用者登入後，由 launchd 管理的背景服務。它被載入後，不一定會立刻佔用 CPU 或記憶體。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("什麼是 LaunchDaemon？")
                    .font(.headline)
                Text("LaunchDaemon 是系統層級背景服務，通常不依賴某個使用者登入。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()

                ForEach(statusCases, id: \.displayName) { status in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.displayName)
                            .font(.headline)
                        Text(status.shortDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(minWidth: 460, minHeight: 520)
    }

    private var statusCases: [LoadStatus] {
        [.loaded, .unloaded, .disabled, .orphaned, .error(""), .unknown]
    }
}
