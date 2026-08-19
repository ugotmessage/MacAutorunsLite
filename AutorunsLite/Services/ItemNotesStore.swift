import Foundation

struct ItemNotesStore: Sendable {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let directory = root.appendingPathComponent("AutorunsLite", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("item-notes.json")
        }
    }

    func load() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    func save(_ notes: [String: String]) {
        let data = (try? JSONEncoder().encode(notes)) ?? Data("{}".utf8)
        try? data.write(to: fileURL, options: .atomic)
    }
}
