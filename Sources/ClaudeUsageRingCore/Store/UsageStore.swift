import Foundation
import Combine

@MainActor
public final class UsageStore: ObservableObject {
    @Published public private(set) var state: UsageState = .loading
    @Published public private(set) var block: BlockUsage? = nil
    @Published public private(set) var lastSuccessAt: Date?
    @Published public private(set) var lastError: String?

    private let client: UsageClient
    private let ccusage: CCUsageClient?
    private let interval: () -> TimeInterval
    private let now: () -> Date
    private let tickInterval: TimeInterval
    private var loopTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?

    private var lastSnapshot: UsageSnapshot?
    private(set) var consecutiveRateLimits = 0

    public init(client: UsageClient, ccusage: CCUsageClient?,
                interval: @escaping () -> TimeInterval,
                now: @escaping () -> Date = { Date() },
                tickInterval: TimeInterval = 60) {
        self.client = client
        self.ccusage = ccusage
        self.interval = interval
        self.now = now
        self.tickInterval = tickInterval
    }

    public func refresh() async {
        do {
            let snap = try await client.fetch()
            lastSnapshot = snap
            state = .ok(snap)
            lastSuccessAt = now()
            lastError = nil
            consecutiveRateLimits = 0
        } catch {
            if (error as? UsageError) == .http(429) { consecutiveRateLimits += 1 }
            lastError = Self.message(for: error)
            // Keep showing the last good data on failure; views use isStale(at:)
            // and lastError to say it is no longer live.
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

    /// True once the shown numbers are too old to pass for live data.
    public func isStale(at date: Date) -> Bool {
        guard let lastSuccessAt else { return false }
        return date.timeIntervalSince(lastSuccessAt) > max(2 * interval(), 15 * 60)
    }

    /// /api/oauth/usage throttles hard; after a 429 it can keep refusing for a
    /// long time, so each consecutive 429 doubles the wait (5m, 10m, 20m, 30m).
    static func retryDelay(base: TimeInterval, rateLimits: Int) -> TimeInterval {
        guard rateLimits > 0 else { return base }
        let backoff = 300 * pow(2, Double(min(rateLimits, 8) - 1))
        return min(1800, max(base, backoff))
    }

    public func start(after delay: TimeInterval = 0) {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            while !Task.isCancelled {
                await self?.refresh()
                guard let secs = self?.nextDelay() else { return }
                try? await Task.sleep(nanoseconds: UInt64(max(10, secs) * 1_000_000_000))
            }
        }
        // Views judge staleness and resets against the clock, but only redraw
        // when the store publishes; a hung fetch or a 30-minute back-off would
        // otherwise leave an old number looking live.
        let tick = tickInterval
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
                self?.objectWillChange.send()
            }
        }
    }

    private func nextDelay() -> TimeInterval {
        Self.retryDelay(base: interval(), rateLimits: consecutiveRateLimits)
    }

    public func stop() {
        loopTask?.cancel()
        loopTask = nil
        tickTask?.cancel()
        tickTask = nil
    }

    /// Task.sleep does not count time spent asleep, so after wake the pending
    /// wait would resume from where it stopped. Restart the loop instead,
    /// giving the network a moment to come back.
    public func refreshAfterWake() {
        stop()
        start(after: 10)
    }

    public nonisolated static func message(for error: Error) -> String {
        if let e = error as? UsageError {
            switch e {
            case .unauthorized: return "Claude Code sign-in expired — open Claude Code to resume"
            case .http(429): return "Rate limited by Anthropic — retrying later"
            case .http(let code): return "Server error (\(code))"
            }
        }
        if error is TokenError { return "Claude Code sign-in not found" }
        if error is UsageParseError { return "Unexpected response format" }
        return "Can't connect"
    }
}
