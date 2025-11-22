import SwiftUI

public struct DeveloperView: View {
    @StateObject private var viewModel = DeveloperViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Power Diagnostics")) {
                    HStack {
                        Text("Voltage")
                        Spacer()
                        Text(String(format: "%.2f V", viewModel.batteryVoltage))
                    }
                    HStack {
                        Text("Current")
                        Spacer()
                        Text(String(format: "%.2f A", viewModel.batteryCurrent))
                    }
                    HStack {
                        Text("Remaining")
                        Spacer()
                        Text("\(viewModel.remainingHours) h")
                    }
                }
                
                Section(header: Text("Network Diagnostics")) {
                    HStack {
                        Text("SSID")
                        Spacer()
                        Text(viewModel.ssid)
                    }
                    HStack {
                        Text("RSSI")
                        Spacer()
                        Text("\(viewModel.rssi) dBm")
                    }
                    HStack {
                        Text("Ping")
                        Spacer()
                        Text("\(viewModel.pingTimeMs) ms")
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(viewModel.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(viewModel.isConnected ? DesignSystem.statusOnline : DesignSystem.statusOffline)
                    }
                }
                
                Section(header: Text("System Logs")) {
                    ForEach(viewModel.logs) { log in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.textSecondary)
                                Spacer()
                                Text(log.level == .error ? "ERROR" : "INFO")
                                    .font(.caption)
                                    .foregroundColor(log.level == .error ? DesignSystem.batteryRed : DesignSystem.textSecondary)
                            }
                            Text(log.message)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section {
                    Button("Send Diagnostics Bundle") {
                        viewModel.sendDiagnostics()
                    }
                    .foregroundColor(DesignSystem.primaryTeal)
                }
            }
            .navigationTitle("Developer")
        }
    }
}
