import Foundation

struct ParsedLaunchPlist: Equatable, Sendable {
    let label: String
    let program: String?
    let programArguments: [String]
    let runAtLoad: Bool
    let keepAliveDescription: String?
    let workingDirectory: String?
    let environmentVariables: [String: String]
    let standardOutPath: String?
    let standardErrorPath: String?

    var executablePath: String? {
        if let program, !program.isEmpty {
            return program
        }
        return programArguments.first
    }

    var arguments: [String] {
        programArguments
    }
}

struct PlistParser: Sendable {
    func parse(url: URL) throws -> ParsedLaunchPlist {
        let data = try Data(contentsOf: url)
        return try parse(data: data, fallbackLabel: url.deletingPathExtension().lastPathComponent)
    }

    func parse(data: Data, fallbackLabel: String) throws -> ParsedLaunchPlist {
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = object as? [String: Any] else {
            throw PlistParserError.invalidFormat
        }
        return parse(dictionary: dict, fallbackLabel: fallbackLabel)
    }

    func parse(dictionary: [String: Any], fallbackLabel: String) -> ParsedLaunchPlist {
        let label = stringValue(dictionary["Label"]) ?? fallbackLabel
        let program = stringValue(dictionary["Program"])
        let programArguments = stringArray(dictionary["ProgramArguments"])
        let runAtLoad = boolValue(dictionary["RunAtLoad"])
        let keepAliveDescription = keepAliveText(dictionary["KeepAlive"])
        let workingDirectory = stringValue(dictionary["WorkingDirectory"])
        let environmentVariables = stringDictionary(dictionary["EnvironmentVariables"])
        let standardOutPath = stringValue(dictionary["StandardOutPath"])
        let standardErrorPath = stringValue(dictionary["StandardErrorPath"])

        return ParsedLaunchPlist(
            label: label,
            program: program,
            programArguments: programArguments,
            runAtLoad: runAtLoad,
            keepAliveDescription: keepAliveDescription,
            workingDirectory: workingDirectory,
            environmentVariables: environmentVariables,
            standardOutPath: standardOutPath,
            standardErrorPath: standardErrorPath
        )
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String, !string.isEmpty {
            return string
        }
        return nil
    }

    private func stringArray(_ value: Any?) -> [String] {
        if let array = value as? [String] {
            return array
        }
        if let array = value as? [Any] {
            return array.compactMap { $0 as? String }
        }
        return []
    }

    private func stringDictionary(_ value: Any?) -> [String: String] {
        if let dict = value as? [String: String] {
            return dict
        }
        if let dict = value as? [String: Any] {
            var result: [String: String] = [:]
            for (key, raw) in dict {
                result[key] = String(describing: raw)
            }
            return result
        }
        return [:]
    }

    private func boolValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return false
    }

    private func keepAliveText(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let bool = value as? Bool {
            return bool ? "Yes" : "No"
        }
        if let number = value as? NSNumber {
            return number.boolValue ? "Yes" : "No"
        }
        if let dict = value as? [String: Any] {
            let parts = dict.keys.sorted().map { key in
                "\(key): \(stringifyKeepAliveValue(dict[key]))"
            }
            return parts.joined(separator: ", ")
        }
        return String(describing: value)
    }

    private func stringifyKeepAliveValue(_ value: Any?) -> String {
        guard let value else { return "nil" }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        if let number = value as? NSNumber {
            return number.boolValue ? "true" : "false"
        }
        return String(describing: value)
    }
}

enum PlistParserError: Error, LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "plist 不是 dictionary 格式"
        }
    }
}
