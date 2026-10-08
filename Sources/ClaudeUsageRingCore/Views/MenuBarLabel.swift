import SwiftUI

public struct MenuBarLabel: View {
    @ObservedObject private var store: UsageStore
    public init(store: UsageStore) { self.store = store }

    public var body: some View {
        switch store.state {
        case .ok(let snap):
            let now = Date()
            let fiveHour = snap.fiveHour.utilization(at: now)
            HStack(spacing: 4) {
                // Grey bars mean the numbers are no longer live.
                Image(nsImage: MiniBarsRenderer.image(
                    weekly: snap.weekly.utilization(at: now),
                    fiveHour: fiveHour, enabled: !store.isStale(at: now)))
                Text("\(Int((fiveHour * 100).rounded()))%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        case .loading:
            Image(nsImage: MiniBarsRenderer.image(weekly: 0, fiveHour: 0, enabled: false))
        case .failed:
            HStack(spacing: 4) {
                Image(nsImage: MiniBarsRenderer.image(weekly: 0, fiveHour: 0, enabled: false))
                Text("—")
            }
        }
    }
}
