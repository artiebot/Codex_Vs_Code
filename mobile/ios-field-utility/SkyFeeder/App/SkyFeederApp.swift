import SwiftUI
import SkyFeederUI

@main
struct SkyFeederApp: App {
    @StateObject private var settingsStore: SettingsStore
    private let dataProvider: FeederDataProviding

    init() {
        AppTheme.apply()

        let info = Bundle.main.infoDictionary ?? [:]
        let allowLocalHttp = info["SKAllowLocalHttp"] as? Bool ?? false
        let defaultProviderName = (info["SKDefaultProvider"] as? String) ?? "PresignedHTTP"
        let defaultProvider = CaptureProviderSelection(from: defaultProviderName)
        let showDevTools = info["SKEnableDevTools"] as? Bool ?? true

        let store = SettingsStore(
            defaultProvider: defaultProvider,
            allowLocalHttp: allowLocalHttp,
            showDevTools: showDevTools
        )
        _settingsStore = StateObject(wrappedValue: store)
        dataProvider = MockFeederDataProvider()
    }

    var body: some Scene {
        WindowGroup {
            SkyFeederRootView(settingsStore: settingsStore, dataProvider: dataProvider)
        }
    }
}
