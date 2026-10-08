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
        XCTAssertNotNil(s.fiveHour.resetsAt)   // microsecond+offset date parsed
        XCTAssertNotNil(s.weekly.resetsAt)
    }

    /// Response captured 2026-10-08: scoped row listed after weekly_all, many null keys.
    func testOctober2026Response() throws {
        let s = try parse("""
        { "five_hour": {"utilization":17.0,"resets_at":"2026-10-08T11:29:59.585325+00:00","limit_dollars":null},
          "seven_day": {"utilization":55.0,"resets_at":"2026-10-11T14:59:59.585351+00:00","limit_dollars":null},
          "seven_day_opus": null, "seven_day_sonnet": null,
          "limits":[
            {"kind":"session","group":"session","percent":17,"severity":"normal","resets_at":"2026-10-08T11:29:59.585325+00:00","scope":null,"is_active":false},
            {"kind":"weekly_all","group":"weekly","percent":55,"severity":"normal","resets_at":"2026-10-11T14:59:59.585351+00:00","scope":null,"is_active":true},
            {"kind":"weekly_scoped","group":"weekly","percent":0,"severity":"normal","resets_at":"2026-10-11T15:00:00+00:00","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":false}
          ] }
        """)
        XCTAssertEqual(s.fiveHour.utilization, 0.17, accuracy: 0.0001)
        XCTAssertEqual(s.weekly.utilization, 0.55, accuracy: 0.0001)
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

    /// No active 5-hour window: the weekly value must still come through.
    func testNullFiveHourCountsAsUnused() throws {
        let s = try parse("""
        { "five_hour": null,
          "seven_day": {"utilization":55.0,"resets_at":"2026-10-11T14:59:59Z"} }
        """)
        XCTAssertEqual(s.fiveHour.utilization, 0)
        XCTAssertNil(s.fiveHour.resetsAt)
        XCTAssertEqual(s.weekly.utilization, 0.55, accuracy: 0.0001)
    }

    func testMissingWeeklyCountsAsUnused() throws {
        let s = try parse(#"{ "five_hour": { "utilization": 22.0 } }"#)
        XCTAssertEqual(s.fiveHour.utilization, 0.22, accuracy: 0.0001)
        XCTAssertEqual(s.weekly.utilization, 0)
    }

    func testMissingResetIsNilNotNow() throws {
        let s = try parse(#"{ "five_hour": { "utilization": 5.0, "resets_at": null } }"#)
        XCTAssertNil(s.fiveHour.resetsAt)
    }

    func testNoWindowsThrows() {
        XCTAssertThrowsError(try parse(#"{ "five_hour": null, "seven_day": null }"#)) { err in
            XCTAssertEqual(err as? UsageParseError, .noWindows)
        }
    }

    func testNotObjectThrows() {
        XCTAssertThrowsError(try parse("[1,2,3]")) { err in
            XCTAssertEqual(err as? UsageParseError, .notObject)
        }
    }

    func testWindowReadsZeroOnceItsResetHasPassed() {
        let reset = now.addingTimeInterval(60)
        let w = UsageWindow(utilization: 0.92, resetsAt: reset)
        XCTAssertEqual(w.utilization(at: now), 0.92, accuracy: 0.0001)
        XCTAssertEqual(w.utilization(at: reset), 0)
        XCTAssertEqual(UsageWindow(utilization: 0.4, resetsAt: nil).utilization(at: now), 0.4, accuracy: 0.0001)
    }
}
