import XCTest
@testable import AutorunsLite

final class ServiceResearchQueryBuilderTests: XCTestCase {
    private let builder = ServiceResearchQueryBuilder()

    func testDefaultRemoveQueryForLaunchDaemon() {
        let result = builder.build(
            label: "com.adobe.acc.installer.v2",
            typeKeyword: "LaunchDaemon",
            keyword: "safe to remove",
            template: ResearchSearchDefaults.template
        )
        XCTAssertEqual(result.query, "\"com.adobe.acc.installer.v2\" LaunchDaemon safe to remove")
    }

    func testUserAgentDisableQuery() {
        XCTAssertEqual(StartupItemType.userLaunchAgent.researchTypeKeyword, "LaunchAgent")
        let result = builder.build(
            label: "com.google.keystone.agent",
            typeKeyword: StartupItemType.userLaunchAgent.researchTypeKeyword,
            keyword: "safe to disable",
            template: ResearchSearchDefaults.template
        )
        XCTAssertEqual(result.query, "\"com.google.keystone.agent\" LaunchAgent safe to disable")
    }

    func testChineseKeywordIsNotTranslated() {
        let result = builder.build(
            label: "com.example.agent",
            typeKeyword: "LaunchAgent",
            keyword: "可以刪除嗎",
            template: ResearchSearchDefaults.template
        )
        XCTAssertEqual(result.query, "\"com.example.agent\" LaunchAgent 可以刪除嗎")
    }

    func testCustomTemplateInsertsMacOS() {
        let result = builder.build(
            label: "com.example.agent",
            typeKeyword: "LaunchAgent",
            keyword: "safe to remove",
            template: "\"{label}\" macOS {type} {keyword}"
        )
        XCTAssertEqual(result.query, "\"com.example.agent\" macOS LaunchAgent safe to remove")
    }

    func testRedditSiteTemplate() {
        let result = builder.build(
            label: "com.example.agent",
            typeKeyword: "LaunchAgent",
            keyword: "safe to remove",
            template: "\"{label}\" {type} site:reddit.com {keyword}"
        )
        XCTAssertEqual(result.query, "\"com.example.agent\" LaunchAgent site:reddit.com safe to remove")
    }

    func testUnknownVariableIsReportedAndKept() {
        let result = builder.build(
            label: "com.example.agent",
            typeKeyword: "LaunchAgent",
            keyword: "macOS",
            template: "\"{label}\" {abc} {keyword}"
        )
        XCTAssertEqual(result.unknownVariables, ["{abc}"])
        XCTAssertTrue(result.query.contains("{abc}"))
    }

    func testMissingLabelPlaceholderIsFlagged() {
        let result = builder.build(
            label: "com.example.agent",
            typeKeyword: "LaunchAgent",
            keyword: "macOS",
            template: "{type} {keyword}"
        )
        XCTAssertTrue(result.missingLabelPlaceholder)
        XCTAssertEqual(result.query, "LaunchAgent macOS")
    }

    func testSearchURLEncodesQuotesSpacesAndChinese() {
        let query = "\"com.example.agent\" LaunchAgent 可以刪除嗎"
        let url = ResearchSearchURL.googleURL(for: query)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "www.google.com")
        XCTAssertTrue(url?.absoluteString.contains("q=") ?? false)
        XCTAssertFalse(url?.absoluteString.contains(" ") ?? true)
    }

    func testSearchURLEncodesSiteOperator() {
        let url = ResearchSearchURL.googleURL(for: "\"com.example.agent\" LaunchAgent site:reddit.com")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("site") ?? false)
    }

    func testHttpsSearchFieldOpensAsURL() {
        let destination = ResearchSearchURL.destination(from: "https://www.google.com/search?q=test")
        if case .url(let url) = destination {
            XCTAssertEqual(url.host, "www.google.com")
        } else {
            XCTFail("expected URL destination")
        }
    }

    func testJavascriptSchemeIsNotOpenedAsURL() {
        let destination = ResearchSearchURL.destination(from: "javascript:alert(1)")
        if case .url(let url) = destination {
            XCTAssertNotEqual(url.scheme, "javascript")
        }
    }
}

@MainActor
final class ResearchSettingsTests: XCTestCase {
    private let keys = [
        "researchBrowserModePreferred",
        "researchQueryTemplate",
        "researchOverviewKeyword",
        "researchDisableKeyword",
        "researchRemoveKeyword",
        "researchCommunityKeyword"
    ]

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    func testDefaultValues() {
        let settings = AppSettings()
        XCTAssertEqual(settings.researchBrowserMode, .system)
        XCTAssertEqual(settings.researchQueryTemplate, "\"{label}\" {type} {keyword}")
        XCTAssertEqual(settings.researchOverviewKeyword, "macOS")
        XCTAssertEqual(ResearchBrowserMode.embedded.displayName, "內建瀏覽器")
        XCTAssertEqual(ResearchBrowserMode.system.displayName, "系統預設瀏覽器")
        XCTAssertEqual(
            settings.searchPreviewQuery,
            "\"com.example.service\" LaunchDaemon macOS"
        )
    }

    func testOnlyOverviewKeywordIsCustomizable() {
        let settings = AppSettings()
        settings.researchOverviewKeyword = "這是什麼"
        let research = ServiceResearchService()

        XCTAssertEqual(
            research.keyword(for: .overview, settings: settings),
            "這是什麼"
        )
        XCTAssertEqual(
            research.keyword(for: .disableSafety, settings: settings),
            ResearchSearchDefaults.disableKeyword
        )
        XCTAssertEqual(
            research.keyword(for: .removalSafety, settings: settings),
            ResearchSearchDefaults.removeKeyword
        )
        XCTAssertEqual(
            research.keyword(for: .community, settings: settings),
            ResearchSearchDefaults.communityKeyword
        )
    }

    func testPersistenceAcrossInstances() {
        let first = AppSettings()
        first.researchBrowserMode = .embedded
        first.researchQueryTemplate = "\"{label}\" macOS {type} {keyword}"
        first.researchOverviewKeyword = "這是什麼"

        let restored = AppSettings()
        XCTAssertEqual(restored.researchBrowserMode, .embedded)
        XCTAssertEqual(restored.researchQueryTemplate, "\"{label}\" macOS {type} {keyword}")
        XCTAssertEqual(restored.researchOverviewKeyword, "這是什麼")
    }

    func testRestoreDefaultsDoesNotResetBrowserMode() {
        let settings = AppSettings()
        settings.researchBrowserMode = .embedded
        settings.researchQueryTemplate = "broken"
        settings.researchOverviewKeyword = "x"

        settings.restoreResearchSearchDefaults()

        XCTAssertEqual(settings.researchBrowserMode, .embedded)
        XCTAssertEqual(settings.researchQueryTemplate, ResearchSearchDefaults.template)
        XCTAssertEqual(settings.researchOverviewKeyword, "macOS")
    }
}
