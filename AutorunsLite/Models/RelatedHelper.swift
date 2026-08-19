import Foundation

enum RelatedHelperKind: String, Hashable, Sendable {
    case loginItem
    case xpc
    case smPlist
}

struct RelatedHelper: Hashable, Sendable, Identifiable {
    var id: String { path }

    let name: String
    let path: String
    let kind: RelatedHelperKind
    let bundleIdentifier: String?

    var kindDisplayName: String {
        switch kind {
        case .loginItem:
            return "Login Item"
        case .xpc:
            return "XPC"
        case .smPlist:
            return "SMAppService"
        }
    }
}
