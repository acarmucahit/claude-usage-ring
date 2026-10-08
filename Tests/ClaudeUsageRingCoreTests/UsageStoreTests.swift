import XCTest
import Combine
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

private struct HangingTransport: Transport {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await Task.sleep(nanoseconds: 60_000_000_000)
        throw URLError(.timedOut)
    }
}

private final class TickCounter: @unchecked Sendable { var count = 0 }

@MainActor
final class UsageStoreTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let ok = #"{ "five_hour":{"utilization":30.0,"resets_at":"2026-06-23T17:00:00Z"}, "seven_day":{"utilization":60.0,"resets_at":"2026-06-27T12:00:00Z"} }"#

    private func client(_ json: String, status: Int = 200) -> UsageClient {
        let now = self.now
        return UsageClient(tokenProvider: { "tok" },
                           transport: StubTransport(data: Data(json.utf8), status: status),
                           now: { now })
    }

    private func seqStore(_ responses: [(String, Int)]) -> UsageStore {
        let now = self.now
        let client = UsageClient(
            tokenProvider: { "t" },
            transport: SeqTransport(responses.map { (Data($0.0.utf8), $0.1) }),
            now: { now })
        return UsageStore(client: client, ccusage: nil, interval: { 300 }, now: { now })
    }

    func testRefreshSuccessSetsOk() async {
        let store = UsageStore(client: client(ok), ccusage: nil, interval: { 300 }, now: { self.now })
        await store.refresh()
        if case let .ok(snap) = store.state {
            XCTAssertEqual(snap.fiveHour.utilization, 0.3, accuracy: 0.0001)
        } else { XCTFail("expected .ok, got \(store.state)") }
        XCTAssertEqual(store.lastSuccessAt, now)
        XCTAssertNil(store.lastError)
    }

    func testRefreshUnauthorizedSetsFailed() async {
        let store = UsageStore(client: client("{}", status: 401), ccusage: nil, interval: { 300 })
        await store.refresh()
        if case let .failed(msg) = store.state {
            XCTAssertTrue(msg.contains("open Claude Code"))
        } else { XCTFail("expected .failed") }
    }

    func testRateLimitKeepsLastGoodSnapshotAndRecordsError() async {
        let store = seqStore([(ok, 200), ("{}", 429)])
        await store.refresh()   // success → caches snapshot
        await store.refresh()   // 429 → keeps last good data, flags rate limit
        XCTAssertEqual(store.consecutiveRateLimits, 1)
        XCTAssertNotNil(store.lastError)
        XCTAssertEqual(store.lastSuccessAt, now)
        if case let .ok(snap) = store.state {
            XCTAssertEqual(snap.fiveHour.utilization, 0.3, accuracy: 0.0001)
        } else { XCTFail("expected last good .ok, got \(store.state)") }
    }

    func testSuccessClearsErrorAndRateLimitCount() async {
        let store = seqStore([("{}", 429), (ok, 200)])
        await store.refresh()
        await store.refresh()
        XCTAssertEqual(store.consecutiveRateLimits, 0)
        XCTAssertNil(store.lastError)
    }

    func testStaleOnlyWhenLastSuccessIsOld() async {
        let store = seqStore([(ok, 200)])
        XCTAssertFalse(store.isStale(at: now), "never fetched is loading, not stale")
        await store.refresh()
        XCTAssertFalse(store.isStale(at: now.addingTimeInterval(14 * 60)))
        XCTAssertTrue(store.isStale(at: now.addingTimeInterval(16 * 60)))
    }

    /// The label must re-check staleness and resets even while a fetch hangs
    /// or a long back-off is running, so the store ticks on its own.
    func testTicksWhileFetchIsBlocked() async throws {
        let client = UsageClient(tokenProvider: { "t" }, transport: HangingTransport())
        let store = UsageStore(client: client, ccusage: nil, interval: { 300 }, tickInterval: 0.05)
        let counter = TickCounter()
        let sub = store.objectWillChange.sink { counter.count += 1 }
        defer { sub.cancel() }
        store.start()
        try await Task.sleep(nanoseconds: 400_000_000)
        store.stop()
        XCTAssertGreaterThanOrEqual(counter.count, 3)
    }

    func testRetryDelayBacksOffOnRepeatedRateLimits() {
        XCTAssertEqual(UsageStore.retryDelay(base: 300, rateLimits: 0), 300)
        XCTAssertEqual(UsageStore.retryDelay(base: 120, rateLimits: 1), 300)
        XCTAssertEqual(UsageStore.retryDelay(base: 300, rateLimits: 2), 600)
        XCTAssertEqual(UsageStore.retryDelay(base: 300, rateLimits: 3), 1200)
        XCTAssertEqual(UsageStore.retryDelay(base: 300, rateLimits: 9), 1800)
    }
}
