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
            reason: L10n.text("safety.reason.safe"),
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
            return L10n.text("safety.reason.apple_label")
        }
        if item.origin == .appleSystem {
            return L10n.text("safety.reason.apple_origin")
        }
        if isSIPProtected(item) {
            return L10n.text("safety.reason.sip_path")
        }
        if item.isSystemProtected {
            return L10n.text("safety.reason.system_protected")
        }
        return nil
    }

    private func reviewReason(_ item: StartupItem) -> String? {
        switch item.type {
        case .launchDaemon:
            return L10n.text("safety.reason.launch_daemon")
        case .systemLaunchAgent:
            return L10n.text("safety.reason.system_launch_agent")
        case .loginItem:
            return L10n.text("safety.reason.login_item")
        case .backgroundTask:
            return L10n.text("safety.reason.background_task")
        case .smAppService:
            return L10n.text("safety.reason.smappservice")
        case .userLaunchAgent:
            break
        }

        if item.origin == .unknown {
            return L10n.text("safety.reason.origin_unknown")
        }
        if item.executableExists {
            return L10n.text("safety.reason.executable_exists")
        }
        if appStillInstalled(item) {
            return L10n.text("safety.reason.app_still_installed")
        }
        if !item.loadStatus.isOrphaned {
            return L10n.text("safety.reason.not_orphaned")
        }
        if hasKeepAlive(item) {
            return L10n.text("safety.reason.keepalive")
        }
        if looksLikeUpdaterOrHelper(item) {
            return L10n.text("safety.reason.updater_helper")
        }
        return nil
    }

    private func missingSafeRequirement(_ item: StartupItem) -> String? {
        guard item.type == .userLaunchAgent else {
            return L10n.text("safety.reason.only_user_launch_agent")
        }
        guard item.origin == .thirdParty else {
            return L10n.text("safety.reason.only_third_party")
        }
        guard item.loadStatus.isOrphaned else {
            return L10n.text("safety.reason.only_orphaned")
        }
        guard !item.executableExists else {
            return L10n.text("safety.reason.executable_still_exists_short")
        }
        guard FileManager.default.fileExists(atPath: item.plistPath) else {
            return L10n.text("safety.reason.plist_missing")
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
