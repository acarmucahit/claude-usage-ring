import SwiftUI
import ClaudeUsageRingCore

@main
struct ClaudeUsageRingApp: App {
    @StateObject private var store: UsageStore
    @StateObject private var settings: SettingsModel

    init() {
        let client = UsageClient(tokenProvider: {
            try TokenReader.live.token()
        })
        if CommandLine.arguments.contains("--check") { UsageCheck.run(client) }

        let settings = SettingsModel()
        let store = UsageStore(
            client: client,
            ccusage: CCUsageClient.live,
            interval: { settings.refreshInterval }
        )
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: store)
        settings.enableLaunchAtLoginOnFirstRun()
        store.start()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in store.refreshAfterWake() }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(store: store, settings: settings) {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// `ClaudeUsageRing --check`: one fetch through the same path the menu bar
/// uses, printed to the terminal, for troubleshooting.
enum UsageCheck {
    static func run(_ client: UsageClient) -> Never {
        let done = DispatchSemaphore(value: 0)
        let result = ResultBox()
        Task.detached {
            do {
                let s = try await client.fetch()
                let now = Date()
                result.text = [line("5-hour", s.fiveHour, now), line("Weekly", s.weekly, now)].joined(separator: "\n")
                result.ok = true
            } catch {
                result.text = "error: " + UsageStore.message(for: error)
            }
            done.signal()
        }
        done.wait()
        print(result.text)
        exit(result.ok ? 0 : 1)
    }

    private static func line(_ title: String, _ w: UsageWindow, _ now: Date) -> String {
        let pct = Int((w.utilization(at: now) * 100).rounded())
        guard let r = w.resetsAt, r > now else { return "\(title): \(pct)%" }
        return "\(title): \(pct)% (resets in \(CountdownFormatter.string(from: now, to: r)))"
    }

    private final class ResultBox: @unchecked Sendable {
        var text = ""
        var ok = false
    }
}
