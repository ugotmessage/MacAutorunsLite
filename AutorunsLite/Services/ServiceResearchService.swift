import Foundation
import AppKit

enum ResearchSearchURL {
    static func googleURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        return components?.url
    }

    static func destination(from searchField: String) -> ResearchDestination {
        let trimmed = searchField.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https",
           url.host != nil
        {
            return .url(url)
        }
        if let url = googleURL(for: trimmed) {
            return .url(url)
        }
        return .invalid
    }
}

@MainActor
struct ServiceResearchService {
    private let builder = ServiceResearchQueryBuilder()

    func keyword(for type: ServiceResearchQueryType, settings: AppSettings) -> String {
        switch type {
        case .overview:
            return settings.researchOverviewKeyword
        case .disableSafety:
            return ResearchSearchDefaults.disableKeyword
        case .removalSafety:
            return ResearchSearchDefaults.removeKeyword
        case .community:
            return ResearchSearchDefaults.communityKeyword
        }
    }

    func query(
        item: StartupItem,
        type: ServiceResearchQueryType,
        settings: AppSettings
    ) -> QueryBuildResult {
        builder.build(
            item: item,
            keyword: keyword(for: type, settings: settings),
            template: settings.researchQueryTemplate
        )
    }

    func query(item: StartupItem, keyword: String, settings: AppSettings) -> QueryBuildResult {
        builder.build(item: item, keyword: keyword, template: settings.researchQueryTemplate)
    }

    func searchURL(for query: String) -> URL? {
        ResearchSearchURL.googleURL(for: query)
    }

    func destination(from searchField: String) -> ResearchDestination {
        ResearchSearchURL.destination(from: searchField)
    }
}

enum ResearchDestination: Equatable {
    case url(URL)
    case invalid
}
