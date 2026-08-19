import XCTest
@testable import AutorunsLite

final class LaunchAgentAcceptanceTests: XCTestCase {
    private let launchctl = LaunchctlService()
    private let loadedLabel = "com.macautorunslite.loadedtest"
    private let unloadedLabel = "com.macautorunslite.unloadedtest"
    private let orphanLabel = "com.macautorunslite.orphantest"
    private let disabledLabel = "com.macautorunslite.disabledtest"

    private var agentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }

    override func tearDown() async throws {
        await cleanup(label: loadedLabel)
        await cleanup(label: unloadedLabel)
        await cleanup(label: orphanLabel)
        await cleanup(label: disabledLabel)
        try await super.tearDown()
    }

    func testLoadedUserLaunchAgent() async throws {
        let plistURL = try writePlist(label: loadedLabel, program: "/bin/sh", extra: sleepArguments)
        let domain = "gui/\(getuid())"
        let bootstrap = await launchctl.bootstrap(domain: domain, plistPath: plistURL.path)
        XCTAssertTrue(
            bootstrap.succeeded || bootstrap.combinedOutput.lowercased().contains("already"),
            "bootstrap failed: \(bootstrap.combinedOutput)"
        )

        let items = await StartupScanner().scan()
        let found = items.first { $0.label == loadedLabel }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.loadStatus, .loaded)
        XCTAssertEqual(found?.loadStatus.displayName, "已載入")
        XCTAssertTrue(found?.launchdLoaded ?? false)
    }

    func testUnloadedUserLaunchAgentIsNotOrphaned() async throws {
        try writePlist(label: unloadedLabel, program: "/bin/sh", extra: sleepArguments)
        let items = await StartupScanner().scan()
        let found = items.first { $0.label == unloadedLabel }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.loadStatus, .unloaded)
        XCTAssertNotEqual(found?.loadStatus, .orphaned)
        XCTAssertTrue(found?.executableExists ?? false)
        XCTAssertFalse(found?.launchdLoaded ?? true)
    }

    func testOrphanedPlistIsDetected() async throws {
        try writePlist(label: orphanLabel, program: "/tmp/macautorunslite-does-not-exist")
        let items = await StartupScanner().scan()
        let found = items.first { $0.label == orphanLabel }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.loadStatus, .orphaned)
        XCTAssertEqual(found?.loadStatus.displayName, "殘留")
        XCTAssertFalse(found?.executableExists ?? true)
    }

    func testDisabledUserLaunchAgent() async throws {
        try writePlist(label: disabledLabel, program: "/bin/sh", extra: sleepArguments)
        let domain = "gui/\(getuid())"
        let disable = await launchctl.disable(domain: domain, label: disabledLabel)
        XCTAssertTrue(disable.succeeded, "disable failed: \(disable.combinedOutput)")

        let items = await StartupScanner().scan()
        let found = items.first { $0.label == disabledLabel }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.loadStatus, .disabled)
        XCTAssertTrue(found?.persistentlyDisabled ?? false)
    }

    func testEmptyLoadedParserDoesNotAffectScan() async throws {
        XCTAssertTrue(LaunchctlService().parseLoadedLabels(from: "").isEmpty)
        try await testLoadedUserLaunchAgent()
    }

    private var sleepArguments: String {
        """
            <key>ProgramArguments</key>
            <array>
                <string>/bin/sh</string>
                <string>-c</string>
                <string>sleep 3600</string>
            </array>
        """
    }

    @discardableResult
    private func writePlist(label: String, program: String, extra: String = "") throws -> URL {
        try FileManager.default.createDirectory(at: agentsDirectory, withIntermediateDirectories: true)
        let url = agentsDirectory.appendingPathComponent("\(label).plist")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>Program</key>
            <string>\(program)</string>
            \(extra)
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """
        try xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func cleanup(label: String) async {
        let plistURL = agentsDirectory.appendingPathComponent("\(label).plist")
        let domain = "gui/\(getuid())"
        _ = await launchctl.bootout(domain: domain, plistPath: plistURL.path)
        _ = await launchctl.enable(domain: domain, label: label)
        try? FileManager.default.removeItem(at: plistURL)
    }
}
