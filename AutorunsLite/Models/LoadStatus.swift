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
            return "已載入"
        case .unloaded:
            return "未載入"
        case .disabled:
            return "已停用"
        case .orphaned:
            return "殘留"
        case .error:
            return "錯誤"
        case .unknown:
            return "未知"
        }
    }

    /// Tooltip / list helper. Status describes runtime, not a cleanup suggestion.
    var shortDescription: String {
        switch self {
        case .loaded:
            return "此項目目前已由 launchd 載入，但不代表程式一定正在執行。"
        case .unloaded:
            return "plist 存在，但目前沒有載入到 launchd；這不一定是異常。"
        case .disabled:
            return "launchd 已明確標記此項目為停用。"
        case .orphaned:
            return "plist 仍存在，但指定執行檔已不存在。"
        case .error:
            return "無法正常解析或查詢此項目。"
        case .unknown:
            return "目前資訊不足，無法安全判斷。"
        }
    }

    var detailedDescription: String {
        switch self {
        case .loaded:
            return """
            此啟動項目目前已註冊在 launchd 中。

            「已載入」不代表它的程式現在一定正在執行。launchd 可能正在等待 RunAtLoad、KeepAlive、Timer、Socket 或其他觸發條件後才啟動對應程式。
            """
        case .unloaded:
            return """
            此項目的 plist 設定檔仍存在，但目前沒有註冊在對應的 launchd domain 中。

            這不一定代表異常，也不代表此項目可以刪除。可能原因包括 App 尚未啟動、只在需要時載入、使用者曾停止該服務，或該服務原本就不需要持續載入。

            未載入不代表無用，也不代表可以安全刪除。
            """
        case .disabled:
            return """
            此啟動項目目前被 launchd 標記為 Disabled。

            即使 plist 仍然存在，launchd 通常不會正常自動載入它，直到重新執行啟用。

            「已停用」與「未載入」不同：未載入表示目前沒有載入，但未必禁止未來載入；已停用表示 launchd 已明確標記為禁止自動載入。
            """
        case .orphaned:
            return """
            MacAutorunsLite 找到此啟動項目的 plist，但 plist 指向的 executable 已不存在。

            常見原因包括 App 已被移除、更新後路徑改變，或舊版 Helper 沒有正確清除。這通常值得檢查，但不代表一定可以直接刪除。
            """
        case .error:
            return """
            此項目在讀取 plist 或查詢 launchctl 時發生錯誤。可能原因包括 plist 格式錯誤、權限不足、launchctl 查詢失敗，或檔案目前無法存取。

            錯誤項目不得加入自動安全處理。
            """
        case .unknown:
            return """
            MacAutorunsLite 目前無法確認此啟動項目的實際狀態。

            未知狀態不應自動停用、自動刪除，或標記成殘留，必須列入人工確認。
            """
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
            return "錯誤：\(message)"
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
