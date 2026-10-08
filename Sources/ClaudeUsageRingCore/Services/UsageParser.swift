import Foundation

public enum UsageParseError: Error, Equatable {
    case notObject
    case noWindows
}

/// Parses the `/api/oauth/usage` response.
///
/// Confirmed schema (2026-06): `utilization` is on a 0–100 scale, and a
/// `limits` array carries unambiguous integer `percent` values keyed by
/// `kind` ("session", "weekly_all", "weekly_scoped"). We prefer the `limits`
/// array and fall back to the top-level `five_hour` / `seven_day` objects.
/// Either window may be null (no active window); that counts as unused.
/// Only a response with neither window is rejected.
public enum UsageParser {
    public static func parse(_ data: Data, now: Date) throws -> UsageSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageParseError.notObject
        }
        let five = fiveHourWindow(root)
        let week = weeklyWindow(root)
        if five == nil && week == nil { throw UsageParseError.noWindows }
        return UsageSnapshot(fiveHour: five ?? .unused, weekly: week ?? .unused)
    }

    private static func fiveHourWindow(_ root: [String: Any]) -> UsageWindow? {
        limitWindow(root, kinds: ["session"], group: "session")
            ?? objectWindow(root, keys: ["five_hour", "fiveHour", "5h"])
    }

    private static func weeklyWindow(_ root: [String: Any]) -> UsageWindow? {
        // Prefer the all-models weekly limit; skip model-scoped (e.g. Sonnet-only).
        limitWindow(root, kinds: ["weekly_all", "weekly"], group: "weekly", requireUnscoped: true)
            ?? objectWindow(root, keys: ["seven_day", "weekly", "sevenDay", "7d"])
    }

    // MARK: - Sources

    private static func limitWindow(_ root: [String: Any], kinds: [String], group: String,
                                    requireUnscoped: Bool = false) -> UsageWindow? {
        guard let limits = root["limits"] as? [[String: Any]] else { return nil }
        for item in limits {
            let kindMatch = (item["kind"] as? String).map { kinds.contains($0) } ?? false
            let groupMatch = (item["group"] as? String) == group
            guard kindMatch || groupMatch else { continue }
            if requireUnscoped, item["scope"] is [String: Any] { continue }
            guard let percent = number(item["percent"]) else { continue }
            return UsageWindow(utilization: fraction(percent), resetsAt: date(item["resets_at"]))
        }
        return nil
    }

    private static func objectWindow(_ root: [String: Any], keys: [String]) -> UsageWindow? {
        for k in keys {
            if let obj = root[k] as? [String: Any], let u = number(obj["utilization"]) {
                return UsageWindow(utilization: fraction(u), resetsAt: date(obj["resets_at"]))
            }
        }
        return nil
    }

    // MARK: - Helpers

    /// The API reports utilization on a 0–100 scale; convert to 0...1 and clamp.
    private static func fraction(_ percent: Double) -> Double {
        min(1.0, max(0.0, percent / 100.0))
    }

    private static func number(_ v: Any?) -> Double? {
        (v as? NSNumber)?.doubleValue
    }

    private static func date(_ v: Any?) -> Date? {
        if let s = v as? String, let d = parseISO(s) { return d }
        if let n = number(v) {
            return Date(timeIntervalSince1970: n > 1_000_000_000_000 ? n / 1000 : n)
        }
        return nil
    }

    private static func parseISO(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        for opts in [[.withInternetDateTime, .withFractionalSeconds],
                     [.withInternetDateTime]] as [ISO8601DateFormatter.Options] {
            iso.formatOptions = opts
            if let d = iso.date(from: s) { return d }
        }
        // Fallback for >3 fractional digits (e.g. microseconds) with an offset.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                    "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
