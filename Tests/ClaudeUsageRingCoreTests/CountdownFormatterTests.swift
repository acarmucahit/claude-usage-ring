import XCTest
@testable import ClaudeUsageRingCore

final class CountdownFormatterTests: XCTestCase {
    let base = Date(timeIntervalSince1970: 1_000_000)

    func testDaysAndHours() {
        let target = base.addingTimeInterval(4 * 86400 + 6 * 3600)
        XCTAssertEqual(CountdownFormatter.string(from: base, to: target), "4d 6h")
    }
    func testHoursAndMinutes() {
        let target = base.addingTimeInterval(3 * 3600 + 42 * 60)
        XCTAssertEqual(CountdownFormatter.string(from: base, to: target), "3h 42m")
    }
    func testMinutesOnly() {
        let target = base.addingTimeInterval(12 * 60)
        XCTAssertEqual(CountdownFormatter.string(from: base, to: target), "12m")
    }
    func testPast() {
        XCTAssertEqual(CountdownFormatter.string(from: base, to: base.addingTimeInterval(-5)), "now")
    }
}
