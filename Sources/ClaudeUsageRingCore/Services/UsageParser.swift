import Foundation

public enum UsageParseError: Error, Equatable {
    case notObject
    case missingWindow(String)
}

/// Parses the `/api/oauth/usage` response.
///
/// Confirmed schema (2026-06): `utilization` is on a 0–100 scale, and a
/// `limits` array carries unambiguous integer `percent` values keyed by
/// `kind` ("session", "weekly_all", "weekly_scoped"). We prefer the `limits`
/// array and fall back to the top-level `five_hour` / `seven_day` objects.
public enum UsageParser {
    public static func parse(_ data: Data, now: Date) throws -> UsageSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageParseError.notObject
        }
        let five = try fiveHourWindow(root, now: now)
        let week = try weeklyWindow(root, now: now)
        return UsageSnapshot(fiveHour: five, weekly: week)
    }

    private static func fiveHourWindow(_ root: [String: Any], now: Date) throws -> UsageWindow {
        if let w = limitWindow(root, kinds: ["session"], group: "session", now: now) { return w }
        if let w = objectWindow(root, keys: ["five_hour", "fiveHour", "5h"], now: now) { return w }
        throw UsageParseError.missingWindow("five_hour")
    }

    private static func weeklyWindow(_ root: [String: Any], now: Date) throws -> UsageWindow {
        // Prefer the all-models weekly limit; skip model-scoped (e.g. Sonnet-only).
        if let w = limitWindow(root, kinds: ["weekly_all", "weekly"], group: "weekly",
                               now: now, requireUnscoped: true) { return w }
        if let w = objectWindow(root, keys: ["seven_day", "weekly", "sevenDay", "7d"], now: now) { return w }
        throw UsageParseError.missingWindow("seven_day")
    }

    // MARK: - Sources

    private static func limitWindow(_ root: [String: Any], kinds: [String], group: String,
                                    now: Date, requireUnscoped: Bool = false) -> UsageWindow? {
        guard let limits = root["limits"] as? [[String: Any]] else { return nil }
        for item in limits {
            let kindMatch = (item["kind"] as? String).map { kinds.contains($0) } ?? false
            let groupMatch = (item["group"] as? String) == group
            guard kindMatch || groupMatch else { continue }
            if requireUnscoped, item["scope"] is [String: Any] { continue }
            guard let percent = number(item["percent"]) else { continue }
            return UsageWindow(utilization: fraction(percent), resetsAt: date(item["resets_at"], now: now))
        }
        return nil
    }

    private static func objectWindow(_ root: [String: Any], keys: [String], now: Date) -> UsageWindow? {
        for k in keys {
            if let obj = root[k] as? [String: Any], let u = number(obj["utilization"]) {
                return UsageWindow(utilization: fraction(u), resetsAt: date(obj["resets_at"], now: now))
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

    private static func date(_ v: Any?, now: Date) -> Date {
        if let s = v as? String, let d = parseISO(s) { return d }
        if let n = number(v) {
            return Date(timeIntervalSince1970: n > 1_000_000_000_000 ? n / 1000 : n)
        }
        return now
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
