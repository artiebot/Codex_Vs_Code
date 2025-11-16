import SwiftUI
import SkyFeederUI

@main
struct SkyFeederFieldUtilityApp: App {
    @StateObject private var settingsStore: SettingsStore
    private let dataProvider: FeederDataProviding

    init() {
        AppTheme.apply()

        let info = Bundle.main.infoDictionary ?? [:]
        let allowLocalHttp = info["SKAllowLocalHttp"] as? Bool ?? false
        let defaultProviderName = (info["SKDefaultProvider"] as? String) ?? "presigned"
        let defaultProvider = SkyFeederUI.CaptureProviderSelection(rawValue: defaultProviderName) ?? .presigned
        let showDevTools = info["SKEnableDevTools"] as? Bool ?? true

        let store = SettingsStore(
            defaultProvider: defaultProvider,
            allowLocalHttp: allowLocalHttp,
            showDevTools: showDevTools
        )
        _settingsStore = StateObject(wrappedValue: store)
        dataProvider = LiveFeederDataProvider(settingsStore: store)
    }

    var body: some Scene {
        WindowGroup {
            SkyFeederRootView(settingsStore: settingsStore, dataProvider: dataProvider)
        }
    }
}
