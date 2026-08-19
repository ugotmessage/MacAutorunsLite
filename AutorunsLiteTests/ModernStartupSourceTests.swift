import XCTest
@testable import AutorunsLite

final class BTMDumpParserTests: XCTestCase {
    private let parser = BTMDumpParser()

    func testParsesDumpFieldsAndTypes() {
        let records = parser.parse(Self.sampleDump)
        XCTAssertEqual(records.count, 4)

        let login = records[0]
        XCTAssertEqual(login.uuid, "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
        XCTAssertEqual(login.inferredType, .loginItem)
        XCTAssertEqual(login.associatedBundleIDs, ["com.example.app"])
        XCTAssertEqual(login.parentIdentifier, "Example")
        XCTAssertEqual(login.loadStatus, .loaded)
        XCTAssertEqual(login.filePath, "/Applications/Example.app")

        let sm = records[1]
        XCTAssertEqual(sm.inferredType, .smAppService)
        XCTAssertTrue(sm.filePath.hasSuffix("/com.example.agent.plist"))

        let legacy = records[2]
        XCTAssertEqual(legacy.inferredType, .launchDaemon)
        XCTAssertTrue(legacy.isLegacyTraditional)
        XCTAssertEqual(legacy.loadStatus, .disabled)
        XCTAssertEqual(legacy.filePath, "/Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist")

        let background = records[3]
        XCTAssertEqual(background.inferredType, .backgroundTask)
        XCTAssertEqual(background.teamIdentifier, "ABCD123456")
    }

    func testUserScanDoesNotReadBTMDump() {
        var dumpCalled = false
        let scanner = ModernStartupScanner(dumpProvider: {
            dumpCalled = true
            return nil
        })
        _ = scanner.scan(includeSystemSources: false)
        XCTAssertFalse(dumpCalled)
    }

    func testSystemScanReadsBTMDump() {
        var dumpCalled = false
        let scanner = ModernStartupScanner(dumpProvider: {
            dumpCalled = true
            return nil
        })
        _ = scanner.scan(includeSystemSources: true)
        XCTAssertTrue(dumpCalled)
    }

    static let sampleDump = """
    Background Items:
    #1:
    UUID: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA
    Name: Example Login
    Developer Name: Example Inc
    Team Identifier: ABCD123456
    Type: user item (0x1)
    Disposition: [enabled, allowed, visible, notified] (11)
    Identifier: com.example.app
    URL: file:///Applications/Example.app/
    Executable Path: /Applications/Example.app/Contents/MacOS/Example
    Assoc. Bundle IDs: [ com.example.app ]
    Parent Identifier: Example

    #2:
    UUID: BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB
    Name: com.example.agent
    Developer Name: Example Inc
    Team Identifier: ABCD123456
    Type: developer agent (0x20)
    Disposition: [enabled, allowed, visible, notified] (11)
    Identifier: com.example.agent
    URL: file:///Applications/Example.app/Contents/Library/LaunchAgents/com.example.agent.plist
    Executable Path: /Applications/Example.app/Contents/MacOS/agent
    Assoc. Bundle IDs: [ com.example.app ]
    Parent Identifier: Example

    #3:
    UUID: CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC
    Name: com.microsoft.autoupdate.helper
    Type: curated legacy daemon (0x90010)
    Disposition: [disabled, allowed, visible, notified] (10)
    Identifier: com.microsoft.autoupdate.helper
    URL: file:///Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist
    Executable Path: /Library/PrivilegedHelperTools/com.microsoft.autoupdate.helper
    Parent Identifier: Microsoft AutoUpdate

    #4:
    UUID: DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD
    Name: Background Example
    Developer Name: Example Inc
    Team Identifier: ABCD123456
    Type: app (0x2)
    Disposition: [enabled, allowed, visible, notified] (11)
    Identifier: com.example.background
    URL: file:///Applications/Background.app/
    Executable Path: /Applications/Background.app/Contents/MacOS/Background
    """
}

final class ModernSourceMergeTests: XCTestCase {
    func testLegacyDaemonURLDoesNotDuplicateTraditionalItem() {
        let traditional = makeTraditional(
            label: "com.microsoft.autoupdate.helper",
            plistPath: "/Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist",
            type: .launchDaemon
        )
        let records = BTMDumpParser().parse(BTMDumpParserTests.sampleDump)
        let merged = StartupItemMerger().merge(
            traditional: [traditional],
            modern: [],
            btmRecords: records
        )
        let daemons = merged.filter { $0.plistPath == traditional.plistPath }
        XCTAssertEqual(daemons.count, 1)
        XCTAssertEqual(daemons[0].type, .launchDaemon)
        XCTAssertEqual(daemons[0].btmUUID, "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")
        XCTAssertEqual(daemons[0].loadStatus, .disabled)
    }

    func testModernItemsAreAddedWhenNotInTraditionalScan() {
        let records = BTMDumpParser().parse(BTMDumpParserTests.sampleDump)
        let merged = StartupItemMerger().merge(traditional: [], modern: [], btmRecords: records)
        XCTAssertTrue(merged.contains { $0.type == .loginItem })
        XCTAssertTrue(merged.contains { $0.type == .smAppService })
        XCTAssertTrue(merged.contains { $0.type == .backgroundTask })
        XCTAssertTrue(merged.contains { $0.type == .launchDaemon })
    }

    private func makeTraditional(label: String, plistPath: String, type: StartupItemType) -> StartupItem {
        StartupItem(
            id: plistPath,
            label: label,
            plistPath: plistPath,
            executablePath: "/usr/bin/true",
            arguments: [],
            type: type,
            runAtLoad: true,
            keepAliveDescription: nil,
            executableExists: true,
            loadStatus: .loaded,
            workingDirectory: nil,
            environmentVariables: [:],
            standardOutPath: nil,
            standardErrorPath: nil,
            appDisplayName: nil,
            appBundleName: nil,
            appBundleIdentifier: nil,
            appBundlePath: nil,
            origin: .thirdParty,
            launchdLoaded: true,
            persistentlyDisabled: false
        )
    }
}

final class StartupItemTypeTests: XCTestCase {
    func testDisplayNamesAndLaunchctlSupport() {
        XCTAssertEqual(StartupItemType.userLaunchAgent.displayName, "User Agent")
        XCTAssertEqual(StartupItemType.systemLaunchAgent.sourceDescription, "System LaunchAgent")
        XCTAssertEqual(StartupItemType.launchDaemon.sourceDescription, "LaunchDaemon")
        XCTAssertEqual(StartupItemType.loginItem.sourceDescription, "Login Item")
        XCTAssertEqual(StartupItemType.backgroundTask.sourceDescription, "Background Task")
        XCTAssertEqual(StartupItemType.smAppService.sourceDescription, "SMAppService")
        XCTAssertEqual(StartupItemType.loginItem.researchTypeKeyword, "login item")
        XCTAssertEqual(StartupItemType.backgroundTask.researchTypeKeyword, "background task")
        XCTAssertEqual(StartupItemType.smAppService.researchTypeKeyword, "SMAppService")

        XCTAssertTrue(StartupItemType.userLaunchAgent.supportsLaunchctl)
        XCTAssertTrue(StartupItemType.systemLaunchAgent.supportsLaunchctl)
        XCTAssertTrue(StartupItemType.launchDaemon.supportsLaunchctl)
        XCTAssertFalse(StartupItemType.loginItem.supportsLaunchctl)
        XCTAssertFalse(StartupItemType.backgroundTask.supportsLaunchctl)
        XCTAssertFalse(StartupItemType.smAppService.supportsLaunchctl)
        XCTAssertNil(StartupItemType.loginItem.launchctlDomain)
        XCTAssertEqual(StartupItemType.launchDaemon.launchctlDomain, "system")
    }

    func testScanDirectoriesAreUserOnlyByDefault() {
        let userOnly = StartupScanner.scanDirectories(includeSystemItems: false)
        XCTAssertEqual(userOnly.map(\.type), [.userLaunchAgent])
        let withSystem = StartupScanner.scanDirectories(includeSystemItems: true)
        XCTAssertEqual(withSystem.map(\.type), [.userLaunchAgent, .systemLaunchAgent, .launchDaemon])
    }
}

final class AppRelationTests: XCTestCase {
    func testRelatedItemsShareParentBundle() {
        let parent = makeItem(
            id: "source:loginItem:/Applications/Example.app",
            label: "com.example.app",
            type: .loginItem,
            bundleID: "com.example.app",
            parentID: "com.example.app",
            helpers: [
                RelatedHelper(name: "Example XPC", path: "/Applications/Example.app/Contents/XPCServices/Example.xpc", kind: .xpc, bundleIdentifier: "com.example.xpc")
            ]
        )
        let helper = makeItem(
            id: "source:smAppService:/Applications/Example.app/Contents/Library/LaunchAgents/com.example.agent.plist",
            label: "com.example.agent",
            type: .smAppService,
            bundleID: "com.example.app",
            parentID: "com.example.app"
        )
        let unrelated = makeItem(
            id: "other",
            label: "com.other.app",
            type: .loginItem,
            bundleID: "com.other.app",
            parentID: "com.other.app"
        )

        let related = AppRelationMatcher.related(to: parent, in: [parent, helper, unrelated])
        XCTAssertEqual(related.map(\.id), [helper.id])
        XCTAssertEqual(parent.relatedHelpers.first?.kind, .xpc)
    }

    private func makeItem(
        id: String,
        label: String,
        type: StartupItemType,
        bundleID: String,
        parentID: String,
        helpers: [RelatedHelper] = []
    ) -> StartupItem {
        StartupItem(
            id: id,
            label: label,
            plistPath: "",
            executablePath: "/Applications/Example.app",
            arguments: [],
            type: type,
            runAtLoad: true,
            keepAliveDescription: nil,
            executableExists: true,
            loadStatus: .unknown,
            workingDirectory: nil,
            environmentVariables: [:],
            standardOutPath: nil,
            standardErrorPath: nil,
            appDisplayName: "Example",
            appBundleName: "Example",
            appBundleIdentifier: bundleID,
            appBundlePath: "/Applications/Example.app",
            origin: .thirdParty,
            launchdLoaded: false,
            persistentlyDisabled: false,
            parentBundleIdentifier: parentID,
            parentDisplayName: "Example",
            associatedBundleIDs: [parentID],
            relatedHelpers: helpers
        )
    }
}

final class ModernActionGuardTests: XCTestCase {
    @MainActor
    func testViewModelCannotMutateModernSources() {
        let vm = StartupViewModel()
        let item = StartupItem(
            id: "source:loginItem:/Applications/Example.app",
            label: "com.example.app",
            plistPath: "",
            executablePath: "/Applications/Example.app",
            arguments: [],
            type: .loginItem,
            runAtLoad: true,
            keepAliveDescription: nil,
            executableExists: true,
            loadStatus: .loaded,
            workingDirectory: nil,
            environmentVariables: [:],
            standardOutPath: nil,
            standardErrorPath: nil,
            appDisplayName: "Example",
            appBundleName: "Example",
            appBundleIdentifier: "com.example.app",
            appBundlePath: "/Applications/Example.app",
            origin: .thirdParty,
            launchdLoaded: false,
            persistentlyDisabled: false
        )
        XCTAssertFalse(vm.canStart(item))
        XCTAssertFalse(vm.canStop(item))
        XCTAssertFalse(vm.canEnable(item))
        XCTAssertFalse(vm.canDisable(item))
        XCTAssertFalse(vm.canMoveToTrash(item))
    }

    @MainActor
    func testNotesFallBackToPlistPath() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notes-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ItemNotesStore(fileURL: url)
        store.save(["/tmp/legacy.plist": "舊備註"])
        let vm = StartupViewModel(notesStore: store)
        let item = StartupItem(
            id: "source:smAppService:/tmp/legacy.plist",
            label: "com.example.agent",
            plistPath: "/tmp/legacy.plist",
            executablePath: nil,
            arguments: [],
            type: .smAppService,
            runAtLoad: false,
            keepAliveDescription: nil,
            executableExists: true,
            loadStatus: .unknown,
            workingDirectory: nil,
            environmentVariables: [:],
            standardOutPath: nil,
            standardErrorPath: nil,
            appDisplayName: nil,
            appBundleName: nil,
            appBundleIdentifier: nil,
            appBundlePath: nil,
            origin: .thirdParty,
            launchdLoaded: false,
            persistentlyDisabled: false
        )
        XCTAssertEqual(vm.note(for: item), "舊備註")
    }

    @MainActor
    func testSystemItemsAreOptIn() {
        let vm = StartupViewModel()
        XCTAssertFalse(vm.includeSystemItems)
    }
}

final class SystemLoadDecisionTests: XCTestCase {
    func testDoesNotCommitWhenSystemAccessDenied() {
        let scanned = ScanResult(
            items: [],
            modernSourceWarning: "無法讀取 Background Task 資料庫。Login Item 與 in-bundle helper 仍會顯示，狀態請以系統設定為準。",
            systemLoadGranted: false
        )
        XCTAssertFalse(SystemLoadDecision.shouldCommit(scanned: scanned, previousSystemCount: 0))
    }

    func testCommitsWhenSystemLaunchdItemsPresent() {
        let item = StartupItem(
            id: "/Library/LaunchDaemons/com.example.daemon.plist",
            label: "com.example.daemon",
            plistPath: "/Library/LaunchDaemons/com.example.daemon.plist",
            executablePath: "/usr/bin/true",
            arguments: [],
            type: .launchDaemon,
            runAtLoad: false,
            keepAliveDescription: nil,
            executableExists: true,
            loadStatus: .unknown,
            workingDirectory: nil,
            environmentVariables: [:],
            standardOutPath: nil,
            standardErrorPath: nil,
            appDisplayName: nil,
            appBundleName: nil,
            appBundleIdentifier: nil,
            appBundlePath: nil,
            origin: .thirdParty,
            launchdLoaded: false,
            persistentlyDisabled: false
        )
        let scanned = ScanResult(items: [item], modernSourceWarning: nil, systemLoadGranted: true)
        XCTAssertTrue(SystemLoadDecision.shouldCommit(scanned: scanned, previousSystemCount: 0))
    }
}

final class LaunchctlPermissionTests: XCTestCase {
    func testDetectsPermissionDenied() {
        let result = LaunchctlResult(
            command: "launchctl print-disabled system",
            exitCode: 1,
            stdout: "",
            stderr: "Operation not permitted"
        )
        XCTAssertTrue(result.permissionDenied)
    }
}

final class AppBundleHelperScannerTests: XCTestCase {
    func testFindsLoginItemSMAppServiceAndXPC() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("apps-\(UUID().uuidString)")
        let app = root.appendingPathComponent("Example.app")
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(
            at: contents.appendingPathComponent("Library/LoginItems/Helper.app/Contents"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: contents.appendingPathComponent("Library/LaunchAgents"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: contents.appendingPathComponent("XPCServices"),
            withIntermediateDirectories: true
        )
        try writeInfo(to: contents.appendingPathComponent("Info.plist"), bundleID: "com.example.app", name: "Example")
        try writeInfo(
            to: contents.appendingPathComponent("Library/LoginItems/Helper.app/Contents/Info.plist"),
            bundleID: "com.example.helper",
            name: "Helper"
        )
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>Label</key><string>com.example.agent</string>
        <key>ProgramArguments</key><array><string>/usr/bin/true</string></array>
        </dict></plist>
        """
        try plist.write(
            to: contents.appendingPathComponent("Library/LaunchAgents/com.example.agent.plist"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createDirectory(
            at: contents.appendingPathComponent("XPCServices/ExampleXPC.xpc/Contents"),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let scan = AppBundleHelperScanner(applicationDirectories: [root]).scan()
        XCTAssertTrue(
            scan.items.contains { $0.type == .loginItem && $0.label == "com.example.helper" },
            "login item missing: \(scan.items.map { "\($0.type.rawValue):\($0.label)" })"
        )
        XCTAssertTrue(
            scan.items.contains { $0.type == .smAppService && $0.label == "com.example.agent" },
            "smAppService missing: \(scan.items.map { "\($0.type.rawValue):\($0.label)" })"
        )
        let parentKey = app.resolvingSymlinksInPath().standardizedFileURL.path
        let xpcHelpers = scan.helpersByParentPath[parentKey]
            ?? scan.helpersByParentPath.first {
                URL(fileURLWithPath: $0.key).resolvingSymlinksInPath().path == parentKey
            }?.value
        XCTAssertTrue(
            xpcHelpers?.contains { $0.kind == .xpc } == true,
            "xpc helper missing for \(parentKey); keys=\(Array(scan.helpersByParentPath.keys))"
        )
    }

    private func writeInfo(to url: URL, bundleID: String, name: String) throws {
        let plist: [String: String] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": name,
            "CFBundleExecutable": name
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)
    }
}

