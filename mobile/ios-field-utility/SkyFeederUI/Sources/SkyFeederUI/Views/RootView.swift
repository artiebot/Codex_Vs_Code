import SwiftUI

public struct SkyFeederRootView: View {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var feederViewModel: FeederViewModel
    @StateObject private var optionsViewModel: OptionsViewModel
    @StateObject private var devViewModel: DevViewModel

    public init(
        settingsStore: SettingsStore,
        dataProvider: FeederDataProviding = MockFeederDataProvider()
    ) {
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _feederViewModel = StateObject(
            wrappedValue: FeederViewModel(dataProvider: dataProvider)
        )
        _optionsViewModel = StateObject(
            wrappedValue: OptionsViewModel(settingsStore: settingsStore, dataProvider: dataProvider)
        )
        _devViewModel = StateObject(wrappedValue: DevViewModel(settingsStore: settingsStore))
    }

    public var body: some View {
        TabView {
            FeederView(viewModel: feederViewModel)
                .tabItem {
                    Label("Feeder", systemImage: "house.fill")
                }

            OptionsView(viewModel: optionsViewModel)
                .tabItem {
                    Label("Options", systemImage: "slider.horizontal.3")
                }

            if settingsStore.showDevTools {
                DevView(viewModel: devViewModel)
                    .tabItem {
                        Label("Dev", systemImage: "wrench.fill")
                    }
            }
        }
        .tint(DesignSystem.primaryTeal)
    }
}
