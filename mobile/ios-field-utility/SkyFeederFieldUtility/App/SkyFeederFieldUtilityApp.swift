import SwiftUI
import SkyFeederUI

@main
struct SkyFeederFieldUtilityApp: App {
    @StateObject private var settingsStore: SettingsStore

    init() {
        AppTheme.apply()

        let info = Bundle.main.infoDictionary ?? [:]
        let allowLocalHttp = info["SKAllowLocalHttp"] as? Bool ?? false
        let defaultProviderName = (info["SKDefaultProvider"] as? String) ?? "presigned"
        let defaultProvider = CaptureProviderSelection(rawValue: defaultProviderName) ?? .presigned

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
