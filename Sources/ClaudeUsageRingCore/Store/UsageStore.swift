import Foundation
import Combine

@MainActor
public final class UsageStore: ObservableObject {
    @Published public private(set) var state: UsageState = .loading
    @Published public private(set) var block: BlockUsage? = nil

    private let client: UsageClient
    private let ccusage: CCUsageClient?
    private let interval: () -> TimeInterval
    private var loopTask: Task<Void, Never>?

    private var lastSnapshot: UsageSnapshot?
    private(set) var rateLimited = false

    /// Minimum sleep after a rate-limited (429) response, regardless of the
    /// configured interval, to let the server-side limit recover.
    static let rateLimitCooldown: TimeInterval = 300

    public init(client: UsageClient, ccusage: CCUsageClient?, interval: @escaping () -> TimeInterval) {
        self.client = client
        self.ccusage = ccusage
        self.interval = interval
    }

    public func refresh() async {
        do {
            let snap = try await client.fetch()
            lastSnapshot = snap
            state = .ok(snap)
            rateLimited = false
        } catch {
            rateLimited = (error as? UsageError) == .http(429)
            // Keep showing the last good data on a transient failure; only
            // surface an error if we have never succeeded.
            if let last = lastSnapshot {
                state = .ok(last)
            } else {
                state = .failed(Self.message(for: error))
            }
        }
        if let cc = ccusage {
            block = await Task.detached { cc.current() }.value
        }
    }

    public func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let base = self?.interval() ?? 60
                let limited = self?.rateLimited ?? false
                let secs = limited ? max(base, Self.rateLimitCooldown) : base
                try? await Task.sleep(nanoseconds: UInt64(max(10, secs) * 1_000_000_000))
            }
        }
    }

    public func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    public static func message(for error: Error) -> String {
        if let e = error as? UsageError {
            switch e {
            case .unauthorized: return "Unauthorized — is Claude signed in?"
            case .http(429): return "Rate limited — backing off"
            case .http(let code): return "Server error (\(code))"
            }
        }
        if error is TokenError { return "Claude session not found" }
        if error is UsageParseError { return "Unexpected response format" }
        return "Can't connect"
    }
}
