import Foundation
import AppKit

protocol TrashService: Sendable {
    func trash(url: URL) async throws
}

struct WorkspaceTrashService: TrashService {
    func trash(url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.recycle([url]) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum TrashEligibility {
    static func userLaunchAgentsDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    static func isAllowedUserLaunchAgentPlist(_ item: StartupItem) -> Bool {
        guard item.type == .userLaunchAgent else { return false }
        guard !item.isSystemProtected else { return false }

        let plistURL = URL(fileURLWithPath: item.plistPath)
        let allowed = userLaunchAgentsDirectory().standardizedFileURL.path
        let standardized = plistURL.standardizedFileURL.path
        guard standardized.hasPrefix(allowed + "/") || standardized.hasPrefix(allowed) else {
            return false
        }

        if let values = try? plistURL.resourceValues(forKeys: [.isSymbolicLinkKey]),
           values.isSymbolicLink == true
        {
            let destination = plistURL.resolvingSymlinksInPath().path
            if destination.hasPrefix("/System/")
                || destination.hasPrefix("/Library/")
                || destination.hasPrefix("/usr/")
            {
                return false
            }
        }

        return FileManager.default.fileExists(atPath: item.plistPath)
    }

    static func canMoveToTrash(_ item: StartupItem, recommendation: ItemRecommendation) -> Bool {
        recommendation == .safeAction && isAllowedUserLaunchAgentPlist(item)
    }
}
