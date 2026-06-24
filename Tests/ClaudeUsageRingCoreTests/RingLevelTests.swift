import XCTest
@testable import ClaudeUsageRingCore

final class RingLevelTests: XCTestCase {
    func testThresholds() {
        XCTAssertEqual(RingLevel(utilization: 0.0), .green)
        XCTAssertEqual(RingLevel(utilization: 0.49), .green)
        XCTAssertEqual(RingLevel(utilization: 0.50), .yellow)
        XCTAssertEqual(RingLevel(utilization: 0.79), .yellow)
        XCTAssertEqual(RingLevel(utilization: 0.80), .red)
        XCTAssertEqual(RingLevel(utilization: 1.0), .red)
    }
}
