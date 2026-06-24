import XCTest
@testable import ClaudeUsageRingCore

@MainActor
final class SettingsModelTests: XCTestCase {
    func testClampBounds() {
        XCTAssertEqual(SettingsModel.clamp(2), 30)
        XCTAssertEqual(SettingsModel.clamp(60), 60)
        XCTAssertEqual(SettingsModel.clamp(9999), 600)
    }
}
