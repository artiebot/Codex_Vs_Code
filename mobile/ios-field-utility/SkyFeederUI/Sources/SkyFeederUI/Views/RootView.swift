import SwiftUI

public struct SkyFeederRootView: View {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var feederViewModel: FeederViewModel
    @StateObject private var optionsViewModel: OptionsViewModel
    #if DEBUG
    @StateObject private var devViewModel: DevViewModel
    #endif

    public init(settingsStore: SettingsStore) {
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _feederViewModel = StateObject(wrappedValue: FeederViewModel(settingsStore: settingsStore))
        _optionsViewModel = StateObject(wrappedValue: OptionsViewModel(settingsStore: settingsStore))
        #if DEBUG
        _devViewModel = StateObject(wrappedValue: DevViewModel(settingsStore: settingsStore))
        #endif
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

            #if DEBUG
            DevView(viewModel: devViewModel)
                .tabItem {
                    Label("Dev", systemImage: "wrench.fill")
                }
            #endif
        }
        .tint(DesignSystem.primaryTeal)
    }
}
