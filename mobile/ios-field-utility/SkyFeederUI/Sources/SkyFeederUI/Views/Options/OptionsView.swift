import SwiftUI

public struct OptionsView: View {
    @ObservedObject var viewModel: OptionsViewModel

    public init(viewModel: OptionsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    CaptureSettingsSection(viewModel: viewModel)
                    TimeQuietHoursSection(viewModel: viewModel)
                    NotificationsSection(viewModel: viewModel)
                    StorageRetentionSection(viewModel: viewModel)
                    AdvancedSection(viewModel: viewModel)
                }
                .padding()
            }
            .background(DesignSystem.background.ignoresSafeArea())
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.onAppear()
            }
        }
    }
}

// MARK: - Capture Settings Section

struct CaptureSettingsSection: View {
    @ObservedObject var viewModel: OptionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Capture Settings")
                .font(DesignSystem.headline())
                .foregroundColor(DesignSystem.textSecondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                SettingsRow(
                    title: "Min trigger weight",
                    value: "\(viewModel.settings.minTriggerWeightGrams) g"
                )

                Divider()

                SettingsRow(
                    title: "Capture type",
                    value: viewModel.settings.captureType.displayName
                )

                // Radio buttons for capture type
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(CaptureType.allCases, id: \.self) { type in
                        Button(action: {
                            viewModel.updateCaptureType(type)
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(DesignSystem.primaryTeal, lineWidth: 2)
                                        .frame(width: 20, height: 20)

                                    if viewModel.settings.captureType == type {
                                        Circle()
                                            .fill(DesignSystem.primaryTeal)
                                            .frame(width: 12, height: 12)
                                    }
                                }

                                Text(type.displayName)
                                    .font(DesignSystem.body())
                                    .foregroundColor(DesignSystem.textPrimary)

                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                Divider()

                SettingsRow(
                    title: "Capture cooldown",
                    value: "\(viewModel.settings.captureCooldownSeconds) sec"
                )
            }
            .background(DesignSystem.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }
}

// MARK: - Time & Quiet Hours Section

struct TimeQuietHoursSection: View {
    @ObservedObject var viewModel: OptionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Time & Quiet Hours")
                .font(DesignSystem.headline())
                .foregroundColor(DesignSystem.textSecondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                HStack {
                    Text("Enable")
                        .font(DesignSystem.body())
                        .foregroundColor(DesignSystem.textPrimary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { viewModel.settings.quietHoursEnabled },
                        set: { viewModel.toggleQuietHours($0) }
                    ))
                    .tint(DesignSystem.primaryTeal)
                }
                .padding()

                if viewModel.settings.quietHoursEnabled {
                    Divider()

                    SettingsRow(
                        title: "From",
                        value: formatTimeComponents(viewModel.settings.quietHoursStart)
                    )

                    Divider()

                    SettingsRow(
                        title: "To",
                        value: formatTimeComponents(viewModel.settings.quietHoursEnd)
                    )

                    Divider()

                    Text("No captures or notifications at night.")
                        .font(DesignSystem.caption())
                        .foregroundColor(DesignSystem.textSecondary)
                        .padding()
                }
            }
            .background(DesignSystem.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }

    func formatTimeComponents(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - Notifications Section

struct NotificationsSection: View {
    @ObservedObject var viewModel: OptionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notifications")
                .font(DesignSystem.headline())
                .foregroundColor(DesignSystem.textSecondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                HStack {
                    Text("Notify on low battery")
                        .font(DesignSystem.body())
                        .foregroundColor(DesignSystem.textPrimary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { viewModel.settings.notifyLowBattery },
                        set: { viewModel.toggleNotifyLowBattery($0) }
                    ))
                    .tint(DesignSystem.primaryTeal)
                }
                .padding()

                Divider()

                HStack {
                    Text("Notify when feeder sees a visitor")
                        .font(DesignSystem.body())
                        .foregroundColor(DesignSystem.textPrimary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { viewModel.settings.notifyOnVisitor },
                        set: { viewModel.toggleNotifyOnVisitor($0) }
                    ))
                    .tint(DesignSystem.primaryTeal)
                }
                .padding()
            }
            .background(DesignSystem.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }
}

// MARK: - Storage & Retention Section

struct StorageRetentionSection: View {
    @ObservedObject var viewModel: OptionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Storage & Retention")
                .font(DesignSystem.headline())
                .foregroundColor(DesignSystem.textSecondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                if let policy = viewModel.retentionPolicy {
                    SettingsRow(
                        title: "Photos kept for",
                        value: "\(policy.photoRetentionDays) days"
                    )

                    Divider()

                    SettingsRow(
                        title: "Videos kept for",
                        value: "\(policy.videoRetentionDays) days"
                    )

                    Divider()

                    Text("Controlled by SkyFeeder — not adjustable here.")
                        .font(DesignSystem.caption())
                        .foregroundColor(DesignSystem.textSecondary)
                        .padding()
                } else {
                    HStack {
                        ProgressView()
                        Text("Loading...")
                            .font(DesignSystem.body())
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                    .padding()
                }
            }
            .background(DesignSystem.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }
}

// MARK: - Advanced Section

struct AdvancedSection: View {
    @ObservedObject var viewModel: OptionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Advanced")
                .font(DesignSystem.headline())
                .foregroundColor(DesignSystem.textSecondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                SettingsRow(
                    title: "Time zone",
                    value: viewModel.settings.timeZoneAutoDetect ? "Auto-detect" : "Manual"
                )
            }
            .background(DesignSystem.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(DesignSystem.body())
                .foregroundColor(DesignSystem.textPrimary)

            Spacer()

            Text(value)
                .font(DesignSystem.body())
                .foregroundColor(DesignSystem.textSecondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(DesignSystem.textSecondary)
        }
        .padding()
    }
}
