import XCTest
@testable import ClaudeUsageRingCore

final class CCUsageClientTests: XCTestCase {
    // Block started 2h before "now".
    let now = Date(timeIntervalSince1970: 1_700_007_200)
    let startISO = "2023-11-14T22:13:20Z" // = 1_700_000_000

    func testParsesCostAndComputesBurn() {
        let json = """
        { "blocks": [ { "isActive": true, "costUSD": 4.0,
          "startTime": "\(startISO)", "totalTokens": 123 } ] }
        """
        let b = CCUsageParser.parse(Data(json.utf8), now: now)
        XCTAssertEqual(b?.costUSD ?? 0, 4.0, accuracy: 0.0001)
        XCTAssertEqual(b?.burnUSDPerHour ?? 0, 2.0, accuracy: 0.01) // 4 USD / 2h
    }

    func testNoActiveBlockReturnsNil() {
        let json = #"{ "blocks": [ { "isActive": false, "costUSD": 1.0 } ] }"#
        XCTAssertNil(CCUsageParser.parse(Data(json.utf8), now: now))
    }

    func testGarbageReturnsNil() {
        XCTAssertNil(CCUsageParser.parse(Data("not json".utf8), now: now))
    }
}
