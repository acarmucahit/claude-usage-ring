import SwiftUI
import ClaudeUsageRingCore

@main
struct ClaudeUsageRingApp: App {
    @StateObject private var store: UsageStore
    @StateObject private var settings: SettingsModel

    init() {
        let settings = SettingsModel()
        let client = UsageClient(tokenProvider: {
            try TokenReader.live.token()
        })
        let store = UsageStore(
            client: client,
            ccusage: CCUsageClient.live,
            interval: { settings.refreshInterval }
        )
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: store)
        store.start()
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
