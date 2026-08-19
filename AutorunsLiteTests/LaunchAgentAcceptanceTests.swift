import XCTest
@testable import AutorunsLite

final class LaunchAgentAcceptanceTests: XCTestCase {
    private let label = "com.autorunslite.test"
    private let launchctl = LaunchctlService()
    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    override func tearDown() async throws {
        _ = await launchctl.bootout(domain: "gui/\(getuid())", plistPath: plistURL.path)
        try? FileManager.default.removeItem(at: plistURL)
        try await super.tearDown()
    }

    func testUserLaunchAgentBootstrapPrintAndBootout() async throws {
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try plistXML.write(to: plistURL, atomically: true, encoding: .utf8)

        let domain = "gui/\(getuid())"
        let bootstrap = await launchctl.bootstrap(domain: domain, plistPath: plistURL.path)
        XCTAssertTrue(
            bootstrap.succeeded || bootstrap.combinedOutput.lowercased().contains("already"),
            "bootstrap failed: \(bootstrap.combinedOutput)"
        )

        let printed = await launchctl.printService(domain: domain, label: label)
        XCTAssertTrue(printed.succeeded, "print failed: \(printed.combinedOutput)")

        let scanner = StartupScanner()
        let items = await scanner.scan()
        let found = items.first { $0.label == label }
        XCTAssertNotNil(found, "scanner did not find \(label)")
        XCTAssertEqual(found?.type, .userLaunchAgent)
        XCTAssertEqual(found?.executablePath, "/bin/sh")
        XCTAssertTrue(found?.executableExists ?? false)
        XCTAssertNotEqual(found?.loadStatus, .orphaned)

        let bootout = await launchctl.bootout(domain: domain, plistPath: plistURL.path)
        XCTAssertTrue(bootout.succeeded, "bootout failed: \(bootout.combinedOutput)")

        let after = await launchctl.printService(domain: domain, label: label)
        XCTAssertFalse(after.succeeded)
        XCTAssertTrue(after.combinedOutput.lowercased().contains("could not find service"))
    }

    func testOrphanedPlistIsDetected() async throws {
        let orphanLabel = "com.autorunslite.orphan"
        let orphanURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(orphanLabel).plist")
        defer { try? FileManager.default.removeItem(at: orphanURL) }

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(orphanLabel)</string>
            <key>Program</key>
            <string>/tmp/nonexistent123</string>
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """
        try xml.write(to: orphanURL, atomically: true, encoding: .utf8)

        let items = await StartupScanner().scan()
        let found = items.first { $0.label == orphanLabel }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.loadStatus, .orphaned)
        XCTAssertEqual(found?.loadStatus.displayName, "殘留")
        XCTAssertEqual(found?.loadStatus.systemImage, "exclamationmark.triangle.fill")
        XCTAssertFalse(found?.executableExists ?? true)
    }

    private var plistXML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/sh</string>
                <string>-c</string>
                <string>sleep 3600</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
    }
}
