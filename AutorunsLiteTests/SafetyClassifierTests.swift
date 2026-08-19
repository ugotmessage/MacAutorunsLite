import XCTest
@testable import AutorunsLite

final class SafetyClassifierTests: XCTestCase {
    private let classifier = SafetyClassifier()
    private var createdFiles: [URL] = []

    override func tearDown() {
        createdFiles.forEach { try? FileManager.default.removeItem(at: $0) }
        createdFiles.removeAll()
        super.tearDown()
    }

    func testOrphanedThirdPartyUserAgentIsSafe() {
        let item = makeItem(
            label: "com.example.oldagent",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            createPlist: true
        )
        XCTAssertEqual(classifier.classify(item).classification, .safe)
    }

    func testAppleLabelIsProtected() {
        let item = makeItem(
            label: "com.apple.blued",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .appleSystem,
            executableExists: false,
            createPlist: true
        )
        XCTAssertEqual(classifier.classify(item).classification, .protected)
    }

    func testSystemPathIsProtected() {
        let item = makeItem(
            label: "com.example.systemish",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            plistPath: "/System/Library/LaunchAgents/com.example.systemish.plist",
            createPlist: false
        )
        XCTAssertEqual(classifier.classify(item).classification, .protected)
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
        XCTAssertEqual(classifier.classify(item).classification, .reviewRequired)
    }

    func testSystemLaunchAgentIsReviewRequired() {
        let item = makeItem(
            label: "com.example.systemagent",
            type: .systemLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            createPlist: true
        )
        XCTAssertEqual(classifier.classify(item).classification, .reviewRequired)
    }

    func testExistingExecutableIsReviewRequired() {
        let item = makeItem(
            label: "com.example.alive",
            type: .userLaunchAgent,
            status: .loaded,
            origin: .thirdParty,
            executableExists: true,
            executablePath: "/usr/local/bin/example-alive",
            createPlist: true
        )
        XCTAssertEqual(classifier.classify(item).classification, .reviewRequired)
    }

    func testAppStillInstalledIsReviewRequired() {
        let appURL = FileManager.default.temporaryDirectory.appendingPathComponent("StillInstalled.app")
        try? FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
        createdFiles.append(appURL)

        let item = makeItem(
            label: "com.example.stillinstalled",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            appBundlePath: appURL.path,
            createPlist: true
        )
        XCTAssertEqual(classifier.classify(item).classification, .reviewRequired)
    }

    func testMissingPlistIsReviewRequired() {
        let item = makeItem(
            label: "com.example.goneplist",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            createPlist: false
        )
        XCTAssertEqual(classifier.classify(item).classification, .reviewRequired)
    }

    func testUpdaterNameIsReviewRequired() {
        let item = makeItem(
            label: "com.example.updater",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            createPlist: true
        )
        XCTAssertEqual(classifier.classify(item).classification, .reviewRequired)
    }

    func testHelperNameIsReviewRequired() {
        let item = makeItem(
            label: "com.example.helper",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            createPlist: true
        )
        XCTAssertEqual(classifier.classify(item).classification, .reviewRequired)
    }

    func testUnknownOriginIsReviewRequired() {
        let item = makeItem(
            label: "mystery.agent",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .unknown,
            executableExists: false,
            createPlist: true
        )
        XCTAssertEqual(classifier.classify(item).classification, .reviewRequired)
    }

    func testKeepAliveIsReviewRequired() {
        let item = makeItem(
            label: "com.example.keepalive",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            keepAlive: "Yes",
            createPlist: true
        )
        XCTAssertEqual(classifier.classify(item).classification, .reviewRequired)
    }

    func testDryRunDoesNotChangeItems() {
        let safe = makeItem(
            label: "com.example.oldagent",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .thirdParty,
            executableExists: false,
            createPlist: true
        )
        let protected = makeItem(
            label: "com.apple.safari",
            type: .userLaunchAgent,
            status: .orphaned,
            origin: .appleSystem,
            executableExists: false,
            createPlist: true
        )
        let dryRun = classifier.dryRun(items: [safe, protected])
        XCTAssertEqual(dryRun.safeCount, 1)
        XCTAssertEqual(dryRun.protectedCount, 1)
        XCTAssertEqual(dryRun.reviewCount, 0)
        XCTAssertEqual(safe.loadStatus, .orphaned)
        XCTAssertEqual(protected.loadStatus, .orphaned)
    }

    private func makeItem(
        label: String,
        type: StartupItemType,
        status: LoadStatus,
        origin: ItemOrigin,
        executableExists: Bool,
        keepAlive: String? = nil,
        plistPath: String? = nil,
        executablePath: String? = nil,
        appBundlePath: String? = nil,
        createPlist: Bool
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

        return StartupItem(
            id: path,
            label: label,
            plistPath: path,
            executablePath: executablePath ?? (executableExists ? "/usr/local/bin/\(label)" : "/tmp/nonexistent-\(label)"),
            arguments: [],
            type: type,
            runAtLoad: true,
            keepAliveDescription: keepAlive,
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
