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
                Section(header: Text("Backend")) {
                    HStack {
                        Text("Base URL")
                        Spacer()
                        Text(settingsStore.state.apiBaseURL?.absoluteString ?? "Not set")
                            .foregroundColor(DesignSystem.textSecondary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Device ID")
                        Spacer()
                        Text(settingsStore.state.deviceID)
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                    HStack {
                        Text("Manifest")
                        Spacer()
                        Text(settingsStore.state.manifestURL?.absoluteString ?? "Not set")
                            .foregroundColor(DesignSystem.textSecondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Power Diagnostics")) {
                    HStack {
                        Text("Voltage")
                        Spacer()
                        Text(String(format: "%.2f V", viewModel.telemetry?.packVoltage ?? 0))
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                    if let battery = viewModel.telemetry?.batteryPercent {
                        HStack {
                            Text("Battery Level")
                            Spacer()
                            Text("\(battery)%")
                                .foregroundColor(battery > 20 ? DesignSystem.textSecondary : .red)
                        }
                    }
                    if let isCharging = viewModel.telemetry?.isChargingViaSolar {
                        HStack {
                            Text("Charging Status")
                            Spacer()
                            Text(isCharging ? "Charging" : "Discharging")
                                .foregroundColor(isCharging ? .green : DesignSystem.textSecondary)
                        }
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
                            Text("Status")
                            Spacer()
                            Text(connectivity.statusText)
                                .foregroundColor(connectivity.statusText.lowercased() == "healthy" ? DesignSystem.statusOnline : DesignSystem.statusOffline)
                        }
                        if let avgPing = connectivity.averageRoundtripMs {
                            HStack {
                                Text("Avg Ping")
                                Spacer()
                                Text("\(avgPing) ms")
                                    .foregroundColor(DesignSystem.textSecondary)
                            }
                        }
                        HStack {
                            Text("Recent Failures")
                            Spacer()
                            Text("\(connectivity.recentFailures)")
                                .foregroundColor(DesignSystem.textSecondary)
                        }
                    }
                }
                
                Section(header: Text("System Logs")) {
                    if viewModel.logs.isEmpty {
                        Text("No logs yet. Confirm /api/logs/summary is reachable.")
                            .font(.caption)
                            .foregroundColor(DesignSystem.textSecondary)
                    } else {
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

                if let error = viewModel.errorMessage {
                    Section(header: Text("Errors")) {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Developer")
            .task { await viewModel.refresh() }
            .refreshable { await viewModel.refresh() }
        }
    }
}
