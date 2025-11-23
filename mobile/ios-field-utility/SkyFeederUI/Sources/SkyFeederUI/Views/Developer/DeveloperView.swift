import SwiftUI

public struct DeveloperView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @StateObject private var viewModel: DevViewModel
    
    public init(settingsStore: SettingsStore) {
        _viewModel = StateObject(wrappedValue: DevViewModel(settingsStore: settingsStore))
    }
    
    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Power Diagnostics")) {
                    HStack {
                        Text("Voltage")
                        Spacer()
                        Text(String(format: "%.2f V", viewModel.telemetry?.packVoltage ?? 0))
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                    HStack {
                        Text("Solar")
                        Spacer()
                        Text(String(format: "%.1f W", viewModel.telemetry?.solarWatts ?? 0))
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                    HStack {
                        Text("Load")
                        Spacer()
                        Text(String(format: "%.1f W", viewModel.telemetry?.loadWatts ?? 0))
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                }
                
                if let connectivity = viewModel.connectivity {
                    Section(header: Text("Network Diagnostics")) {
                        HStack {
                            Text("SSID")
                            Spacer()
                            Text(connectivity.ssid)
                                .foregroundColor(DesignSystem.textSecondary)
                        }
                        HStack {
                            Text("Ping")
                            Spacer()
                            Text("\(connectivity.pingMs) ms")
                                .foregroundColor(DesignSystem.textSecondary)
                        }
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(connectivity.isConnected ? "Connected" : "Disconnected")
                                .foregroundColor(connectivity.isConnected ? DesignSystem.statusOnline : DesignSystem.statusOffline)
                        }
                    }
                }
                
                if !viewModel.logs.isEmpty {
                    Section(header: Text("System Logs")) {
                        ForEach(viewModel.logs) { log in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.caption)
                                        .foregroundColor(DesignSystem.textSecondary)
                                    Spacer()
                                }
                                Text(log.message)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Developer")
            .task { await viewModel.refresh() }
            .refreshable { await viewModel.refresh() }
        }
    }
}
