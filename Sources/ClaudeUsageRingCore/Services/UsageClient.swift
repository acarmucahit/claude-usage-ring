import Foundation

public protocol Transport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

public struct URLSessionTransport: Transport {
    public init() {}
    public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

public enum UsageError: Error, Equatable {
    case unauthorized
    case http(Int)
}

public struct UsageClient: Sendable {
    private let tokenProvider: @Sendable () async throws -> String
    private let transport: Transport
    private let now: @Sendable () -> Date
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    public init(tokenProvider: @escaping @Sendable () async throws -> String,
                transport: Transport = URLSessionTransport(),
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.tokenProvider = tokenProvider
        self.transport = transport
        self.now = now
    }

    public func fetch() async throws -> UsageSnapshot {
        let token = try await tokenProvider()
        var req = URLRequest(url: Self.endpoint)
        req.timeoutInterval = 5
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await transport.send(req)
        if let http = resp as? HTTPURLResponse {
            if http.statusCode == 401 { throw UsageError.unauthorized }
            guard (200..<300).contains(http.statusCode) else { throw UsageError.http(http.statusCode) }
        }
        return try UsageParser.parse(data, now: now())
    }
}
