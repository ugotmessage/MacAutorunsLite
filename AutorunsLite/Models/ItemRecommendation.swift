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
            return "建議保留"
        case .canDisable:
            return "可考慮停用"
        case .safeAction:
            return "可安全處理"
        case .reviewRequired:
            return "建議檢查"
        case .protected:
            return "系統保護"
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
