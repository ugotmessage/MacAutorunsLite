import XCTest
@testable import AutorunsLite

final class ItemNotesStoreTests: XCTestCase {
    func testSaveAndLoadRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("item-notes-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ItemNotesStore(fileURL: url)
        store.save([
            "/Users/demo/Library/LaunchAgents/com.example.agent.plist": "Adobe 安裝殘留"
        ])

        let loaded = ItemNotesStore(fileURL: url).load()
        XCTAssertEqual(loaded["/Users/demo/Library/LaunchAgents/com.example.agent.plist"], "Adobe 安裝殘留")
    }

    func testMissingFileIsEmpty() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-notes-\(UUID().uuidString).json")
        let store = ItemNotesStore(fileURL: url)
        XCTAssertEqual(store.load(), [:])
    }
}
