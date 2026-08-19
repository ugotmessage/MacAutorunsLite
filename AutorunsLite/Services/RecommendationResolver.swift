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
                reason: L10n.text("recommendation.reason.safe_action"),
                evidence: safeActionEvidence(item)
            )
        case .protected:
            return RecommendationResult(
                recommendation: .protected,
                reason: L10n.text("recommendation.reason.protected"),
                evidence: [
                    L10n.text("recommendation.evidence.apple_or_system_protected"),
                    L10n.text("recommendation.evidence.no_auto_disable"),
                    L10n.text("recommendation.evidence.no_auto_delete")
                ]
            )
        case .reviewRequired:
            return refineReview(item, safetyReason: safety.reason)
        }
    }

    private func refineReview(_ item: StartupItem, safetyReason: String) -> RecommendationResult {
        if isErrorStatus(item.loadStatus) {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: L10n.text("recommendation.reason.error"),
                evidence: [L10n.text("recommendation.evidence.status_error"), safetyReason]
            )
        }
        if item.loadStatus == .unknown {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: L10n.text("recommendation.reason.unknown"),
                evidence: [
                    L10n.text("recommendation.evidence.status_unknown"),
                    L10n.text("recommendation.evidence.do_not_auto_disable_or_delete")
                ]
            )
        }
        if looksLikeUpdaterOrHelper(item) {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: L10n.text("recommendation.reason.updater_helper"),
                evidence: [L10n.text("recommendation.evidence.looks_like_updater_helper"), safetyReason]
            )
        }
        if hasKeepAlive(item) {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: L10n.text("recommendation.reason.keepalive"),
                evidence: [L10n.text("recommendation.evidence.keepalive"), safetyReason]
            )
        }
        if item.type.isModernSource {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: L10n.text("recommendation.reason.modern_source"),
                evidence: [
                    L10n.text("recommendation.evidence.modern_source"),
                    L10n.text("recommendation.evidence.no_auto_disable"),
                    L10n.text("recommendation.evidence.no_auto_delete"),
                    safetyReason
                ]
            )
        }
        if item.type == .launchDaemon {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: L10n.text("recommendation.reason.launch_daemon"),
                evidence: [L10n.text("recommendation.evidence.type_launch_daemon"), safetyReason]
            )
        }
        if item.type == .systemLaunchAgent {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: L10n.text("recommendation.reason.system_launch_agent"),
                evidence: [L10n.text("recommendation.evidence.type_system_launch_agent"), safetyReason]
            )
        }
        if item.origin == .unknown {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: L10n.text("recommendation.reason.origin_unknown"),
                evidence: [L10n.text("recommendation.evidence.origin_unknown"), safetyReason]
            )
        }
        if item.loadStatus.isOrphaned, appStillInstalled(item) {
            return RecommendationResult(
                recommendation: .reviewRequired,
                reason: L10n.text("recommendation.reason.orphaned_app_still_installed"),
                evidence: [
                    L10n.text("recommendation.evidence.status_orphaned"),
                    L10n.text("recommendation.evidence.app_still_installed")
                ]
            )
        }
        if isHealthyInstalledItem(item) {
            return keepResult(for: item)
        }
        if canConsiderDisable(item) {
            return RecommendationResult(
                recommendation: .canDisable,
                reason: L10n.text("recommendation.reason.can_disable"),
                evidence: [
                    L10n.text("recommendation.evidence.third_party_user_launch_agent"),
                    L10n.text("recommendation.evidence.executable_exists"),
                    L10n.text("recommendation.evidence.app_still_installed"),
                    L10n.text("recommendation.evidence.delete_not_required")
                ]
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
                reason: L10n.text("recommendation.reason.keep_unloaded"),
                evidence: [
                    L10n.text("recommendation.evidence.status_unloaded"),
                    L10n.text("recommendation.evidence.executable_exists"),
                    L10n.text("recommendation.evidence.related_app_exists"),
                    L10n.text("recommendation.evidence.unloaded_not_unused")
                ]
            )
        case .disabled:
            return RecommendationResult(
                recommendation: .keep,
                reason: L10n.text("recommendation.reason.keep_disabled"),
                evidence: [
                    L10n.text("recommendation.evidence.status_disabled"),
                    L10n.text("recommendation.evidence.executable_exists"),
                    L10n.text("recommendation.evidence.related_app_exists")
                ]
            )
        default:
            return RecommendationResult(
                recommendation: .keep,
                reason: L10n.text("recommendation.reason.keep_default"),
                evidence: [
                    L10n.text("recommendation.evidence.executable_exists"),
                    L10n.text("recommendation.evidence.related_app_exists"),
                    L10n.text("recommendation.evidence.not_orphaned")
                ]
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
            L10n.text("recommendation.evidence.third_party_user_launch_agent"),
            L10n.text("recommendation.evidence.executable_missing"),
            L10n.text("recommendation.evidence.not_apple_system"),
            L10n.text("recommendation.evidence.not_keepalive")
        ]
        if !appStillInstalled(item) {
            evidence.insert(L10n.text("recommendation.evidence.app_missing"), at: 2)
        }
        return evidence
    }
}
