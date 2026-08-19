import Foundation

struct ScanResult: Sendable {
    let items: [StartupItem]
    let modernSourceWarning: String?
    /// When a system scan was requested, indicates launchd/BTM prerequisites succeeded.
    let systemLoadGranted: Bool
}

struct ModernScanResult: Sendable {
    let items: [StartupItem]
    let btmRecords: [BTMRecord]
    let helpersByParentPath: [String: [RelatedHelper]]
    let warning: String?
}

struct ModernStartupScanner: Sendable {
    var loginItemScanner: LoginItemScanner
    var bundleHelperScanner: AppBundleHelperScanner
    var dumpParser: BTMDumpParser
    var dumpProvider: () -> String?
    var fileManager: FileManager

    init(
        loginItemScanner: LoginItemScanner = LoginItemScanner(),
        bundleHelperScanner: AppBundleHelperScanner = AppBundleHelperScanner(),
        dumpParser: BTMDumpParser = BTMDumpParser(),
        dumpProvider: (() -> String?)? = nil,
        fileManager: FileManager = .default
    ) {
        self.loginItemScanner = loginItemScanner
        self.bundleHelperScanner = bundleHelperScanner
        self.dumpParser = dumpParser
        self.dumpProvider = dumpProvider ?? { ModernStartupScanner.readDumpBTM() }
        self.fileManager = fileManager
    }

    func scan(includeSystemSources: Bool = false) -> ModernScanResult {
        let loginItems = loginItemScanner.scan()
        let bundleScan = bundleHelperScanner.scan()
        var warning: String?
        var records: [BTMRecord] = []

        if includeSystemSources {
            if let dump = dumpProvider() {
                records = dumpParser.parse(dump)
            } else {
                warning = L10n.text("scan.background_task_warning")
            }
        }

        let combined = loginItems + bundleScan.items
        return ModernScanResult(
            items: combined,
            btmRecords: records,
            helpersByParentPath: bundleScan.helpersByParentPath,
            warning: warning
        )
    }

    static func readDumpBTM() -> String? {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return nil
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sfltool")
        process.arguments = ["dumpbtm"]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return readBTMFileIfPresent()
        }

        let deadline = Date().addingTimeInterval(4)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return readBTMFileIfPresent()
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus == 0, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return readBTMFileIfPresent()
    }

    private static func readBTMFileIfPresent() -> String? {
        let directory = URL(fileURLWithPath: "/private/var/db/com.apple.backgroundtaskmanagement")
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        // Binary BTM files are not parsed in v0.2.0; presence without dumpbtm
        // still cannot yield records. Returning nil triggers the UI warning.
        _ = contents.first { $0.pathExtension == "btm" }
        return nil
    }
}
