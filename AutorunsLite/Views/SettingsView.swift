import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section("外觀") {
                Picker("外觀模式", selection: settings.appearanceModeBinding) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .textSelection(.disabled)
            }

            Section("服務研究") {
                Picker("網頁開啟方式", selection: settings.researchBrowserModeBinding) {
                    ForEach(ResearchBrowserMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .textSelection(.disabled)

                Text("預設會用系統瀏覽器開啟搜尋結果。若改為內建瀏覽器，會在 MacAutorunsLite 視窗中顯示網頁。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("搜尋設定") {
                editableField(
                    title: "搜尋模板",
                    prompt: "\"{label}\" {type} {keyword}",
                    text: settings.researchQueryTemplateBinding
                )
                Text("可用變數：{label} 服務 Label、{type} LaunchAgent / LaunchDaemon、{keyword} 目前研究關鍵字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if settings.templateMissingLabelPlaceholder {
                    Text("建議搜尋模板保留 {label}，否則可能無法準確找到對應服務。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("搜尋關鍵字") {
                editableField(
                    title: "這是什麼",
                    prompt: "macOS",
                    text: settings.researchOverviewKeywordBinding
                )
                editableField(
                    title: "能停用嗎",
                    prompt: "safe to disable",
                    text: settings.researchDisableKeywordBinding
                )
                editableField(
                    title: "能刪除嗎",
                    prompt: "safe to remove",
                    text: settings.researchRemoveKeywordBinding
                )
                editableField(
                    title: "網友討論",
                    prompt: "reddit",
                    text: settings.researchCommunityKeywordBinding
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("搜尋預覽")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(settings.searchPreviewQuery)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }

                Button("恢復預設搜尋設定") {
                    confirmingReset = true
                }
                .textSelection(.disabled)
            }
        }
        .formStyle(.grouped)
        .textSelection(.enabled)
        .padding()
        .frame(minWidth: 560, minHeight: 640, alignment: .topLeading)
        .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        .confirmationDialog(
            "恢復預設搜尋設定？",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("恢復預設值") {
                settings.restoreResearchSearchDefaults()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這會將搜尋模板與研究關鍵字恢復為預設值。")
        }
    }

    private func editableField(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
            TextField(title, text: text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .accessibilityLabel(title)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
