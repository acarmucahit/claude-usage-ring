import SwiftUI
import ServiceManagement

public struct MenuContent: View {
    @ObservedObject private var store: UsageStore
    @ObservedObject private var settings: SettingsModel
    private let quit: () -> Void

    public init(store: UsageStore, settings: SettingsModel, quit: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.quit = quit
    }

    public var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 12) {
            switch store.state {
            case .ok(let snap):
                UsageBar(title: "5-hour", window: snap.fiveHour, now: now)
                UsageBar(title: "Weekly", window: snap.weekly, now: now)
            case .loading:
                Text("Loading…").foregroundStyle(.secondary)
            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }

            if case .ok = store.state {
                VStack(alignment: .leading, spacing: 2) {
                    if let at = store.lastSuccessAt {
                        Text(now.timeIntervalSince(at) < 60
                             ? "Updated just now"
                             : "Updated \(CountdownFormatter.string(from: at, to: now)) ago")
                    }
                    if let err = store.lastError {
                        Label(err, systemImage: "exclamationmark.triangle")
                    }
                }
                .font(.system(size: 10)).foregroundStyle(.secondary)
            }

            if let b = store.block {
                Divider()
                HStack(spacing: 6) {
                    Text(String(format: "Block: $%.2f", b.costUSD))
                    if let burn = b.burnUSDPerHour {
                        Text("·"); Text(String(format: "🔥 $%.0f/hr", burn))
                    }
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Picker("Refresh", selection: Binding(
                    get: { settings.refreshInterval },
                    set: { settings.refreshInterval = SettingsModel.clamp($0) })) {
                    Text("2m").tag(120.0)
                    Text("5m").tag(300.0)
                    Text("15m").tag(900.0)
                }
                .pickerStyle(.menu).labelsHidden().frame(width: 80)
                Spacer()
                Button("Quit", action: quit)
            }
            Toggle("Launch at login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }))
                .font(.system(size: 11)).toggleStyle(.checkbox)
            if settings.launchAtLoginNeedsApproval {
                Button("Approve in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    .font(.system(size: 11))
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}
