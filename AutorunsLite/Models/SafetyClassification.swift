import Foundation

enum SafetyClassification: String, Hashable, Sendable, CaseIterable {
    case safe
    case reviewRequired
    case protected

    var displayName: String {
        switch self {
        case .safe:
            return L10n.text("safety.safe")
        case .reviewRequired:
            return L10n.text("safety.review_required")
        case .protected:
            return L10n.text("safety.protected")
        }
    }
}

struct SafetyVerdict: Hashable, Sendable {
    let classification: SafetyClassification
    let reason: String
    let item: StartupItem
}

struct SafeActionDryRun: Hashable, Sendable {
    let generatedAt: Date
    let verdicts: [SafetyVerdict]

    var safeItems: [StartupItem] {
        verdicts.filter { $0.classification == .safe }.map(\.item)
    }

    var reviewItems: [StartupItem] {
        verdicts.filter { $0.classification == .reviewRequired }.map(\.item)
    }

    var protectedItems: [StartupItem] {
        verdicts.filter { $0.classification == .protected }.map(\.item)
    }

    var safeCount: Int { safeItems.count }
    var reviewCount: Int { reviewItems.count }
    var protectedCount: Int { protectedItems.count }
}

struct SafeActionSnapshotEntry: Codable, Hashable, Sendable {
    let label: String
    let plistPath: String
    let type: String
    let loadedBefore: Bool
    let disabledBefore: Bool
    let timestamp: Date
    let actionPerformed: [String]
}

struct SafeActionSnapshot: Codable, Hashable, Sendable {
    let timestamp: Date
    let entries: [SafeActionSnapshotEntry]
}

enum SafeActionItemOutcome: String, Hashable, Sendable {
    case succeeded
    case failed
    case skipped
}

struct SafeActionItemResult: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let outcome: SafeActionItemOutcome
    let detail: String
}

struct SafeActionBatchResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let succeeded: Int
    let failed: Int
    let skipped: Int
    let items: [SafeActionItemResult]
    let snapshot: SafeActionSnapshot?

    var title: String { L10n.text("safe_action.result_title") }
}
