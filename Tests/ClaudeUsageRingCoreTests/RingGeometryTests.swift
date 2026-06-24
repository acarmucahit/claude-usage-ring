import XCTest
@testable import ClaudeUsageRingCore

final class RingGeometryTests: XCTestCase {
    func testClamp() {
        XCTAssertEqual(RingGeometry.trimEnd(for: -0.2), 0.0, accuracy: 0.0001)
        XCTAssertEqual(RingGeometry.trimEnd(for: 0.42), 0.42, accuracy: 0.0001)
        XCTAssertEqual(RingGeometry.trimEnd(for: 1.7), 1.0, accuracy: 0.0001)
    }
}
