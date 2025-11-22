import SwiftUI
import SkyFeederUI

struct SkyFeederRootView: View {
    @ObservedObject var settingsStore: SettingsStore
    let dataProvider: FeederDataProviding

    var body: some View {
        FeederView(viewModel: FeederViewModel(dataProvider: dataProvider))
            .environmentObject(settingsStore)
    }
}
