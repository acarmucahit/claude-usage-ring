import XCTest
@testable import ClaudeUsageRingCore

private struct StubTransport: Transport {
    let data: Data; let status: Int
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private final class SeqTransport: Transport, @unchecked Sendable {
    private let responses: [(Data, Int)]
    private var index = 0
    init(_ responses: [(Data, Int)]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let (data, status) = responses[min(index, responses.count - 1)]
        index += 1
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor
final class UsageStoreTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func client(_ json: String, status: Int = 200) -> UsageClient {
        let now = self.now
        return UsageClient(tokenProvider: { "tok" },
                           transport: StubTransport(data: Data(json.utf8), status: status),
                           now: { now })
    }

    func testRefreshSuccessSetsOk() async {
        let store = UsageStore(
            client: client(#"{ "five_hour": {"utilization":30.0,"resets_at":"2026-06-23T17:00:00Z"}, "seven_day": {"utilization":60.0,"resets_at":"2026-06-27T12:00:00Z"} }"#),
            ccusage: nil, interval: { 30 })
        await store.refresh()
        if case let .ok(snap) = store.state {
            XCTAssertEqual(snap.fiveHour.utilization, 0.3, accuracy: 0.0001)
        } else { XCTFail("expected .ok, got \(store.state)") }
    }

    func testRefreshUnauthorizedSetsFailed() async {
        let store = UsageStore(client: client("{}", status: 401), ccusage: nil, interval: { 30 })
        await store.refresh()
        if case let .failed(msg) = store.state {
            XCTAssertTrue(msg.contains("Unauthorized"))
        } else { XCTFail("expected .failed") }
    }

    func testRateLimitKeepsLastGoodSnapshot() async {
        let now = self.now
        let ok = #"{ "five_hour":{"utilization":30.0,"resets_at":"2026-06-23T17:00:00Z"}, "seven_day":{"utilization":60.0,"resets_at":"2026-06-27T12:00:00Z"} }"#
        let client = UsageClient(
            tokenProvider: { "t" },
            transport: SeqTransport([(Data(ok.utf8), 200), (Data("{}".utf8), 429)]),
            now: { now })
        let store = UsageStore(client: client, ccusage: nil, interval: { 30 })
        await store.refresh()   // success → caches snapshot
        await store.refresh()   // 429 → keeps last good data, flags rate limit
        XCTAssertTrue(store.rateLimited)
        if case let .ok(snap) = store.state {
            XCTAssertEqual(snap.fiveHour.utilization, 0.3, accuracy: 0.0001)
        } else { XCTFail("expected last good .ok, got \(store.state)") }
    }
}
