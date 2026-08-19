import Foundation
import Darwin

enum ServicePrintState: Equatable, Sendable {
    case loaded
    case notFound
    case error(String)
}

final class LaunchctlService: Sendable {
    func run(_ arguments: [String]) async -> LaunchctlResult {
        await Task.detached(priority: .userInitiated) {
            Self.runSync(executable: "/bin/launchctl", arguments: arguments)
        }.value
    }

    func printService(domain: String, label: String) async -> LaunchctlResult {
        await run(["print", "\(domain)/\(label)"])
    }

    func serviceState(domain: String, label: String) async -> ServicePrintState {
        Self.interpretPrintResult(await printService(domain: domain, label: label))
    }

    static func interpretPrintResult(_ result: LaunchctlResult) -> ServicePrintState {
        if result.succeeded {
            return .loaded
        }

        let output = result.combinedOutput.lowercased()
        if output.contains("could not find service")
            || output.contains("service cannot be found")
            || output.contains("could not find domain")
        {
            return .notFound
        }

        let message = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return .error(message.isEmpty ? "launchctl print failed (\(result.exitCode))" : message)
    }

    func printDomain(_ domain: String) async -> LaunchctlResult {
        await run(["print", domain])
    }

    func printDisabled(domain: String) async -> LaunchctlResult {
        await run(["print-disabled", domain])
    }

    func bootstrap(domain: String, plistPath: String) async -> LaunchctlResult {
        await run(["bootstrap", domain, plistPath])
    }

    func bootout(domain: String, plistPath: String) async -> LaunchctlResult {
        await run(["bootout", domain, plistPath])
    }

    func enable(domain: String, label: String) async -> LaunchctlResult {
        await run(["enable", "\(domain)/\(label)"])
    }

    func disable(domain: String, label: String) async -> LaunchctlResult {
        await run(["disable", "\(domain)/\(label)"])
    }

    func parseDisabledLabels(from stdout: String) -> Set<String> {
        var disabled = Set<String>()
        let pattern = #"\"([^\"]+)\"\s*=>\s*([^\s}]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return disabled
        }

        let range = NSRange(stdout.startIndex..<stdout.endIndex, in: stdout)
        regex.enumerateMatches(in: stdout, options: [], range: range) { match, _, _ in
            guard
                let match,
                let labelRange = Range(match.range(at: 1), in: stdout),
                let valueRange = Range(match.range(at: 2), in: stdout)
            else {
                return
            }
            let label = String(stdout[labelRange])
            let value = String(stdout[valueRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ",;"))
                .lowercased()

            if value.hasPrefix("disabled") || value == "true" || value == "1" {
                disabled.insert(label)
            }
        }
        return disabled
    }

    @available(*, deprecated, message: "Do not use for loaded-state detection. Query launchctl print domain/label instead.")
    func parseLoadedLabels(from stdout: String) -> Set<String> {
        guard let servicesStart = stdout.range(of: "services = {") else {
            return []
        }

        var block = stdout[servicesStart.upperBound...]
        if let endpoints = block.range(of: "endpoints = {") {
            block = block[..<endpoints.lowerBound]
        }

        var labels = Set<String>()
        let pattern = #"\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return labels
        }

        let text = String(block)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard
                let match,
                let labelRange = Range(match.range(at: 1), in: text)
            else {
                return
            }
            labels.insert(String(text[labelRange]))
        }
        return labels
    }

    private static func runSync(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 8
    ) -> LaunchctlResult {
        let command = ([executable] + arguments).joined(separator: " ")
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let stdoutBox = MutexData()
        let stderrBox = MutexData()
        let readersDone = DispatchSemaphore(value: 0)

        do {
            try process.run()

            // Real pthreads, not GCD workers — avoids thread-pool deadlock
            // when many launchctl processes run at once.
            Thread.detachNewThread {
                stdoutBox.append(Self.readAll(from: outputPipe.fileHandleForReading))
                readersDone.signal()
            }
            Thread.detachNewThread {
                stderrBox.append(Self.readAll(from: errorPipe.fileHandleForReading))
                readersDone.signal()
            }

            Self.wait(for: process, timeout: timeout)

            _ = readersDone.wait(timeout: .now() + 2)
            _ = readersDone.wait(timeout: .now() + 2)

            return LaunchctlResult(
                command: command,
                exitCode: process.terminationStatus,
                stdout: String(data: stdoutBox.data, encoding: .utf8) ?? "",
                stderr: String(data: stderrBox.data, encoding: .utf8) ?? ""
            )
        } catch {
            return LaunchctlResult(
                command: command,
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription
            )
        }
    }

    private static func readAll(from handle: FileHandle) -> Data {
        if #available(macOS 10.15.4, *) {
            return (try? handle.readToEnd()) ?? Data()
        }
        return handle.readDataToEndOfFile()
    }

    private static func wait(for process: Process, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard process.isRunning else { return }

        process.terminate()
        let terminateDeadline = Date().addingTimeInterval(1)
        while process.isRunning && Date() < terminateDeadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
    }
}

private final class MutexData: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
