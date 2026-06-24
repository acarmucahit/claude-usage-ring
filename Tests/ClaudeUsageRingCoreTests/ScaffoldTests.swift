import XCTest
@testable import ClaudeUsageRingCore

final class ScaffoldTests: XCTestCase {
    func testModelsConstruct() {
        let w = UsageWindow(utilization: 0.5, resetsAt: Date(timeIntervalSince1970: 0))
        let s = UsageSnapshot(fiveHour: w, weekly: w)
        XCTAssertEqual(s.fiveHour, s.weekly)
    }
}
