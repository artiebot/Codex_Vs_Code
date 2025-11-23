import SwiftUI

public struct RootView: View {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var dashboardViewModel: DashboardViewModel
    
    public init() {
        let store = SettingsStore(userDefaults: .standard)
        _settingsStore = StateObject(wrappedValue: store)
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(settingsStore: store))
    }
    
    public var body: some View {
        TabView {
            DashboardView(viewModel: dashboardViewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            DeveloperView(settingsStore: settingsStore)
                .tabItem {
                    Label("Developer", systemImage: "hammer.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .environmentObject(settingsStore)
        .tint(DesignSystem.primaryTeal)
        .preferredColorScheme(.dark) // Force dark mode as per design requirement
    }
}
