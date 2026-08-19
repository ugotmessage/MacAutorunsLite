import Foundation
import CoreServices

protocol LoginItemListing: Sendable {
    func loginItemURLs() -> [URL]
}

struct SharedFileListLoginItems: LoginItemListing {
    func loginItemURLs() -> [URL] {
        sessionLoginItemURLs()
    }

    private func sessionLoginItemURLs() -> [URL] {
        let listName = kLSSharedFileListSessionLoginItems.takeUnretainedValue()
        guard let list = LSSharedFileListCreate(nil, listName, nil)?.takeRetainedValue() else {
            return []
        }
        var seed: UInt32 = 0
        guard let snapshot = LSSharedFileListCopySnapshot(list, &seed)?.takeRetainedValue() as? [LSSharedFileListItem] else {
            return []
        }

        var urls: [URL] = []
        urls.reserveCapacity(snapshot.count)
        for item in snapshot {
            var cfError: Unmanaged<CFError>?
            if let resolved = LSSharedFileListItemCopyResolvedURL(item, 0, &cfError)?.takeRetainedValue() {
                urls.append(resolved as URL)
            }
        }
        return urls
    }
}

struct EmptyLoginItemListing: LoginItemListing {
    func loginItemURLs() -> [URL] { [] }
}

struct LoginItemScanner: Sendable {
    private let listing: LoginItemListing
    private let bundleResolver: AppBundleResolver

    init(
        listing: LoginItemListing? = nil,
        bundleResolver: AppBundleResolver = AppBundleResolver()
    ) {
        if let listing {
            self.listing = listing
        } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            self.listing = EmptyLoginItemListing()
        } else {
            self.listing = SharedFileListLoginItems()
        }
        self.bundleResolver = bundleResolver
    }

    func scan() -> [StartupItem] {
        listing.loginItemURLs().compactMap(makeItem(url:))
    }

    private func makeItem(url: URL) -> StartupItem? {
        let path = url.path
        guard !path.hasPrefix("/System/") else { return nil }

        let bundle = Bundle(url: url.pathExtension.lowercased() == "app" ? url : (bundleResolver.bundleURL(containingExecutable: path) ?? url))
        let bundleURL = bundle?.bundleURL ?? url
        let executable = bundle?.executableURL?.path
        let exists = FileManager.default.fileExists(atPath: path)
        let identifier = bundle?.bundleIdentifier ?? url.lastPathComponent
        let origin = ItemOrigin.classify(
            label: identifier,
            plistPath: path,
            executablePath: executable ?? path
        )
        let parent = ParentAppResolver.parentApp(for: path)

        return StartupItem(
            id: "source:loginItem:\(path)",
            label: identifier,
            plistPath: "",
            executablePath: executable ?? path,
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
            appDisplayName: bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            appBundleName: bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? bundleURL.deletingPathExtension().lastPathComponent,
            appBundleIdentifier: bundle?.bundleIdentifier,
            appBundlePath: bundleURL.path,
            origin: origin,
            launchdLoaded: false,
            persistentlyDisabled: false,
            parentBundleIdentifier: parent.bundleIdentifier,
            parentDisplayName: parent.displayName,
            sourceURL: path
        )
    }
}

enum ParentAppResolver {
    struct ParentApp {
        var path: String?
        var bundleIdentifier: String?
        var displayName: String?
    }

    static func parentApp(for path: String) -> ParentApp {
        let markers = [
            "/Contents/Library/LoginItems/",
            "/Contents/Library/LaunchAgents/",
            "/Contents/Library/LaunchDaemons/",
            "/Contents/XPCServices/"
        ]
        for marker in markers {
            if let range = path.range(of: marker) {
                let parentPath = String(path[..<range.lowerBound])
                if parentPath.lowercased().hasSuffix(".app") {
                    return info(for: parentPath)
                }
            }
        }

        var url = URL(fileURLWithPath: path)
        while url.path != "/" && !url.path.isEmpty {
            if url.pathExtension.lowercased() == "app" {
                return info(for: url.path)
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return ParentApp()
    }

    private static func info(for appPath: String) -> ParentApp {
        let bundle = Bundle(url: URL(fileURLWithPath: appPath))
        return ParentApp(
            path: appPath,
            bundleIdentifier: bundle?.bundleIdentifier,
            displayName: (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
        )
    }
}
