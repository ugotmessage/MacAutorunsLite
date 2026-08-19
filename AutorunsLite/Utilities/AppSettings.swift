import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("appLanguage")
    var appLanguageRawValue: String = AppLanguage.system.rawValue {
        didSet {
            AppLocalization.shared.setLanguage(appLanguage)
            objectWillChange.send()
        }
    }

    @AppStorage("appearanceMode")
    var appearanceModeRawValue: String = AppearanceMode.system.rawValue {
        didSet { objectWillChange.send() }
    }

    @AppStorage("researchBrowserModePreferred")
    var researchBrowserModeRawValue: String = ResearchBrowserMode.system.rawValue {
        didSet { objectWillChange.send() }
    }

    @AppStorage("researchQueryTemplate")
    var researchQueryTemplate: String = ResearchSearchDefaults.template {
        didSet { objectWillChange.send() }
    }

    @AppStorage("researchOverviewKeyword")
    var researchOverviewKeyword: String = ResearchSearchDefaults.overviewKeyword {
        didSet { objectWillChange.send() }
    }

    init() {
        AppLocalization.shared.setLanguage(appLanguage)
    }

    var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: appLanguageRawValue) ?? .system }
        set { appLanguageRawValue = newValue.rawValue }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRawValue) ?? .system }
        set { appearanceModeRawValue = newValue.rawValue }
    }

    var researchBrowserMode: ResearchBrowserMode {
        get { ResearchBrowserMode(rawValue: researchBrowserModeRawValue) ?? .system }
        set { researchBrowserModeRawValue = newValue.rawValue }
    }

    var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { self.appearanceMode },
            set: { self.appearanceMode = $0 }
        )
    }

    var appLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { self.appLanguage },
            set: { self.appLanguage = $0 }
        )
    }

    var researchBrowserModeBinding: Binding<ResearchBrowserMode> {
        Binding(
            get: { self.researchBrowserMode },
            set: { self.researchBrowserMode = $0 }
        )
    }

    var researchQueryTemplateBinding: Binding<String> {
        Binding(get: { self.researchQueryTemplate }, set: { self.researchQueryTemplate = $0 })
    }

    var researchOverviewKeywordBinding: Binding<String> {
        Binding(get: { self.researchOverviewKeyword }, set: { self.researchOverviewKeyword = $0 })
    }

    var templateMissingLabelPlaceholder: Bool {
        !researchQueryTemplate.contains("{label}")
    }

    var searchPreviewQuery: String {
        ServiceResearchQueryBuilder().build(
            label: ResearchSearchDefaults.previewLabel,
            typeKeyword: ResearchSearchDefaults.previewType,
            keyword: researchOverviewKeyword,
            template: researchQueryTemplate
        ).query
    }

    var resolvedLocale: Locale {
        AppLocalization.shared.locale(for: appLanguage)
    }

    func restoreResearchSearchDefaults() {
        researchQueryTemplate = ResearchSearchDefaults.template
        researchOverviewKeyword = ResearchSearchDefaults.overviewKeyword
    }
}
