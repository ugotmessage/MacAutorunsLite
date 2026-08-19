import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
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

    @AppStorage("researchDisableKeyword")
    var researchDisableKeyword: String = ResearchSearchDefaults.disableKeyword {
        didSet { objectWillChange.send() }
    }

    @AppStorage("researchRemoveKeyword")
    var researchRemoveKeyword: String = ResearchSearchDefaults.removeKeyword {
        didSet { objectWillChange.send() }
    }

    @AppStorage("researchCommunityKeyword")
    var researchCommunityKeyword: String = ResearchSearchDefaults.communityKeyword {
        didSet { objectWillChange.send() }
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

    var researchDisableKeywordBinding: Binding<String> {
        Binding(get: { self.researchDisableKeyword }, set: { self.researchDisableKeyword = $0 })
    }

    var researchRemoveKeywordBinding: Binding<String> {
        Binding(get: { self.researchRemoveKeyword }, set: { self.researchRemoveKeyword = $0 })
    }

    var researchCommunityKeywordBinding: Binding<String> {
        Binding(get: { self.researchCommunityKeyword }, set: { self.researchCommunityKeyword = $0 })
    }

    var templateMissingLabelPlaceholder: Bool {
        !researchQueryTemplate.contains("{label}")
    }

    var searchPreviewQuery: String {
        ServiceResearchQueryBuilder().build(
            label: ResearchSearchDefaults.previewLabel,
            typeKeyword: ResearchSearchDefaults.previewType,
            keyword: researchRemoveKeyword,
            template: researchQueryTemplate
        ).query
    }

    func restoreResearchSearchDefaults() {
        researchQueryTemplate = ResearchSearchDefaults.template
        researchOverviewKeyword = ResearchSearchDefaults.overviewKeyword
        researchDisableKeyword = ResearchSearchDefaults.disableKeyword
        researchRemoveKeyword = ResearchSearchDefaults.removeKeyword
        researchCommunityKeyword = ResearchSearchDefaults.communityKeyword
    }
}
