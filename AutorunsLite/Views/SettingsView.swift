import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section(L10n.text("settings.language_section")) {
                Picker(L10n.text("settings.language_mode"), selection: settings.appLanguageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .pickerStyle(.radioGroup)
                // `L10n` 來自 singleton，不一定會觸發 Picker 內建選項視圖重新計算。
                // 強制重建可確保切換語言後選項文字也一起更新。
                .id(settings.appLanguageRawValue)
                .textSelection(.disabled)

                Text(L10n.text("settings.language_mode_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.text("settings.appearance_section")) {
                Picker(L10n.text("settings.appearance_mode"), selection: settings.appearanceModeBinding) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .textSelection(.disabled)
            }

            Section(L10n.text("settings.research_section")) {
                Picker(L10n.text("settings.browser_mode"), selection: settings.researchBrowserModeBinding) {
                    ForEach(ResearchBrowserMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .textSelection(.disabled)

                Text(L10n.text("settings.browser_mode_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.text("settings.search_section")) {
                editableField(
                    title: L10n.text("settings.search_template"),
                    prompt: ResearchSearchDefaults.template,
                    text: settings.researchQueryTemplateBinding
                )
                Text(L10n.text("settings.search_template_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if settings.templateMissingLabelPlaceholder {
                    Text(L10n.text("settings.search_template_missing_label"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                keywordField(
                    title: L10n.text("settings.keyword_overview"),
                    prompt: ResearchSearchDefaults.overviewKeyword,
                    text: settings.researchOverviewKeywordBinding
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("settings.search_preview"))
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

                Button(L10n.text("settings.restore_search_defaults")) {
                    confirmingReset = true
                }
                .textSelection(.disabled)
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("settings.keywords_section"))
                    Text(L10n.text("settings.keywords_help"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .textSelection(.enabled)
        .padding()
        .frame(minWidth: 520, minHeight: 360, alignment: .topLeading)
        .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        .confirmationDialog(
            L10n.text("settings.restore_confirm_title"),
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button(L10n.text("settings.restore_confirm_action")) {
                settings.restoreResearchSearchDefaults()
            }
            Button(L10n.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("settings.restore_confirm_message"))
        }
    }

    private func editableField(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
            TextField("", text: text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .labelsHidden()
                .accessibilityLabel(title)
        }
        .padding(.vertical, 2)
    }

    private func keywordField(title: String, prompt: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField("", text: text, prompt: Text(prompt))
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .labelsHidden()
                .accessibilityLabel(title)
                .accessibilityHint(L10n.text("settings.keyword_accessibility_hint"))
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
