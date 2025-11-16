import SwiftUI

public struct DevView: View {
    @ObservedObject var viewModel: DevViewModel

    public init(viewModel: DevViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    DevicesCard(viewModel: viewModel)
                    ConnectivityCard(connectivity: viewModel.connectivity)
                    PowerTelemetryCard(
                        telemetry: viewModel.telemetry,
                        retentionPolicy: viewModel.retentionPolicy,
                        onRunCleanup: { viewModel.runCleanupNow() }
                    )
                    ActionsCard(viewModel: viewModel)
                    LogsCard(logs: viewModel.logs)
                }
                .padding()
            }
            .background(DesignSystem.background.ignoresSafeArea())
            .navigationTitle("SkyFeeder Dev")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.onAppear()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

// MARK: - Devices Card

struct DevicesCard: View {
    @ObservedObject var viewModel: DevViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Devices")
                .font(DesignSystem.title3())
                .foregroundColor(DesignSystem.textPrimary)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.textSecondary)
                TextField("Search devices", text: $viewModel.searchText)
                    .font(DesignSystem.body())
            }
            .padding(12)
            .background(DesignSystem.background)
            .cornerRadius(8)

            ForEach(viewModel.filteredDevices) { device in
                DeviceRow(device: device)
                if device.id != viewModel.filteredDevices.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(DesignSystem.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct DeviceRow: View {
    let device: DeviceSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cube.box")
                .foregroundColor(DesignSystem.textSecondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.id)
                    .font(DesignSystem.body())
                    .foregroundColor(DesignSystem.textPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(device.isOnline ? DesignSystem.statusOnline : DesignSystem.statusOffline)
                        .frame(width: 8, height: 8)
                    Text(device.isOnline ? "Online" : "Offline")
                        .font(DesignSystem.caption())
                        .foregroundColor(DesignSystem.textSecondary)
                }

                Text("Last contact: \(device.lastContact, style: .relative)")
                    .font(DesignSystem.caption2())
                    .foregroundColor(DesignSystem.textSecondary)
            }

            Spacer()

            Text("\(device.batteryPercentage)%")
                .font(DesignSystem.body())
                .foregroundColor(DesignSystem.textSecondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Connectivity Card

struct ConnectivityCard: View {
    let connectivity: ConnectivityDiagnostics?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connectivity")
                .font(DesignSystem.title3())
                .foregroundColor(DesignSystem.textPrimary)

            if let connectivity = connectivity {
                InfoRow(label: "Status", value: connectivity.statusText)
                InfoRow(label: "Recent failures", value: "\(connectivity.recentFailures)")
                if let roundtrip = connectivity.averageRoundtripMs {
                    InfoRow(label: "Average roundtrip", value: "\(roundtrip) ms")
                }
                if let lastSync = connectivity.lastSync {
                    InfoRow(label: "Last sync", value: "\(lastSync, style: .relative) ago")
                }
            } else {
                ProgressView()
            }
        }
        .padding()
        .background(DesignSystem.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Power & Telemetry Card

struct PowerTelemetryCard: View {
    let telemetry: TelemetrySnapshot?
    let retentionPolicy: RetentionPolicy?
    let onRunCleanup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Power & Telemetry")
                .font(DesignSystem.title3())
                .foregroundColor(DesignSystem.textPrimary)

            if let telemetry = telemetry {
                InfoRow(label: "Pack voltage", value: String(format: "%.2f V", telemetry.packVoltage))
                InfoRow(label: "Solar input", value: String(format: "%.1f W", telemetry.solarWatts))
                InfoRow(label: "Load power", value: String(format: "%.1f W", telemetry.loadWatts))
                InfoRow(label: "Internal temp", value: String(format: "%.1f °C", telemetry.internalTempC))
                InfoRow(label: "Signal strength", value: "\(telemetry.signalStrengthDbm) dBm")
            }

            if let policy = retentionPolicy {
                Divider()
                InfoRow(label: "PHOTO_RETENTION_DAYS", value: "\(policy.photoRetentionDays)")
                InfoRow(label: "VIDEO_RETENTION_DAYS", value: "\(policy.videoRetentionDays)")

                Button(action: onRunCleanup) {
                    Text("Run cleanup now")
                        .font(DesignSystem.body())
                        .foregroundColor(DesignSystem.primaryTeal)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(DesignSystem.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Actions Card

struct ActionsCard: View {
    @ObservedObject var viewModel: DevViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(DesignSystem.title3())
                .foregroundColor(DesignSystem.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ActionButton(title: "Force telemetry", action: { viewModel.forceTelemetry() })
                ActionButton(title: "Request snapshot", action: { viewModel.requestSnapshot() })
                ActionButton(title: "Reboot", action: { viewModel.reboot() })
                ActionButton(title: "Factory reset", isDangerous: true, action: { viewModel.factoryReset() })
            }
        }
        .padding()
        .background(DesignSystem.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct ActionButton: View {
    let title: String
    var isDangerous: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.subheadline())
                .foregroundColor(isDangerous ? DesignSystem.batteryRed : DesignSystem.primaryTeal)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(isDangerous ? DesignSystem.batteryRed : DesignSystem.primaryTeal, lineWidth: 1)
                )
        }
    }
}

// MARK: - Logs Card

struct LogsCard: View {
    let logs: [LogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Logs")
                .font(DesignSystem.title3())
                .foregroundColor(DesignSystem.textPrimary)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logs) { log in
                        HStack(alignment: .top, spacing: 8) {
                            Text(log.timestamp, style: .time)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(DesignSystem.textSecondary)
                                .frame(width: 60, alignment: .leading)

                            Text(log.message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(DesignSystem.textPrimary)
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding(12)
            .background(DesignSystem.background)
            .cornerRadius(8)
        }
        .padding()
        .background(DesignSystem.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.body())
                .foregroundColor(DesignSystem.textSecondary)

            Spacer()

            Text(value)
                .font(DesignSystem.body())
                .foregroundColor(DesignSystem.textPrimary)
        }
    }
}
