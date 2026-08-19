import Foundation

enum LoadStatusResolver: Sendable {
    static func resolve(
        executableExists: Bool,
        isDisabled: Bool,
        runtimeState: ServicePrintState
    ) -> LoadStatus {
        if !executableExists {
            return .orphaned
        }
        if isDisabled {
            return .disabled
        }
        switch runtimeState {
        case .loaded:
            return .loaded
        case .notFound:
            return .unloaded
        case .error(let message):
            return .error(message)
        }
    }

    static func resolve(
        executableExists: Bool,
        isDisabled: Bool,
        printSucceeded: Bool,
        printOutput: String,
        exitCode: Int32
    ) -> LoadStatus {
        let result = LaunchctlResult(
            exitCode: printSucceeded ? 0 : exitCode,
            stdout: printOutput,
            stderr: ""
        )
        return resolve(
            executableExists: executableExists,
            isDisabled: isDisabled,
            runtimeState: LaunchctlService.interpretPrintResult(result)
        )
    }
}
