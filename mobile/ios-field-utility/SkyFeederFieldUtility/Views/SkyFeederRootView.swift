import SwiftUI
import SkyFeederUI

struct SkyFeederRootView: View {
    @ObservedObject var settingsStore: SettingsStore
    let dataProvider: FeederDataProviding

    var body: some View {
        TabView {
            DashboardView(
                viewModel: DashboardViewModel(
                    deviceService: MockDeviceService(),
                    visitService: MockVisitService(),
                    statsService: MockStatsService()
                )
            )
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }

            DeveloperView()
                .tabItem {
                    Label("Developer", systemImage: "hammer.fill")
                }

            SkyFeederUI.SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .environmentObject(settingsStore)
    }
}
