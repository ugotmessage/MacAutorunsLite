import XCTest
@testable import AutorunsLite

final class AppearanceModeTests: XCTestCase {
    func testDisplayNames() {
        XCTAssertEqual(AppearanceMode.system.displayName, "跟隨系統")
        XCTAssertEqual(AppearanceMode.light.displayName, "淺色")
        XCTAssertEqual(AppearanceMode.dark.displayName, "深色")
    }

    func testPreferredColorScheme() {
        XCTAssertNil(AppearanceMode.system.preferredColorScheme)
        XCTAssertEqual(AppearanceMode.light.preferredColorScheme, .light)
        XCTAssertEqual(AppearanceMode.dark.preferredColorScheme, .dark)
    }

    func testPersistsRawValueInUserDefaults() {
        let key = "appearanceMode"
        let previous = UserDefaults.standard.string(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.set(AppearanceMode.dark.rawValue, forKey: key)
        let restored = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: key) ?? "")
        XCTAssertEqual(restored, .dark)

        UserDefaults.standard.set(AppearanceMode.light.rawValue, forKey: key)
        XCTAssertEqual(AppearanceMode(rawValue: UserDefaults.standard.string(forKey: key) ?? ""), .light)

        UserDefaults.standard.set(AppearanceMode.system.rawValue, forKey: key)
        XCTAssertEqual(AppearanceMode(rawValue: UserDefaults.standard.string(forKey: key) ?? ""), .system)
    }
}
