import XCTest
@testable import AutorunsLite

final class RecommendationResolverTests: XCTestCase {
    private let resolver = RecommendationResolver()
    private var createdFiles: [URL] = []

    override func tearDown() {
        createdFiles.forEach { try? FileManager.default.removeItem(at: $0) }
        createdFiles.removeAll()
        super.tearDown()
    }

    func testLoadedThirdPartyIsKeep() {
        let item = makeItem(
            label: "com.example.appagent",
            type: .userLaunchAgent,
            status: .loaded,
            origin: .thirdParty,
            executableExists: true,
            createPlist: true,
            appExists: true
        )
        XCTAssertEqual(resolver.resolve(item).recommendation, .keep)
    }

    func testUnloadedThirdPartyIsKeepNotSafeAction() {
        let item = makeItem(
            label: "com.example.appagent",
            type: .userLaunchAgent,
            status: .unloaded,
            origin: .thirdParty,
            executableExists: true,
            createPlist: true,
            appExists: true
        )
        let result = resolver.resolve(item)
        XCTAssertEqual(result.recommendation, .keep)
        XCTAssertNotEqual(result.recommendation, .safeAction)
        XCTAssertTrue(result.reason.contains("未載入"))
        XCTAssertTrue(result.reason.contains("不是刪除理由"))
    }

    func testOrphanedSafeItemIsSafeAction() {
        let item = makeItem(
            label: "com.example.oldagent",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            createPlist: true
        )
        XCTAssertEqual(resolver.resolve(item).recommendation, .safeAction)
    }

    func testOrphanedHelperIsReviewRequired() {
        let item = makeItem(
            label: "com.example.helper",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            createPlist: true
        )
        XCTAssertEqual(resolver.resolve(item).recommendation, .reviewRequired)
    }

    func testAppleLabelIsProtected() {
        let item = makeItem(
            label: "com.apple.blued",
            type: .userLaunchAgent,
            status: .loaded,
            origin: .appleSystem,
            executableExists: true,
            createPlist: true
        )
        XCTAssertEqual(resolver.resolve(item).recommendation, .protected)
    }

    func testLaunchDaemonIsReviewRequired() {
        let item = makeItem(
            label: "com.example.daemon",
            type: .launchDaemon,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            createPlist: true
        )
        XCTAssertEqual(resolver.resolve(item).recommendation, .reviewRequired)
    }

    func testDisabledInstalledAppIsKeep() {
        let item = makeItem(
            label: "com.example.appagent",
            type: .userLaunchAgent,
            status: .disabled,
            origin: .thirdParty,
            executableExists: true,
            createPlist: true,
            appExists: true
        )
        XCTAssertEqual(resolver.resolve(item).recommendation, .keep)
    }

    func testTrashOnlyAllowsSafeUserLaunchAgentInHome() {
        let homePlist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.example.not-created.plist")
        let safe = makeItem(
            label: "com.example.oldagent",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            plistPath: homePlist.path,
            createPlist: false
        )
        XCTAssertFalse(TrashEligibility.canMoveToTrash(safe, recommendation: .safeAction))

        let library = makeItem(
            label: "com.example.oldagent",
            type: .systemLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            plistPath: "/Library/LaunchAgents/com.example.oldagent.plist",
            createPlist: false
        )
        XCTAssertFalse(TrashEligibility.canMoveToTrash(library, recommendation: .safeAction))
        XCTAssertFalse(TrashEligibility.canMoveToTrash(safe, recommendation: .keep))
    }

    private func makeItem(
        label: String,
        type: StartupItemType,
        status: LoadStatus,
        origin: ItemOrigin,
        executableExists: Bool,
        plistPath: String? = nil,
        createPlist: Bool,
        appExists: Bool = false
    ) -> StartupItem {
        let path: String
        if let plistPath {
            path = plistPath
        } else if createPlist {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(label).plist")
            try? "test".write(to: url, atomically: true, encoding: .utf8)
            createdFiles.append(url)
            path = url.path
        } else {
            path = "/tmp/missing-\(label).plist"
        }

        var appBundlePath: String?
        if appExists {
            let appURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(label).app")
            try? FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
            createdFiles.append(appURL)
            appBundlePath = appURL.path
        }

        return StartupItem(
            id: path,
            label: label,
            plistPath: path,
            executablePath: executableExists ? "/usr/local/bin/\(label)" : "/tmp/nonexistent-\(label)",
            arguments: [],
            type: type,
            runAtLoad: true,
            keepAliveDescription: nil,
            executableExists: executableExists,
            loadStatus: status,
            workingDirectory: nil,
            environmentVariables: [:],
            standardOutPath: nil,
            standardErrorPath: nil,
            appDisplayName: nil,
            appBundleName: nil,
            appBundleIdentifier: nil,
            appBundlePath: appBundlePath,
            origin: origin,
            launchdLoaded: status == .loaded,
            persistentlyDisabled: status == .disabled
        )
    }
}
