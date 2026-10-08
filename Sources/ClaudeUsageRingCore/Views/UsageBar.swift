import SwiftUI

public struct UsageBar: View {
    private let title: String
    private let window: UsageWindow
    private let now: Date

    public init(title: String, window: UsageWindow, now: Date) {
        self.title = title
        self.window = window
        self.now = now
    }

    public var body: some View {
        let utilization = window.utilization(at: now)
        let level = RingLevel(utilization: utilization)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(Int((utilization * 100).rounded()))%")
                    .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(level.color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(level.color.opacity(0.15))
                    Capsule().fill(level.color)
                        .frame(width: geo.size.width * RingGeometry.trimEnd(for: utilization))
                }
            }
            .frame(height: 6)
            if let resetsAt = window.resetsAt {
                Text(resetsAt > now
                     ? "Resets in \(CountdownFormatter.string(from: now, to: resetsAt))"
                     : "Reset — waiting for fresh data")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}
