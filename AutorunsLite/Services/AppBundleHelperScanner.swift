import Foundation

struct AppBundleHelperScan: Sendable {
    var items: [StartupItem]
    var helpersByParentPath: [String: [RelatedHelper]]
}

struct AppBundleHelperScanner: Sendable {
    var applicationDirectories: [URL]

    init(applicationDirectories: [URL]? = nil) {
        if let applicationDirectories {
            self.applicationDirectories = applicationDirectories
        } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            self.applicationDirectories = []
        } else {
            var directories = [URL(fileURLWithPath: "/Applications")]
            let homeApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            directories.append(homeApps)
            self.applicationDirectories = directories
        }
    }

    func scan() -> AppBundleHelperScan {
        var items: [StartupItem] = []
        var helpersByParent: [String: [RelatedHelper]] = [:]

        for directory in applicationDirectories {
            for appURL in appBundles(in: directory) {
                let parent = ParentAppResolver.parentApp(for: appURL.path)
                let parentPath = normalizedPath(appURL)
                var related: [RelatedHelper] = []

                for loginURL in contents(of: appURL.appendingPathComponent("Contents/Library/LoginItems"), extensions: ["app"]) {
                    related.append(
                        RelatedHelper(
                            name: loginURL.deletingPathExtension().lastPathComponent,
                            path: loginURL.path,
                            kind: .loginItem,
                            bundleIdentifier: Bundle(url: loginURL)?.bundleIdentifier
                        )
                    )
                    items.append(makeLoginItem(at: loginURL, parentApp: appURL, parent: parent))
                }

                for plistURL in contents(of: appURL.appendingPathComponent("Contents/Library/LaunchAgents"), extensions: ["plist"]) {
                    related.append(
                        RelatedHelper(
                            name: plistURL.deletingPathExtension().lastPathComponent,
                            path: plistURL.path,
                            kind: .smPlist,
                            bundleIdentifier: parent.bundleIdentifier
                        )
                    )
                    items.append(makeSMAppService(at: plistURL, parentApp: appURL, parent: parent, daemon: false))
                }

                for plistURL in contents(of: appURL.appendingPathComponent("Contents/Library/LaunchDaemons"), extensions: ["plist"]) {
                    related.append(
                        RelatedHelper(
                            name: plistURL.deletingPathExtension().lastPathComponent,
                            path: plistURL.path,
                            kind: .smPlist,
                            bundleIdentifier: parent.bundleIdentifier
                        )
                    )
                    items.append(makeSMAppService(at: plistURL, parentApp: appURL, parent: parent, daemon: true))
                }

                for xpcURL in contents(of: appURL.appendingPathComponent("Contents/XPCServices"), extensions: ["xpc"]) {
                    related.append(
                        RelatedHelper(
                            name: xpcURL.deletingPathExtension().lastPathComponent,
                            path: xpcURL.path,
                            kind: .xpc,
                            bundleIdentifier: Bundle(url: xpcURL)?.bundleIdentifier
                        )
                    )
                }

                if !related.isEmpty {
                    helpersByParent[parentPath, default: []].append(contentsOf: related)
                }
            }
        }

        let attached = items.map { item in
            let parentPath = item.appBundlePath ?? ParentAppResolver.parentApp(for: item.resolvedSourcePath).path
            let extra = helpers(from: helpersByParent, parentPath: parentPath)
            return extra.isEmpty ? item : item.enriching(relatedHelpers: extra)
        }

        return AppBundleHelperScan(items: attached, helpersByParentPath: helpersByParent)
    }

    private func appBundles(in directory: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.filter { $0.pathExtension.lowercased() == "app" }
    }

    private func contents(of directory: URL, extensions: Set<String>) -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return files.filter { extensions.contains($0.pathExtension.lowercased()) }
    }

    private func makeLoginItem(at url: URL, parentApp: URL, parent: ParentAppResolver.ParentApp) -> StartupItem {
        let bundle = Bundle(url: url)
        let identifier = bundle?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
        let exists = FileManager.default.fileExists(atPath: url.path)
        return StartupItem(
            id: "source:loginItem:\(url.path)",
            label: identifier,
            plistPath: "",
            executablePath: bundle?.executableURL?.path ?? url.path,
            arguments: [],
            type: .loginItem,
            runAtLoad: true,
            keepAliveDescription: nil,
            executableExists: exists,
            loadStatus: exists ? .unknown : .orphaned,
            workingDirectory: nil,
            environmentVariables: [:],
            standardOutPath: nil,
            standardErrorPath: nil,
            appDisplayName: bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? parent.displayName,
            appBundleName: bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent,
            appBundleIdentifier: bundle?.bundleIdentifier ?? parent.bundleIdentifier,
            appBundlePath: normalizedPath(parentApp),
            origin: ItemOrigin.classify(label: identifier, plistPath: url.path, executablePath: url.path),
            launchdLoaded: false,
            persistentlyDisabled: false,
            parentBundleIdentifier: parent.bundleIdentifier,
            parentDisplayName: parent.displayName,
            associatedBundleIDs: [parent.bundleIdentifier].compactMap { $0 },
            sourceURL: url.path
        )
    }

    private func makeSMAppService(at url: URL, parentApp: URL, parent: ParentAppResolver.ParentApp, daemon: Bool) -> StartupItem {
        let parsed = try? PlistParser().parse(url: url)
        let label = parsed?.label ?? url.deletingPathExtension().lastPathComponent
        let executable = parsed?.executablePath
        let resolvedExecutable = resolvedPath(executable, relativeTo: parentApp)
        let exists = resolvedExecutable.map { FileManager.default.fileExists(atPath: $0) } ?? FileManager.default.fileExists(atPath: url.path)
        return StartupItem(
            id: "source:smAppService:\(url.path)",
            label: label,
            plistPath: url.path,
            executablePath: resolvedExecutable,
            arguments: parsed?.arguments ?? [],
            type: .smAppService,
            runAtLoad: parsed?.runAtLoad ?? false,
            keepAliveDescription: parsed?.keepAliveDescription,
            executableExists: exists,
            loadStatus: exists ? .unknown : .orphaned,
            workingDirectory: parsed?.workingDirectory,
            environmentVariables: parsed?.environmentVariables ?? [:],
            standardOutPath: parsed?.standardOutPath,
            standardErrorPath: parsed?.standardErrorPath,
            appDisplayName: parent.displayName,
            appBundleName: parentApp.deletingPathExtension().lastPathComponent,
            appBundleIdentifier: parent.bundleIdentifier,
            appBundlePath: normalizedPath(parentApp),
            origin: ItemOrigin.classify(label: label, plistPath: url.path, executablePath: resolvedExecutable),
            launchdLoaded: false,
            persistentlyDisabled: false,
            parentBundleIdentifier: parent.bundleIdentifier,
            parentDisplayName: parent.displayName,
            associatedBundleIDs: [parent.bundleIdentifier].compactMap { $0 },
            sourceURL: url.path
        )
    }

    private func resolvedPath(_ path: String?, relativeTo app: URL) -> String? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("/") { return path }
        return app.appendingPathComponent(path).path
    }

    private func normalizedPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func helpers(from map: [String: [RelatedHelper]], parentPath: String?) -> [RelatedHelper] {
        guard let parentPath, !parentPath.isEmpty else { return [] }
        if let exact = map[parentPath] { return exact }
        let resolved = URL(fileURLWithPath: parentPath).resolvingSymlinksInPath().standardizedFileURL.path
        if let match = map[resolved] { return match }
        return map.first {
            URL(fileURLWithPath: $0.key).resolvingSymlinksInPath().standardizedFileURL.path == resolved
        }?.value ?? []
    }
}
