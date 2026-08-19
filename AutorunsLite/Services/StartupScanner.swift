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

    init(
        launchctl: LaunchctlService = LaunchctlService(),
        parser: PlistParser = PlistParser(),
        bundleResolver: AppBundleResolver = AppBundleResolver()
    ) {
        self.launchctl = launchctl
        self.parser = parser
        self.bundleResolver = bundleResolver
    }

    func scan() async -> [StartupItem] {
        let uid = getuid()
        let guiDomain = "gui/\(uid)"

        async let guiDisabledResult = launchctl.printDisabled(domain: guiDomain)
        async let systemDisabledResult = launchctl.printDisabled(domain: "system")

        let discovered = discoverItems()

        let (guiDisabled, systemDisabled) = await (guiDisabledResult, systemDisabledResult)
        let disabledGUI = launchctl.parseDisabledLabels(from: guiDisabled.stdout)
        let disabledSystem = launchctl.parseDisabledLabels(from: systemDisabled.stdout)

        var items: [StartupItem] = []
        items.reserveCapacity(discovered.count)

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
            items.append(contentsOf: batchItems)
        }

        return items.sortedForDisplay()
    }

    func refreshItem(_ item: StartupItem) async -> StartupItem? {
        let plistURL = URL(fileURLWithPath: item.plistPath)
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            return nil
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

    static func scanDirectories() -> [ScanDirectory] {
        // Scan scope is traditional launchd plists only:
        // ~/Library/LaunchAgents, /Library/LaunchAgents, /Library/LaunchDaemons.
        // SMAppService / Login Items / Background Tasks are not scanned, so a loaded
        // launchd service without a matching plist here may not appear.
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ScanDirectory(
                url: home.appendingPathComponent("Library/LaunchAgents"),
                type: .userLaunchAgent
            ),
            ScanDirectory(
                url: URL(fileURLWithPath: "/Library/LaunchAgents"),
                type: .systemLaunchAgent
            ),
            ScanDirectory(
                url: URL(fileURLWithPath: "/Library/LaunchDaemons"),
                type: .launchDaemon
            )
        ]
    }

    private func discoverItems() -> [DiscoveredLaunchItem] {
        Self.scanDirectories().flatMap { directory in
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
                loadStatus: .error(discovered.parseErrorDescription ?? "無法解析 plist"),
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
            domain: discovered.type.launchctlDomain,
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
        await launchctl.serviceState(domain: type.launchctlDomain, label: label)
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
