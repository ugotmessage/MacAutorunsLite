import Foundation

struct ScanDirectory: Sendable {
    let url: URL
    let type: StartupItemType
}

final class StartupScanner: Sendable {
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
        async let guiPrintResult = launchctl.printDomain(guiDomain)
        async let systemPrintResult = launchctl.printDomain("system")

        let (guiDisabled, systemDisabled, guiPrint, systemPrint) = await (
            guiDisabledResult,
            systemDisabledResult,
            guiPrintResult,
            systemPrintResult
        )

        let disabledGUI = launchctl.parseDisabledLabels(from: guiDisabled.stdout)
        let disabledSystem = launchctl.parseDisabledLabels(from: systemDisabled.stdout)
        let loadedGUI = launchctl.parseLoadedLabels(from: guiPrint.stdout)
        let loadedSystem = launchctl.parseLoadedLabels(from: systemPrint.stdout)

        let discovered = Self.scanDirectories().flatMap { plistFiles(in: $0) }

        let items = discovered.compactMap { entry in
            makeItem(
                plistURL: entry.url,
                type: entry.type,
                disabledGUI: disabledGUI,
                disabledSystem: disabledSystem,
                loadedGUI: loadedGUI,
                loadedSystem: loadedSystem
            )
        }

        return items.sortedForDisplay()
    }

    func refreshItem(_ item: StartupItem) async -> StartupItem? {
        let uid = getuid()
        let guiDomain = "gui/\(uid)"
        let domain = item.type.launchctlDomain

        async let guiDisabledResult = launchctl.printDisabled(domain: guiDomain)
        async let systemDisabledResult = launchctl.printDisabled(domain: "system")
        async let printResult = launchctl.printService(domain: domain, label: item.label)
        let (guiDisabled, systemDisabled, printed) = await (
            guiDisabledResult,
            systemDisabledResult,
            printResult
        )

        var loadedGUI = Set<String>()
        var loadedSystem = Set<String>()
        if printed.succeeded {
            if item.type == .launchDaemon {
                loadedSystem.insert(item.label)
            } else {
                loadedGUI.insert(item.label)
            }
        }

        return makeItem(
            plistURL: URL(fileURLWithPath: item.plistPath),
            type: item.type,
            disabledGUI: launchctl.parseDisabledLabels(from: guiDisabled.stdout),
            disabledSystem: launchctl.parseDisabledLabels(from: systemDisabled.stdout),
            loadedGUI: loadedGUI,
            loadedSystem: loadedSystem
        )
    }

    static func scanDirectories() -> [ScanDirectory] {
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
        plistURL: URL,
        type: StartupItemType,
        disabledGUI: Set<String>,
        disabledSystem: Set<String>,
        loadedGUI: Set<String>,
        loadedSystem: Set<String>
    ) -> StartupItem? {
        let plistPath = plistURL.path
        let parsed: ParsedLaunchPlist
        do {
            parsed = try parser.parse(url: plistURL)
        } catch {
            return StartupItem(
                id: plistPath,
                label: plistURL.deletingPathExtension().lastPathComponent,
                plistPath: plistPath,
                executablePath: nil,
                arguments: [],
                type: type,
                runAtLoad: false,
                keepAliveDescription: nil,
                executableExists: false,
                loadStatus: .error(error.localizedDescription),
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

        let disabledSet = type == .launchDaemon ? disabledSystem : disabledGUI
        let loadedSet = type == .launchDaemon ? loadedSystem : loadedGUI
        let isLoaded = loadedSet.contains(parsed.label)
        let loadStatus = LoadStatusResolver.resolve(
            executableExists: executableExists,
            isDisabled: disabledSet.contains(parsed.label),
            printSucceeded: isLoaded,
            printOutput: isLoaded ? "" : "Could not find service \"\(parsed.label)\" in domain",
            exitCode: isLoaded ? 0 : 113
        )

        return StartupItem(
            id: plistPath,
            label: parsed.label,
            plistPath: plistPath,
            executablePath: executablePath,
            arguments: parsed.arguments,
            type: type,
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
            persistentlyDisabled: disabledSet.contains(parsed.label)
        )
    }

    private func executableExistsOnDisk(_ path: String?) -> Bool {
        guard let path, !path.isEmpty else {
            return false
        }
        return FileManager.default.fileExists(atPath: path)
    }

    private func emptyToNil(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
