import SwiftUI
import SkyFeederUI

@main
struct SkyFeederApp: App {
    @StateObject private var settingsStore: SettingsStore

    init() {
        AppTheme.apply()

        let info = Bundle.main.infoDictionary ?? [:]
        let allowLocalHttp = info["SKAllowLocalHttp"] as? Bool ?? false
        let defaultProviderName = (info["SKDefaultProvider"] as? String) ?? "PresignedHTTP"
        let defaultProvider = CaptureProviderSelection(from: defaultProviderName)

        _settingsStore = StateObject(
            wrappedValue: SettingsStore(
                defaultProvider: defaultProvider,
                allowLocalHttp: allowLocalHttp
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            SkyFeederRootView(settingsStore: settingsStore)
        }
    }
}
