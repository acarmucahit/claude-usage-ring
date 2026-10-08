import XCTest
@testable import ClaudeUsageRingCore

@MainActor
final class SettingsModelTests: XCTestCase {
    func testClampBounds() {
        XCTAssertEqual(SettingsModel.clamp(2), 120)
        XCTAssertEqual(SettingsModel.clamp(300), 300)
        XCTAssertEqual(SettingsModel.clamp(9999), 1800)
    }

    func testDefaultIntervalIsFiveMinutes() {
        let suite = "SettingsModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(SettingsModel(defaults: defaults).refreshInterval, 300)
    }

    func testStoredSixtySecondsIsRaisedToMinimum() {
        let suite = "SettingsModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(60.0, forKey: "refreshInterval")
        XCTAssertEqual(SettingsModel(defaults: defaults).refreshInterval, 120)
    }
}
