import Foundation
import Combine
import ServiceManagement

@MainActor
public final class SettingsModel: ObservableObject {
    private static let intervalKey = "refreshInterval"
    private static let loginOfferedKey = "launchAtLoginOffered"

    private let defaults: UserDefaults

    @Published public var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: Self.intervalKey) }
    }
    /// Mirrors the real login-item status; change it with setLaunchAtLogin(_:).
    @Published public private(set) var launchAtLogin: Bool
    @Published public private(set) var launchAtLoginNeedsApproval = false

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: Self.intervalKey)
        self.refreshInterval = stored > 0 ? Self.clamp(stored) : 300
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// The usage endpoint rate-limits polling at about a minute, so stay well above that.
    public static func clamp(_ seconds: Double) -> Double {
        min(1800, max(120, seconds))
    }

    /// The point of the app is to be always visible, so turn launch at login
    /// on once; after that the user's choice in the menu wins.
    public func enableLaunchAtLoginOnFirstRun() {
        guard !defaults.bool(forKey: Self.loginOfferedKey) else { return }
        defaults.set(true, forKey: Self.loginOfferedKey)
        setLaunchAtLogin(true)
    }

    public func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("ClaudeUsageRing: launch at login %@ failed: %@", on ? "register" : "unregister", "\(error)")
        }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        launchAtLoginNeedsApproval = status == .requiresApproval
    }
}
