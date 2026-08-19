import Foundation

struct QueryBuildResult: Equatable, Sendable {
    let query: String
    let unknownVariables: [String]
    let missingLabelPlaceholder: Bool
}

struct ServiceResearchQueryBuilder: Sendable {
    func build(
        label: String,
        typeKeyword: String,
        keyword: String,
        template: String
    ) -> QueryBuildResult {
        let trimmedTemplate = template.trimmingCharacters(in: .whitespacesAndNewlines)
        let missingLabel = !trimmedTemplate.contains("{label}")

        var query = trimmedTemplate
            .replacingOccurrences(of: "{label}", with: label)
            .replacingOccurrences(of: "{type}", with: typeKeyword)
            .replacingOccurrences(of: "{keyword}", with: keyword)

        let unknown = unknownVariables(in: query)
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return QueryBuildResult(
            query: query,
            unknownVariables: unknown,
            missingLabelPlaceholder: missingLabel
        )
    }

    func build(item: StartupItem, keyword: String, template: String) -> QueryBuildResult {
        build(
            label: item.label,
            typeKeyword: item.type.researchTypeKeyword,
            keyword: keyword,
            template: template
        )
    }

    private func unknownVariables(in query: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\{[A-Za-z0-9_]+\\}") else {
            return []
        }
        let range = NSRange(query.startIndex..<query.endIndex, in: query)
        let known = Set(["{label}", "{type}", "{keyword}", "{name}", "{vendor}", "{origin}"])
        var found: [String] = []
        regex.enumerateMatches(in: query, options: [], range: range) { match, _, _ in
            guard
                let match,
                let matchRange = Range(match.range, in: query)
            else {
                return
            }
            let token = String(query[matchRange])
            if !known.contains(token) && !found.contains(token) {
                found.append(token)
            }
        }
        return found
    }
}
