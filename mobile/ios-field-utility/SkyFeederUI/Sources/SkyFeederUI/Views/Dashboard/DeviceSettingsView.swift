import SwiftUI

public struct DeviceSettingsView: View {
    @ObservedObject var viewModel: DeviceSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: DeviceSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Weight Threshold")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(viewModel.weightThreshold))g")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $viewModel.weightThreshold,
                        in: 1...500,
                        step: 1
                    )
                    .tint(.blue)
                    Text("Minimum weight to trigger a capture (1-500 grams)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cooldown Period")
                            .font(.subheadline)
                        Spacer()
                        Text(formatCooldown(viewModel.cooldownSeconds))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("Time between captures")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("Camera Enabled", isOn: $viewModel.cameraEnabled)
                    .font(.subheadline)
            } header: {
                Text("Device Settings")
            }

            Section {
                Button {
                    Task { await viewModel.testTrigger() }
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Test Trigger")
                    }
                }

                Button {
                    Task { await viewModel.saveSettings() }
                } label: {
                    if viewModel.isSaving {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Saving...")
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Settings")
                        }
                    }
                }
                .disabled(viewModel.isSaving)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            if let success = viewModel.successMessage {
                Section {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Device Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSettings()
        }
    }

    private func formatCooldown(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}
