import SwiftUI

enum ItemRecommendation: String, Hashable, Sendable, CaseIterable {
    case keep
    case canDisable
    case safeAction
    case reviewRequired
    case protected

    var displayName: String {
        switch self {
        case .keep:
            return L10n.text("recommendation.keep")
        case .canDisable:
            return L10n.text("recommendation.can_disable")
        case .safeAction:
            return L10n.text("recommendation.safe_action")
        case .reviewRequired:
            return L10n.text("recommendation.review_required")
        case .protected:
            return L10n.text("recommendation.protected")
        }
    }

    var systemImage: String {
        switch self {
        case .keep:
            return "checkmark.circle"
        case .canDisable:
            return "pause.circle"
        case .safeAction:
            return "checkmark.shield"
        case .reviewRequired:
            return "eye"
        case .protected:
            return "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .keep:
            return Color.secondary
        case .canDisable:
            return .orange
        case .safeAction:
            return .green
        case .reviewRequired:
            return .orange
        case .protected:
            return Color.secondary
        }
    }
}

struct RecommendationResult: Hashable, Sendable {
    let recommendation: ItemRecommendation
    let reason: String
    let evidence: [String]
}
