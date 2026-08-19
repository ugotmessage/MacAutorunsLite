import XCTest
@testable import AutorunsLite

final class LoadStatusResolverTests: XCTestCase {
    func testOrphanedWhenExecutableMissing() {
        let status = LoadStatusResolver.resolve(
            executableExists: false,
            isDisabled: false,
            printSucceeded: true,
            printOutput: "",
            exitCode: 0
        )
        XCTAssertEqual(status, .orphaned)
        XCTAssertEqual(status.displayName, "殘留")
        XCTAssertEqual(status.systemImage, "exclamationmark.triangle.fill")
    }

    func testDisabledTakesPriorityOverLoaded() {
        let status = LoadStatusResolver.resolve(
            executableExists: true,
            isDisabled: true,
            printSucceeded: true,
            printOutput: "",
            exitCode: 0
        )
        XCTAssertEqual(status, .disabled)
    }

    func testLoadedWhenPrintSucceeds() {
        let status = LoadStatusResolver.resolve(
            executableExists: true,
            isDisabled: false,
            printSucceeded: true,
            printOutput: "state = running",
            exitCode: 0
        )
        XCTAssertEqual(status, .loaded)
        XCTAssertEqual(status.displayName, "已載入")
        XCTAssertEqual(status.systemImage, "circle.fill")
    }

    func testUnloadedWhenServiceMissing() {
        let status = LoadStatusResolver.resolve(
            executableExists: true,
            isDisabled: false,
            printSucceeded: false,
            printOutput: "Could not find service \"com.example\" in domain",
            exitCode: 113
        )
        XCTAssertEqual(status, .unloaded)
        XCTAssertEqual(status.displayName, "未載入")
        XCTAssertEqual(status.systemImage, "circle")
    }

    func testErrorPreservesStderr() {
        let status = LoadStatusResolver.resolve(
            executableExists: true,
            isDisabled: false,
            printSucceeded: false,
            printOutput: "Boot-out failed: 5: Input/output error",
            exitCode: 5
        )
        XCTAssertEqual(status, .error("Boot-out failed: 5: Input/output error"))
        XCTAssertEqual(status.displayName, "錯誤")
        XCTAssertEqual(status.systemImage, "xmark.octagon.fill")
    }

    func testSortOrderPutsOrphanedFirst() {
        let items = [
            makeItem(label: "b.loaded", status: .loaded),
            makeItem(label: "a.unloaded", status: .unloaded),
            makeItem(label: "z.orphaned", status: .orphaned),
            makeItem(label: "m.disabled", status: .disabled)
        ].sortedForDisplay()

        XCTAssertEqual(items.map(\.label), [
            "z.orphaned",
            "m.disabled",
            "b.loaded",
            "a.unloaded"
        ])
    }

    func testGroupedByStatusOrderAndCounts() {
        let items = [
            makeItem(label: "b.loaded", status: .loaded),
            makeItem(label: "a.unloaded", status: .unloaded),
            makeItem(label: "z.orphaned", status: .orphaned),
            makeItem(label: "m.disabled", status: .disabled),
            makeItem(label: "c.loaded", status: .loaded)
        ]
        let groups = items.groupedByStatus()
        XCTAssertEqual(groups.map(\.kind), [.orphaned, .disabled, .loaded, .unloaded])
        XCTAssertEqual(groups[0].items.map(\.label), ["z.orphaned"])
        XCTAssertEqual(groups[2].items.map(\.label), ["b.loaded", "c.loaded"])
    }

    func testStatusAndFilterUseChineseDisplayNames() {
        XCTAssertEqual(LoadStatus.loaded.displayName, "已載入")
        XCTAssertEqual(LoadStatus.unloaded.displayName, "未載入")
        XCTAssertEqual(LoadStatus.disabled.displayName, "已停用")
        XCTAssertEqual(LoadStatus.orphaned.displayName, "殘留")
        XCTAssertEqual(LoadStatus.error("x").displayName, "錯誤")
        XCTAssertEqual(LoadStatus.unknown.displayName, "未知")

        XCTAssertEqual(LoadStatus.loaded.systemImage, "circle.fill")
        XCTAssertEqual(LoadStatus.unloaded.systemImage, "circle")
        XCTAssertEqual(LoadStatus.disabled.systemImage, "pause.circle.fill")
        XCTAssertEqual(LoadStatus.orphaned.systemImage, "exclamationmark.triangle.fill")
        XCTAssertEqual(LoadStatus.unknown.systemImage, "questionmark.circle")

        XCTAssertEqual(StartupFilter.all.title, "全部")
        XCTAssertEqual(StartupFilter.userLaunchAgents.title, "User Agents")
        XCTAssertEqual(StartupFilter.systemLaunchAgents.title, "System Agents")
        XCTAssertEqual(StartupFilter.launchDaemons.title, "Daemons")
        XCTAssertEqual(StartupFilter.loaded.title, "已載入")
        XCTAssertEqual(StartupFilter.disabled.title, "已停用")
        XCTAssertEqual(StartupFilter.orphaned.title, "殘留")
        XCTAssertTrue(LoadStatus.loaded.shortDescription.contains("launchd"))
        XCTAssertTrue(LoadStatus.unloaded.shortDescription.contains("不一定是異常"))
        XCTAssertTrue(LoadStatus.loaded.detailedDescription.contains("不代表"))
        XCTAssertTrue(LoadStatus.unloaded.detailedDescription.contains("不代表可以安全刪除"))
    }

    func testRuntimeStateNotFoundIsUnloaded() {
        let status = LoadStatusResolver.resolve(
            executableExists: true,
            isDisabled: false,
            runtimeState: .notFound
        )
        XCTAssertEqual(status, .unloaded)
    }

    func testRuntimeStateErrorIsError() {
        let status = LoadStatusResolver.resolve(
            executableExists: true,
            isDisabled: false,
            runtimeState: .error("Permission denied")
        )
        XCTAssertEqual(status, .error("Permission denied"))
    }

    func testAppleLabelIsProtected() {
        let item = makeItem(label: "com.apple.Safari", status: .loaded)
        XCTAssertTrue(item.isSystemProtected)
    }

    private func makeItem(label: String, status: LoadStatus) -> StartupItem {
        StartupItem(
            id: label,
            label: label,
            plistPath: "/tmp/\(label).plist",
            executablePath: "/bin/sh",
            arguments: ["/bin/sh"],
            type: .userLaunchAgent,
            runAtLoad: true,
            keepAliveDescription: nil,
            executableExists: status != .orphaned,
            loadStatus: status,
            workingDirectory: nil,
            environmentVariables: [:],
            standardOutPath: nil,
            standardErrorPath: nil,
            appDisplayName: nil,
            appBundleName: nil,
            appBundleIdentifier: nil,
            appBundlePath: nil,
            origin: ItemOrigin.classify(label: label, plistPath: "/tmp/\(label).plist", executablePath: "/bin/sh"),
            launchdLoaded: status == .loaded,
            persistentlyDisabled: status == .disabled
        )
    }
}
