import XCTest
@testable import ClaudeUsageRingCore

final class UsageParserTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func parse(_ json: String) throws -> UsageSnapshot {
        try UsageParser.parse(Data(json.utf8), now: now)
    }

    /// Real response shape: utilization on a 0–100 scale + a `limits` array.
    func testRealSchemaPrefersLimitsArray() throws {
        let s = try parse("""
        { "five_hour": {"utilization":22.0,"resets_at":"2026-06-23T17:00:00.547090+00:00"},
          "seven_day": {"utilization":14.0,"resets_at":"2026-06-28T15:00:00.547113+00:00"},
          "limits":[
            {"kind":"session","group":"session","percent":22,"resets_at":"2026-06-23T17:00:00.547090+00:00","scope":null,"is_active":true},
            {"kind":"weekly_all","group":"weekly","percent":14,"resets_at":"2026-06-28T15:00:00.547113+00:00","scope":null,"is_active":false},
            {"kind":"weekly_scoped","group":"weekly","percent":0,"resets_at":null,"scope":{"model":{"display_name":"Sonnet"}},"is_active":false}
          ] }
        """)
        XCTAssertEqual(s.fiveHour.utilization, 0.22, accuracy: 0.0001)
        // weekly must be the all-models limit (14), NOT the Sonnet-scoped 0.
        XCTAssertEqual(s.weekly.utilization, 0.14, accuracy: 0.0001)
        XCTAssertNotEqual(s.fiveHour.resetsAt, now)   // microsecond+offset date parsed
        XCTAssertNotEqual(s.weekly.resetsAt, now)
    }

    func testObjectFallbackWhenNoLimitsArray() throws {
        let s = try parse("""
        { "five_hour": {"utilization":22.0,"resets_at":"2026-06-23T17:00:00Z"},
          "seven_day": {"utilization":14.0,"resets_at":"2026-06-28T15:00:00Z"} }
        """)
        XCTAssertEqual(s.fiveHour.utilization, 0.22, accuracy: 0.0001)
        XCTAssertEqual(s.weekly.utilization, 0.14, accuracy: 0.0001)
    }

    /// Regression: a 0–1 utilization is 1%, not 100%.
    func testLowUtilizationTreatedAsPercent() throws {
        let s = try parse("""
        { "five_hour":{"utilization":1.0,"resets_at":"2026-06-23T17:00:00Z"},
          "seven_day":{"utilization":0.0,"resets_at":"2026-06-28T15:00:00Z"} }
        """)
        XCTAssertEqual(s.fiveHour.utilization, 0.01, accuracy: 0.0001)
        XCTAssertEqual(s.weekly.utilization, 0.0, accuracy: 0.0001)
    }

    func testMissingWeeklyThrows() {
        XCTAssertThrowsError(try parse(#"{ "five_hour": { "utilization": 22.0 } }"#)) { err in
            XCTAssertEqual(err as? UsageParseError, .missingWindow("seven_day"))
        }
    }

    func testNotObjectThrows() {
        XCTAssertThrowsError(try parse("[1,2,3]")) { err in
            XCTAssertEqual(err as? UsageParseError, .notObject)
        }
    }
}
