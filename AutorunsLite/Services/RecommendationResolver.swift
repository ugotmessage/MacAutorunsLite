import Foundation

struct RecommendationResolver: Sendable {
    private let safetyClassifier: SafetyClassifier

    init(safetyClassifier: SafetyClassifier = SafetyClassifier()) {
        self.safetyClassifier = safetyClassifier
    }

    func resolve(_ item: StartupItem) -> RecommendationResult {
        let safety = safetyClassifier.classify(item)

        switch safety.classification {
        case .safe:
            return RecommendationResult(
                recommendation: .safeAction,
                reason: "此項目符合 MacAutorunsLite 的保守安全條件。可停止並停用自動載入，原始 plist 仍保留，並可透過 Snapshot 復原。",
                evidence: safeActionEvidence(item)
            )
        case .protected:
            return RecommendationResult(
                recommendation: .protected,
                reason: "此項目屬於 Apple 或 macOS 系統服務，MacAutorunsLite 不提供自動停用或刪除操作。",
                evidence: ["Apple 或系統保護項目", "不自動停用", "不自動刪除"]
            )
        case .reviewRequired:
            return refineReview(item, safetyReason: safety.reason)
        }
    }

    private func refineReview(_ item: StartupItem, safetyReason: String) -> RecommendationResult {
        if isErrorStatus(item.loadStatus) {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: "此項目發生錯誤，不得自動處理。",
                evidence: ["狀態為錯誤", safetyReason]
            )
        }
        if item.loadStatus == .unknown {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: "目前資訊不足，無法安全判斷，必須列入人工確認。",
                evidence: ["狀態為未知", "不應自動停用或刪除"]
            )
        }
        if looksLikeUpdaterOrHelper(item) {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: "此項目名稱包含 Updater 或 Helper，可能仍由已安裝 App 使用，因此不自動處理。",
                evidence: ["名稱類似 updater / helper", safetyReason]
            )
        }
        if hasKeepAlive(item) {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: "此項目啟用 KeepAlive，可能被設計成持續維持，因此改列入手動確認。",
                evidence: ["KeepAlive", safetyReason]
            )
        }
        if item.type == .launchDaemon {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: "LaunchDaemon 是系統層級背景服務，可能需要管理者權限，因此不自動處理。",
                evidence: ["類型為 LaunchDaemon", safetyReason]
            )
        }
        if item.type == .systemLaunchAgent {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: "System LaunchAgent 不納入自動處理，建議先確認來源後再決定。",
                evidence: ["類型為 System LaunchAgent", safetyReason]
            )
        }
        if item.origin == .unknown {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: "來源無法完全判斷，因此不自動停用或刪除。",
                evidence: ["來源未知", safetyReason]
            )
        }
        if item.loadStatus.isOrphaned, appStillInstalled(item) {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: "plist 指向的執行檔已不存在，但相關 App 仍安裝，可能只是路徑變更，因此不自動處理。",
                evidence: ["狀態為殘留", "App 仍安裝"]
            )
        }
        if isHealthyInstalledItem(item) {
            return keepResult(for: item)
        }
        if canConsiderDisable(item) {
            return RecommendationResult(
                recommendation: .canDisable,
                reason: "此項目仍屬於已安裝 App。若你不希望它自動啟動，可以選擇停用，但不建議直接刪除 plist。",
                evidence: ["第三方 User LaunchAgent", "執行檔仍存在", "App 仍安裝", "刪除不是必要動作"]
            )
        }

        return RecommendationResult(
            recommendation: .reviewRequired,
            reason: safetyReason,
            evidence: [safetyReason]
        )
    }

    private func keepResult(for item: StartupItem) -> RecommendationResult {
        switch item.loadStatus {
        case .unloaded:
            return RecommendationResult(
                recommendation: .keep,
                reason: "此項目目前未由 launchd 載入，但相關 App 與執行檔仍存在。未載入本身不是刪除理由。",
                evidence: ["狀態為未載入", "執行檔仍存在", "相關 App 仍存在", "未載入不代表無用"]
            )
        case .disabled:
            return RecommendationResult(
                recommendation: .keep,
                reason: "此項目目前已停用，相關 App 仍存在。如果這是你的預期設定，不需要其他處理。",
                evidence: ["狀態為已停用", "執行檔仍存在", "相關 App 仍存在"]
            )
        default:
            return RecommendationResult(
                recommendation: .keep,
                reason: "此項目屬於目前仍安裝的 App，建議保留。",
                evidence: ["執行檔仍存在", "相關 App 仍存在", "不是殘留項目"]
            )
        }
    }

    private func isHealthyInstalledItem(_ item: StartupItem) -> Bool {
        guard item.type == .userLaunchAgent else { return false }
        guard item.origin == .thirdParty else { return false }
        guard item.executableExists else { return false }
        guard !item.loadStatus.isOrphaned else { return false }
        guard !looksLikeUpdaterOrHelper(item) else { return false }
        guard !hasKeepAlive(item) else { return false }
        return true
    }

    private func canConsiderDisable(_ item: StartupItem) -> Bool {
        item.type == .userLaunchAgent
            && item.origin == .thirdParty
            && item.executableExists
            && appStillInstalled(item)
            && !item.isSystemProtected
            && !item.loadStatus.isOrphaned
    }

    private func isErrorStatus(_ status: LoadStatus) -> Bool {
        if case .error = status { return true }
        return false
    }

    private func appStillInstalled(_ item: StartupItem) -> Bool {
        guard let bundlePath = item.appBundlePath, !bundlePath.isEmpty else {
            return false
        }
        return FileManager.default.fileExists(atPath: bundlePath)
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

    private func safeActionEvidence(_ item: StartupItem) -> [String] {
        var evidence = [
            "第三方 User LaunchAgent",
            "執行檔已不存在",
            "非 Apple/System",
            "非 KeepAlive"
        ]
        if !appStillInstalled(item) {
            evidence.insert("App 已不存在", at: 2)
        }
        return evidence
    }
}
