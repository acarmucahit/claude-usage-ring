import SwiftUI

public struct MenuBarLabel: View {
    @ObservedObject private var store: UsageStore
    public init(store: UsageStore) { self.store = store }

    public var body: some View {
        switch store.state {
        case .ok(let snap):
            HStack(spacing: 4) {
                Image(nsImage: MiniBarsRenderer.image(
                    weekly: snap.weekly.utilization,
                    fiveHour: snap.fiveHour.utilization, enabled: true))
                Text("\(Int((snap.fiveHour.utilization * 100).rounded()))%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        case .loading:
            Image(nsImage: MiniBarsRenderer.image(weekly: 0, fiveHour: 0, enabled: false))
        case .failed:
            Image(nsImage: MiniBarsRenderer.image(weekly: 0, fiveHour: 0, enabled: false))
        }
    }
}
