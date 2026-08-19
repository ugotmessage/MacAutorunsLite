import Foundation

@MainActor
final class ServiceResearchSession: ObservableObject {
    @Published var item: StartupItem?
    @Published var initialQueryType: ServiceResearchQueryType = .overview
}
