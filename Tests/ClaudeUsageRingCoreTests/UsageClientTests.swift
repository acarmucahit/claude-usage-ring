import XCTest
@testable import ClaudeUsageRingCore

private struct StubTransport: Transport {
    let data: Data
    let status: Int
    var capturedAuth: (@Sendable (String?) -> Void)? = nil
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        capturedAuth?(request.value(forHTTPHeaderField: "Authorization"))
        let resp = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: nil, headerFields: nil)!
        return (data, resp)
    }
}

final class UsageClientTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testFetchParsesSnapshotAndSendsBearer() async throws {
        let json = Data(#"""
        { "five_hour": { "utilization": 20.0, "resets_at": "2026-06-23T17:00:00Z" },
          "seven_day": { "utilization": 40.0, "resets_at": "2026-06-27T12:00:00Z" } }
        """#.utf8)
        let box = AuthBox()
        let now = self.now
        let transport = StubTransport(data: json, status: 200) { box.value = $0 }
        let client = UsageClient(tokenProvider: { "tok-123" }, transport: transport, now: { now })
        let snap = try await client.fetch()
        XCTAssertEqual(snap.fiveHour.utilization, 0.2, accuracy: 0.0001)
        XCTAssertEqual(box.value, "Bearer tok-123")
    }

    func testUnauthorizedMapsToError() async {
        let now = self.now
        let transport = StubTransport(data: Data("{}".utf8), status: 401)
        let client = UsageClient(tokenProvider: { "x" }, transport: transport, now: { now })
        do { _ = try await client.fetch(); XCTFail("expected throw") }
        catch { XCTAssertEqual(error as? UsageError, .unauthorized) }
    }
}

final class AuthBox: @unchecked Sendable { var value: String? }
