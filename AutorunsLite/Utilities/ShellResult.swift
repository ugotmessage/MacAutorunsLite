import Foundation

struct LaunchctlResult: Sendable, Equatable {
    let command: String
    let exitCode: Int32
    let stdout: String
    let stderr: String

    init(command: String = "", exitCode: Int32, stdout: String, stderr: String) {
        self.command = command
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    var succeeded: Bool {
        exitCode == 0
    }

    var combinedOutput: String {
        let parts = [stdout, stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: "\n")
    }

    var permissionDenied: Bool {
        let haystack = combinedOutput.lowercased()
        return haystack.contains("permission")
            || haystack.contains("not permitted")
            || haystack.contains("not privileged")
            || haystack.contains("input/output error")
            || exitCode == 1 && haystack.contains("denied")
            || exitCode == 5
    }
}

typealias ShellResult = LaunchctlResult
