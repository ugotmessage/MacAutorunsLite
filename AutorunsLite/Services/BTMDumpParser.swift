import Foundation

struct BTMRecord: Equatable, Sendable {
    var uuid: String
    var name: String
    var developerName: String?
    var teamIdentifier: String?
    var rawType: String
    var disposition: String
    var identifier: String
    var url: String
    var executablePath: String?
    var associatedBundleIDs: [String]
    var parentIdentifier: String?

    var filePath: String {
        BTMDumpParser.fileURLPath(url) ?? executablePath ?? ""
    }

    var inferredType: StartupItemType {
        let typeText = rawType.lowercased()
        let path = filePath
        if isLegacyTraditionalPath(path) {
            if path.contains("/LaunchDaemons/") {
                return .launchDaemon
            }
            if path.contains("/LaunchAgents/") {
                if path.contains("/Users/") {
                    return .userLaunchAgent
                }
                return .systemLaunchAgent
            }
        }
        if typeText.contains("login item") || typeText.contains("user item") {
            return .loginItem
        }
        if path.contains("/Contents/Library/LoginItems/") {
            return .loginItem
        }
        if path.contains("/Contents/Library/LaunchAgents/") || path.contains("/Contents/Library/LaunchDaemons/") {
            return .smAppService
        }
        if typeText.contains("agent") || typeText.contains("daemon") {
            if path.contains(".app/Contents/") {
                return .smAppService
            }
        }
        return .backgroundTask
    }

    var isLegacyTraditional: Bool {
        isLegacyTraditionalPath(filePath)
    }

    var loadStatus: LoadStatus {
        let text = disposition.lowercased()
        if text.contains("disabled") || text.contains("disallowed") || text.contains("not allowed") {
            return .disabled
        }
        if text.contains("enabled") {
            return .loaded
        }
        return .unknown
    }
}

private func isLegacyTraditionalPath(_ path: String) -> Bool {
    guard !path.contains(".app/Contents/") else { return false }
    return path.contains("/Library/LaunchAgents/") || path.contains("/Library/LaunchDaemons/")
}

struct BTMDumpParser: Sendable {
    func parse(_ text: String) -> [BTMRecord] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        var records: [BTMRecord] = []
        var current: [String: String] = [:]

        func flush() {
            guard let uuid = current["UUID"], !uuid.isEmpty else {
                current.removeAll()
                return
            }
            records.append(
                BTMRecord(
                    uuid: uuid,
                    name: current["Name"] ?? uuid,
                    developerName: emptyToNil(current["Developer Name"]),
                    teamIdentifier: emptyToNil(current["Team Identifier"]),
                    rawType: current["Type"] ?? "",
                    disposition: current["Disposition"] ?? "",
                    identifier: current["Identifier"] ?? current["Name"] ?? uuid,
                    url: current["URL"] ?? "",
                    executablePath: emptyToNil(current["Executable Path"]),
                    associatedBundleIDs: parseBundleIDs(current["Assoc. Bundle IDs"] ?? current["Associated Bundle IDs"] ?? ""),
                    parentIdentifier: emptyToNil(current["Parent Identifier"])
                )
            )
            current.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed.range(of: #"^#\d+:"#, options: .regularExpression) != nil {
                flush()
                continue
            }
            guard let separator = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            current[key] = value
        }
        flush()
        return records
    }

    static func fileURLPath(_ value: String) -> String? {
        let compact = value.replacingOccurrences(of: "file:///", with: "file:///")
            .replacingOccurrences(of: "file:/// ", with: "file:///")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return nil }
        if compact.hasPrefix("file:") {
            if let url = URL(string: compact.replacingOccurrences(of: " ", with: "%20")) {
                return url.path
            }
        }
        if compact.hasPrefix("/") {
            return compact
        }
        return nil
    }

    private func parseBundleIDs(_ raw: String) -> [String] {
        raw
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func emptyToNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
