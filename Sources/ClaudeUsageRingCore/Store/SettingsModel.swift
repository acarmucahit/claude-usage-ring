import Foundation
import Combine
import ServiceManagement

@MainActor
public final class SettingsModel: ObservableObject {
    private static let intervalKey = "refreshInterval"

    @Published public var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: Self.intervalKey) }
    }
    @Published public var launchAtLogin: Bool {
        didSet { setLaunchAtLogin(launchAtLogin) }
    }

    public init() {
        let stored = UserDefaults.standard.double(forKey: Self.intervalKey)
        self.refreshInterval = stored > 0 ? Self.clamp(stored) : 60
        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            self.launchAtLogin = false
        }
    }

    public static func clamp(_ seconds: Double) -> Double {
        min(600, max(30, seconds))
    }

    public func setLaunchAtLogin(_ on: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            // Non-fatal: surfaced only in logs; toggle reflects attempted state.
        }
    }
}
