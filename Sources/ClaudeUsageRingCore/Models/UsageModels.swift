import Foundation

public struct UsageWindow: Equatable, Sendable {
    public let utilization: Double   // 0.0 ... 1.0
    public let resetsAt: Date?       // nil when the API reports no active window
    public init(utilization: Double, resetsAt: Date?) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }

    /// A fetched value stops being true once its window resets, so it reads 0
    /// until the next successful fetch.
    public func utilization(at now: Date) -> Double {
        if let resetsAt, resetsAt <= now { return 0 }
        return utilization
    }

    static let unused = UsageWindow(utilization: 0, resetsAt: nil)
}

public struct UsageSnapshot: Equatable, Sendable {
    public let fiveHour: UsageWindow
    public let weekly: UsageWindow
    public init(fiveHour: UsageWindow, weekly: UsageWindow) {
        self.fiveHour = fiveHour
        self.weekly = weekly
    }
}

public enum UsageState: Equatable, Sendable {
    case loading
    case ok(UsageSnapshot)
    case failed(String)
}
