import SwiftUI

enum LoadStatus: Hashable, Sendable {
    case loaded
    case unloaded
    case disabled
    case orphaned
    case error(String)
    case unknown

    var displayName: String {
        switch self {
        case .loaded:
            return L10n.text("status.loaded.name")
        case .unloaded:
            return L10n.text("status.unloaded.name")
        case .disabled:
            return L10n.text("status.disabled.name")
        case .orphaned:
            return L10n.text("status.orphaned.name")
        case .error:
            return L10n.text("status.error.name")
        case .unknown:
            return L10n.text("status.unknown.name")
        }
    }

    /// Tooltip / list helper. Status describes runtime, not a cleanup suggestion.
    var shortDescription: String {
        switch self {
        case .loaded:
            return L10n.text("status.loaded.short")
        case .unloaded:
            return L10n.text("status.unloaded.short")
        case .disabled:
            return L10n.text("status.disabled.short")
        case .orphaned:
            return L10n.text("status.orphaned.short")
        case .error:
            return L10n.text("status.error.short")
        case .unknown:
            return L10n.text("status.unknown.short")
        }
    }

    var detailedDescription: String {
        switch self {
        case .loaded:
            return L10n.text("status.loaded.detailed")
        case .unloaded:
            return L10n.text("status.unloaded.detailed")
        case .disabled:
            return L10n.text("status.disabled.detailed")
        case .orphaned:
            return L10n.text("status.orphaned.detailed")
        case .error:
            return L10n.text("status.error.detailed")
        case .unknown:
            return L10n.text("status.unknown.detailed")
        }
    }

    var systemImage: String {
        switch self {
        case .loaded:
            return "circle.fill"
        case .unloaded:
            return "circle"
        case .disabled:
            return "pause.circle.fill"
        case .orphaned:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .loaded:
            return .green
        case .unloaded:
            return Color.secondary
        case .disabled:
            return .orange
        case .orphaned:
            return .orange
        case .error:
            return .red
        case .unknown:
            return Color.secondary
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .error(let message):
            return L10n.text("status.error.accessibility", ["message": message])
        default:
            return displayName
        }
    }

    var sortRank: Int {
        switch self {
        case .orphaned:
            return 0
        case .disabled:
            return 1
        case .loaded:
            return 2
        case .unloaded:
            return 3
        case .error:
            return 4
        case .unknown:
            return 5
        }
    }

    var isOrphaned: Bool {
        if case .orphaned = self { return true }
        return false
    }
}

struct StatusGroup: Identifiable, Hashable, Sendable {
    let kind: StatusGroupKind
    let items: [StartupItem]

    var id: StatusGroupKind { kind }
}

enum StatusGroupKind: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case orphaned
    case disabled
    case loaded
    case unloaded
    case error
    case unknown

    var id: Int { rawValue }

    var representativeStatus: LoadStatus {
        switch self {
        case .orphaned:
            return .orphaned
        case .disabled:
            return .disabled
        case .loaded:
            return .loaded
        case .unloaded:
            return .unloaded
        case .error:
            return .error("")
        case .unknown:
            return .unknown
        }
    }

    func matches(_ status: LoadStatus) -> Bool {
        switch (self, status) {
        case (.orphaned, .orphaned),
             (.disabled, .disabled),
             (.loaded, .loaded),
             (.unloaded, .unloaded),
             (.error, .error),
             (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}

extension Array where Element == StartupItem {
    func groupedByStatus() -> [StatusGroup] {
        StatusGroupKind.allCases.compactMap { kind in
            let grouped = filter { kind.matches($0.loadStatus) }
            guard !grouped.isEmpty else { return nil }
            let sorted = grouped.sorted {
                $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
            return StatusGroup(kind: kind, items: sorted)
        }
    }
}
