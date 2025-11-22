import SwiftUI

public struct RootView: View {
    @StateObject private var dashboardViewModel: DashboardViewModel
    
    public init() {
        let settingsState = SettingsState(userDefaults: .standard)
        let deviceService = LiveDeviceService(settingsState: settingsState)
        let visitService = LiveVisitService(settingsState: settingsState)
        let statsService = LiveStatsService(settingsState: settingsState)
        
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(
            deviceService: deviceService,
            visitService: visitService,
            statsService: statsService
        ))
    }
    
    public var body: some View {
        TabView {
            DashboardView(viewModel: dashboardViewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            DeveloperView()
                .tabItem {
                    Label("Developer", systemImage: "hammer.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(DesignSystem.primaryTeal)
        .preferredColorScheme(.dark) // Force dark mode as per design requirement
    }
}
