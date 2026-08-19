import Foundation

struct ScanDirectory: Sendable {
    let url: URL
    let type: StartupItemType
}

private struct DiscoveredLaunchItem: Sendable {
    let plistURL: URL
    let type: StartupItemType
    let parsed: ParsedLaunchPlist?
    let parseErrorDescription: String?
}

final class StartupScanner: Sendable {
    private static let printConcurrency = 8

    private let launchctl: LaunchctlService
    private let parser: PlistParser
    private let bundleResolver: AppBundleResolver
    private let modernScanner: ModernStartupScanner
    private let merger: StartupItemMerger

    init(
        launchctl: LaunchctlService = LaunchctlService(),
        parser: PlistParser = PlistParser(),
        bundleResolver: AppBundleResolver = AppBundleResolver(),
        modernScanner: ModernStartupScanner = ModernStartupScanner(),
        merger: StartupItemMerger = StartupItemMerger()
    ) {
        self.launchctl = launchctl
        self.parser = parser
        self.bundleResolver = bundleResolver
        self.modernScanner = modernScanner
        self.merger = merger
    }

    func scan() async -> [StartupItem] {
        await scanResult(includeSystemItems: false).items
    }

    func scanResult(includeSystemItems: Bool = false) async -> ScanResult {
        let uid = getuid()
        let guiDomain = "gui/\(uid)"

        async let guiDisabledResult = launchctl.printDisabled(domain: guiDomain)
        let discovered = discoverItems(includeSystemItems: includeSystemItems)

        let guiDisabled: LaunchctlResult
        let systemDisabled: LaunchctlResult
        if includeSystemItems {
            (guiDisabled, systemDisabled) = await (guiDisabledResult, launchctl.printDisabled(domain: "system"))
        } else {
            guiDisabled = await guiDisabledResult
            systemDisabled = LaunchctlResult(command: "", exitCode: 0, stdout: "", stderr: "")
        }
        let disabledGUI = launchctl.parseDisabledLabels(from: guiDisabled.stdout)
        let disabledSystem = includeSystemItems
            ? launchctl.parseDisabledLabels(from: systemDisabled.stdout)
            : []

        var traditional: [StartupItem] = []
        traditional.reserveCapacity(discovered.count)

        for batch in discovered.chunked(into: Self.printConcurrency) {
            let batchItems = await withTaskGroup(of: StartupItem.self, returning: [StartupItem].self) { group in
                for item in batch {
                    group.addTask {
                        await self.makeItem(
                            discovered: item,
                            disabledGUI: disabledGUI,
                            disabledSystem: disabledSystem
                        )
                    }
                }

                var collected: [StartupItem] = []
                collected.reserveCapacity(batch.count)
                for await item in group {
                    collected.append(item)
                }
                return collected
            }
            traditional.append(contentsOf: batchItems)
        }

        let modern = await Task.detached(priority: .userInitiated) { [modernScanner, includeSystemItems] in
            modernScanner.scan(includeSystemSources: includeSystemItems)
        }.value
        let merged = merger.merge(
            traditional: traditional,
            modern: modern.items,
            btmRecords: modern.btmRecords,
            helpersByParentPath: modern.helpersByParentPath
        )
        let systemLoadGranted = includeSystemItems
            ? Self.systemLaunchDirectoriesAccessible() && !systemDisabled.permissionDenied
            : true
        return ScanResult(
            items: merged,
            modernSourceWarning: modern.warning,
            systemLoadGranted: systemLoadGranted
        )
    }

    func refreshItem(_ item: StartupItem) async -> StartupItem? {
        guard item.type.supportsLaunchctl else {
            return item
        }
        let plistURL = URL(fileURLWithPath: item.plistPath)
        guard !item.plistPath.isEmpty, FileManager.default.fileExists(atPath: plistURL.path) else {
            return item
        }

        let uid = getuid()
        let guiDomain = "gui/\(uid)"

        async let guiDisabledResult = launchctl.printDisabled(domain: guiDomain)
        async let systemDisabledResult = launchctl.printDisabled(domain: "system")
        let (guiDisabled, systemDisabled) = await (guiDisabledResult, systemDisabledResult)

        let discovered = discoverItem(plistURL: URL(fileURLWithPath: item.plistPath), type: item.type)
        return await makeItem(
            discovered: discovered,
            disabledGUI: launchctl.parseDisabledLabels(from: guiDisabled.stdout),
            disabledSystem: launchctl.parseDisabledLabels(from: systemDisabled.stdout)
        )
    }

    static func scanDirectories(includeSystemItems: Bool = false) -> [ScanDirectory] {
        // Traditional launchd plists. Modern sources are merged afterwards.
        // System directories stay opt-in so opening the app does not trigger
        // administrator authentication.
        let home = FileManager.default.homeDirectoryForCurrentUser
        var directories = [
            ScanDirectory(
                url: home.appendingPathComponent("Library/LaunchAgents"),
                type: .userLaunchAgent
            )
        ]
        if includeSystemItems {
            directories.append(
                ScanDirectory(
                    url: URL(fileURLWithPath: "/Library/LaunchAgents"),
                    type: .systemLaunchAgent
                )
            )
            directories.append(
                ScanDirectory(
                    url: URL(fileURLWithPath: "/Library/LaunchDaemons"),
                    type: .launchDaemon
                )
            )
        }
        return directories
    }

    static func systemLaunchDirectoriesAccessible() -> Bool {
        [
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons"
        ].allSatisfy { FileManager.default.isReadableFile(atPath: $0) }
    }

    private func discoverItems(includeSystemItems: Bool) -> [DiscoveredLaunchItem] {
        Self.scanDirectories(includeSystemItems: includeSystemItems).flatMap { directory in
            plistFiles(in: directory).map { entry in
                discoverItem(plistURL: entry.url, type: entry.type)
            }
        }
    }

    private func discoverItem(plistURL: URL, type: StartupItemType) -> DiscoveredLaunchItem {
        do {
            let parsed = try parser.parse(url: plistURL)
            return DiscoveredLaunchItem(
                plistURL: plistURL,
                type: type,
                parsed: parsed,
                parseErrorDescription: nil
            )
        } catch {
            return DiscoveredLaunchItem(
                plistURL: plistURL,
                type: type,
                parsed: nil,
                parseErrorDescription: error.localizedDescription
            )
        }
    }

    private func plistFiles(in directory: ScanDirectory) -> [(url: URL, type: StartupItemType)] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory.url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { $0.pathExtension.lowercased() == "plist" }
            .map { (url: $0, type: directory.type) }
    }

    private func makeItem(
        discovered: DiscoveredLaunchItem,
        disabledGUI: Set<String>,
        disabledSystem: Set<String>
    ) async -> StartupItem {
        let plistPath = discovered.plistURL.path
        guard let parsed = discovered.parsed else {
            return StartupItem(
                id: plistPath,
                label: discovered.plistURL.deletingPathExtension().lastPathComponent,
                plistPath: plistPath,
                executablePath: nil,
                arguments: [],
                type: discovered.type,
                runAtLoad: false,
                keepAliveDescription: nil,
                executableExists: false,
                loadStatus: .error(discovered.parseErrorDescription ?? L10n.text("error.cannot_parse_plist")),
                workingDirectory: nil,
                environmentVariables: [:],
                standardOutPath: nil,
                standardErrorPath: nil,
                appDisplayName: nil,
                appBundleName: nil,
                appBundleIdentifier: nil,
                appBundlePath: nil,
                origin: .unknown,
                launchdLoaded: false,
                persistentlyDisabled: false
            )
        }

        let executablePath = parsed.executablePath
        let executableExists = executableExistsOnDisk(executablePath)
        let bundle = bundleResolver.resolve(executablePath: executablePath)
        let origin = ItemOrigin.classify(
            label: parsed.label,
            plistPath: plistPath,
            executablePath: executablePath
        )
        let disabledSet = discovered.type == .launchDaemon ? disabledSystem : disabledGUI
        let isDisabled = disabledSet.contains(parsed.label)
        let runtime = await runtimeState(label: parsed.label, type: discovered.type)
        let loadStatus = LoadStatusResolver.resolve(
            executableExists: executableExists,
            isDisabled: isDisabled,
            runtimeState: runtime
        )
        let isLoaded = (runtime == .loaded)

        logScan(
            label: parsed.label,
            domain: discovered.type.launchctlDomain ?? "",
            runtime: runtime,
            status: loadStatus
        )

        return StartupItem(
            id: plistPath,
            label: parsed.label,
            plistPath: plistPath,
            executablePath: executablePath,
            arguments: parsed.arguments,
            type: discovered.type,
            runAtLoad: parsed.runAtLoad,
            keepAliveDescription: parsed.keepAliveDescription,
            executableExists: executableExists,
            loadStatus: loadStatus,
            workingDirectory: parsed.workingDirectory,
            environmentVariables: parsed.environmentVariables,
            standardOutPath: parsed.standardOutPath,
            standardErrorPath: parsed.standardErrorPath,
            appDisplayName: emptyToNil(bundle.displayName),
            appBundleName: emptyToNil(bundle.bundleName),
            appBundleIdentifier: emptyToNil(bundle.bundleIdentifier),
            appBundlePath: bundle.bundlePath,
            origin: origin,
            launchdLoaded: isLoaded,
            persistentlyDisabled: isDisabled
        )
    }

    private func runtimeState(label: String, type: StartupItemType) async -> ServicePrintState {
        await launchctl.serviceState(domain: type.launchctlDomain ?? "gui/\(getuid())", label: label)
    }

    private func executableExistsOnDisk(_ path: String?) -> Bool {
        // TODO:
        // Improve ownership/orphan detection for wrapper executables such as
        // /usr/bin/open, /bin/sh, /usr/bin/env.
        guard let path, !path.isEmpty else {
            return false
        }
        return FileManager.default.fileExists(atPath: path)
    }

    private func emptyToNil(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private func logScan(
        label: String,
        domain: String,
        runtime: ServicePrintState,
        status: LoadStatus
    ) {
        #if DEBUG
        switch runtime {
        case .loaded:
            print("[Scan]\n\(label)\ndomain = \(domain)\nexitCode = 0\nstatus = loaded")
        case .notFound:
            print("[Scan]\n\(label)\ndomain = \(domain)\nexitCode = 113\nstatus = unloaded")
        case .error(let message):
            print("[Scan]\n\(label)\ndomain = \(domain)\nstatus = error\nstderr = \(message)")
        }
        _ = status
        #endif
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
