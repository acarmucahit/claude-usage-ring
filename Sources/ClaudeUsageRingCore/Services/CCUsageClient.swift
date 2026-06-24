import Foundation

public struct BlockUsage: Equatable, Sendable {
    public let costUSD: Double
    public let burnUSDPerHour: Double?
    public init(costUSD: Double, burnUSDPerHour: Double?) {
        self.costUSD = costUSD
        self.burnUSDPerHour = burnUSDPerHour
    }
}

public enum CCUsageParser {
    public static func parse(_ data: Data, now: Date) -> BlockUsage? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = root["blocks"] as? [[String: Any]],
              let active = blocks.first(where: { ($0["isActive"] as? Bool) == true }),
              let cost = (active["costUSD"] as? NSNumber)?.doubleValue else {
            return nil
        }
        var burn: Double? = nil
        if let startStr = active["startTime"] as? String,
           let start = parseISO(startStr) {
            let hours = now.timeIntervalSince(start) / 3600
            if hours > 0.05 { burn = cost / hours }
        }
        return BlockUsage(costUSD: cost, burnUSDPerHour: burn)
    }

    private static func parseISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

public struct CCUsageClient: Sendable {
    private let runner: @Sendable () -> Data?
    private let now: @Sendable () -> Date

    public init(runner: @escaping @Sendable () -> Data?,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.runner = runner
        self.now = now
    }

    public func current() -> BlockUsage? {
        guard let data = runner() else { return nil }
        return CCUsageParser.parse(data, now: now())
    }

    public static let live = CCUsageClient(runner: {
        // Resolve ccusage from PATH; return nil if not installed.
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        which.arguments = ["which", "ccusage"]
        let wpipe = Pipe()
        which.standardOutput = wpipe
        which.standardError = Pipe()
        guard (try? which.run()) != nil else { return nil }
        which.waitUntilExit()
        let path = String(decoding: wpipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard which.terminationStatus == 0, !path.isEmpty else { return nil }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = ["blocks", "--active", "--json"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        guard (try? p.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return p.terminationStatus == 0 ? data : nil
    })
}
