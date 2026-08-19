import Foundation

enum LoadStatusResolver: Sendable {
    static func resolve(
        executableExists: Bool,
        isDisabled: Bool,
        printSucceeded: Bool,
        printOutput: String,
        exitCode: Int32
    ) -> LoadStatus {
        if !executableExists {
            return .orphaned
        }
        if isDisabled {
            return .disabled
        }
        if printSucceeded {
            return .loaded
        }

        let output = printOutput.lowercased()
        if output.contains("could not find service") || output.contains("could not find domain") {
            return .unloaded
        }
        if exitCode != 0 {
            let message = printOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return .error(message.isEmpty ? "launchctl print failed (\(exitCode))" : message)
        }
        return .unknown
    }
}
