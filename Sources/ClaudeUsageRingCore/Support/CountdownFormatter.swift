import Foundation

public enum CountdownFormatter {
    /// Human-readable countdown: "4d 6h", "3h 42m", "12m", "now".
    public static func string(from now: Date, to target: Date) -> String {
        let total = Int(target.timeIntervalSince(now))
        if total <= 0 { return "now" }
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
