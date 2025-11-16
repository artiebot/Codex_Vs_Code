import Foundation
import Combine

@MainActor
public class OptionsViewModel: ObservableObject {
    @Published public var settings: OptionsSettings
    @Published public var retentionPolicy: RetentionPolicy?

    private static let settingsKey = "SkyFeederOptionsSettings"
    private let dataProvider: FeederDataProviding?
    private let settingsStore: SettingsStore

    public init(
        settingsStore: SettingsStore,
        dataProvider: FeederDataProviding? = nil
    ) {
        self.settingsStore = settingsStore
        self.dataProvider = dataProvider
        self.settings = Self.loadSettings()
    }

    public func onAppear() {
        Task {
            await loadRetentionPolicy()
        }
    }

    public var minTriggerRange: ClosedRange<Double> {
        10...500
    }

    public var minTriggerStep: Double {
        10
    }

    public func updateMinTriggerWeight(_ weight: Int) {
        settings.minTriggerWeightGrams = weight
        saveSettings()
    }

    public func updateCaptureType(_ type: CaptureType) {
        settings.captureType = type
        saveSettings()
    }

    public func updateCaptureCooldown(_ seconds: Int) {
        settings.captureCooldownSeconds = seconds
        saveSettings()
    }

    public func toggleQuietHours(_ enabled: Bool) {
        settings.quietHoursEnabled = enabled
        saveSettings()
    }

    public func updateQuietHoursStart(_ components: DateComponents) {
        settings.quietHoursStart = components
        saveSettings()
    }

    public func updateQuietHoursEnd(_ components: DateComponents) {
        settings.quietHoursEnd = components
        saveSettings()
    }

    public func toggleNotifyLowBattery(_ enabled: Bool) {
        settings.notifyLowBattery = enabled
        saveSettings()
    }

    public func toggleNotifyOnVisitor(_ enabled: Bool) {
        settings.notifyOnVisitor = enabled
        saveSettings()
    }

    public func toggleTimeZoneAutoDetect(_ enabled: Bool) {
        settings.timeZoneAutoDetect = enabled
        saveSettings()
    }

    // MARK: - Persistence

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: Self.settingsKey)
        }
    }

    private static func loadSettings() -> OptionsSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(OptionsSettings.self, from: data) else {
            return OptionsSettings()
        }
        return decoded
    }

    private func loadRetentionPolicy() async {
        if let provider = dataProvider {
            retentionPolicy = try? await provider.fetchRetentionPolicy()
        } else {
            retentionPolicy = RetentionPolicy(photoRetentionDays: 7, videoRetentionDays: 3)
        }
    }
}
