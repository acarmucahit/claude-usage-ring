import Foundation

public struct UsageWindow: Equatable, Sendable {
    public let utilization: Double   // 0.0 ... 1.0
    public let resetsAt: Date
    public init(utilization: Double, resetsAt: Date) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }
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
