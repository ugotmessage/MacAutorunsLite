import Foundation

enum SystemLoadDecision {
    static func shouldCommit(scanned: ScanResult, previousSystemCount: Int) -> Bool {
        let systemCount = scanned.items.filter(\.type.isSystemLaunchd).count
        return scanned.systemLoadGranted && (systemCount > previousSystemCount || systemCount > 0)
    }
}
