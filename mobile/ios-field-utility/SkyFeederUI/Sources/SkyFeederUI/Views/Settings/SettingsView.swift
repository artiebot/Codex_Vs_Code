import SwiftUI

public struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Device")) {
                    Picker("Default Device", selection: $viewModel.selectedDeviceId) {
                        Text("SkyFeeder-01").tag("sf-01")
                        Text("SkyFeeder-02").tag("sf-02")
                    }
                    
                    Text("Timezone: Use device timezone")
                        .foregroundColor(DesignSystem.textSecondary)
                }
                
                Section(header: Text("Detection")) {
                    VStack(alignment: .leading) {
                        Text("Sensitivity")
                        Slider(value: $viewModel.sensitivity)
                            .tint(DesignSystem.primaryTeal)
                    }
                    
                    Toggle("Quiet Hours", isOn: $viewModel.quietHoursEnabled)
                        .tint(DesignSystem.primaryTeal)
                    
                    if viewModel.quietHoursEnabled {
                        DatePicker("Start", selection: $viewModel.quietHoursStart, displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: $viewModel.quietHoursEnd, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $viewModel.theme) {
                        Text("Light").tag(SettingsViewModel.AppTheme.light)
                        Text("Dark").tag(SettingsViewModel.AppTheme.dark)
                        Text("System").tag(SettingsViewModel.AppTheme.system)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Firmware Version")
                        Spacer()
                        Text("1.2.0")
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                    HStack {
                        Text("Build Number")
                        Spacer()
                        Text("142")
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                    Link("Documentation", destination: URL(string: "https://example.com/docs")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
