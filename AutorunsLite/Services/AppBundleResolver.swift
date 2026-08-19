import Foundation

struct AppBundleInfo: Equatable, Sendable {
    let displayName: String?
    let bundleName: String?
    let bundleIdentifier: String?
    let bundlePath: String?
    let iconFile: String?
}

struct AppBundleResolver: Sendable {
    func resolve(executablePath: String?) -> AppBundleInfo {
        guard let executablePath, !executablePath.isEmpty else {
            return AppBundleInfo(
                displayName: nil,
                bundleName: nil,
                bundleIdentifier: nil,
                bundlePath: nil,
                iconFile: nil
            )
        }

        guard let bundleURL = bundleURL(containingExecutable: executablePath) else {
            return AppBundleInfo(
                displayName: nil,
                bundleName: nil,
                bundleIdentifier: nil,
                bundlePath: nil,
                iconFile: nil
            )
        }

        let bundle = Bundle(url: bundleURL)
        return AppBundleInfo(
            displayName: bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            bundleName: bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
            bundleIdentifier: bundle?.bundleIdentifier,
            bundlePath: bundleURL.path,
            iconFile: bundle?.object(forInfoDictionaryKey: "CFBundleIconFile") as? String
        )
    }

    func bundleURL(containingExecutable path: String) -> URL? {
        var url = URL(fileURLWithPath: path)
        while url.path != "/" && !url.path.isEmpty {
            if url.pathExtension.lowercased() == "app" {
                return url
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                break
            }
            url = parent
        }
        return nil
    }
}
