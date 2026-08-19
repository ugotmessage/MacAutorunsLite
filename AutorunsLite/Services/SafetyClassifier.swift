import Foundation

struct SafetyClassifier: Sendable {
    func classify(_ item: StartupItem) -> SafetyVerdict {
        if let protected = protectedReason(item) {
            return SafetyVerdict(classification: .protected, reason: protected, item: item)
        }
        if let review = reviewReason(item) {
            return SafetyVerdict(classification: .reviewRequired, reason: review, item: item)
        }
        if let unsafe = missingSafeRequirement(item) {
            return SafetyVerdict(classification: .reviewRequired, reason: unsafe, item: item)
        }
        return SafetyVerdict(
            classification: .safe,
            reason: "殘留的第三方 User LaunchAgent，執行檔已不存在，可停用並保留 plist。",
            item: item
        )
    }

    func dryRun(items: [StartupItem]) -> SafeActionDryRun {
        SafeActionDryRun(
            generatedAt: Date(),
            verdicts: items.map(classify)
        )
    }

    private func protectedReason(_ item: StartupItem) -> String? {
        if item.label.lowercased().hasPrefix("com.apple.") {
            return "Apple 系統項目，禁止自動處理。"
        }
        if item.origin == .appleSystem {
            return "Apple/System 來源，禁止自動處理。"
        }
        if isSIPProtected(item) {
            return "位於系統保護路徑，禁止自動處理。"
        }
        if item.isSystemProtected {
            return "受保護的系統項目，禁止自動處理。"
        }
        return nil
    }

    private func reviewReason(_ item: StartupItem) -> String? {
        switch item.type {
        case .launchDaemon:
            return "LaunchDaemon 可能需要管理者權限，改列入手動確認。"
        case .systemLaunchAgent:
            return "System LaunchAgent 不納入自動處理。"
        case .userLaunchAgent:
            break
        }

        if item.origin == .unknown {
            return "來源無法完全判斷，改列入手動確認。"
        }
        if item.executableExists {
            return "執行檔仍存在，不自動處理。"
        }
        if appStillInstalled(item) {
            return "App 仍安裝，改列入手動確認。"
        }
        if !item.loadStatus.isOrphaned {
            return "不是殘留項目，只提供建議、不自動執行。"
        }
        if hasKeepAlive(item) {
            return "KeepAlive 項目改列入手動確認。"
        }
        if looksLikeUpdaterOrHelper(item) {
            return "名稱類似 updater / helper，改列入手動確認。"
        }
        return nil
    }

    private func missingSafeRequirement(_ item: StartupItem) -> String? {
        guard item.type == .userLaunchAgent else {
            return "僅優先處理 User LaunchAgent。"
        }
        guard item.origin == .thirdParty else {
            return "僅處理可判定的第三方項目。"
        }
        guard item.loadStatus.isOrphaned else {
            return "僅處理殘留項目。"
        }
        guard !item.executableExists else {
            return "執行檔仍存在。"
        }
        guard FileManager.default.fileExists(atPath: item.plistPath) else {
            return "plist 已不存在，無法安全處理。"
        }
        return nil
    }

    private func isSIPProtected(_ item: StartupItem) -> Bool {
        let paths = [item.plistPath, item.executablePath].compactMap { $0 }
        return paths.contains { path in
            path.hasPrefix("/System/")
                || path.hasPrefix("/usr/bin/")
                || path.hasPrefix("/usr/sbin/")
                || path.hasPrefix("/usr/libexec/")
                || path.hasPrefix("/bin/")
                || path.hasPrefix("/sbin/")
                || path.hasPrefix("/Library/Apple/")
        }
    }

    private func hasKeepAlive(_ item: StartupItem) -> Bool {
        guard let keepAlive = item.keepAliveDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
              !keepAlive.isEmpty
        else {
            return false
        }
        let normalized = keepAlive.lowercased()
        return normalized != "no" && normalized != "否" && normalized != "false"
    }

    private func looksLikeUpdaterOrHelper(_ item: StartupItem) -> Bool {
        let haystack = [
            item.label,
            item.plistPath,
            item.executablePath ?? "",
            item.displayName
        ].joined(separator: " ").lowercased()
        return haystack.contains("updater") || haystack.contains("helper")
    }

    private func appStillInstalled(_ item: StartupItem) -> Bool {
        guard let bundlePath = item.appBundlePath, !bundlePath.isEmpty else {
            return false
        }
        return FileManager.default.fileExists(atPath: bundlePath)
    }
}
