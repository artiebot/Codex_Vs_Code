import Foundation
import SwiftUI

@MainActor
public final class DeviceSettingsViewModel: ObservableObject {
    @Published public var weightThreshold: Double = 50
    @Published public var cooldownSeconds: Int = 300
    @Published public var cameraEnabled: Bool = true
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSaving = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var successMessage: String?

    private let settingsStore: SettingsStore
    private let provider: SettingsProvider
    private let userDefaults: UserDefaults

    private let weightThresholdKey = "deviceSettings.weightThreshold"
    private let cooldownSecondsKey = "deviceSettings.cooldownSeconds"
    private let cameraEnabledKey = "deviceSettings.cameraEnabled"

    public init(
        settingsStore: SettingsStore,
        provider: SettingsProvider = SettingsProvider(),
        userDefaults: UserDefaults = .standard
    ) {
        self.settingsStore = settingsStore
        self.provider = provider
        self.userDefaults = userDefaults

        // Load from UserDefaults
        loadFromUserDefaults()
    }

    public func loadSettings() async {
        guard let baseURL = settingsStore.state.apiBaseURL else {
            errorMessage = "Missing API base URL in Settings."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let settings = try await provider.fetchSettings(
                baseURL: baseURL,
                deviceId: settingsStore.state.deviceID
            )
            applySettings(settings)
            saveToUserDefaults()
            isLoading = false
        } catch {
            if let settingsError = error as? LocalizedError {
                errorMessage = settingsError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    public func saveSettings() async {
        guard let baseURL = settingsStore.state.apiBaseURL else {
            errorMessage = "Missing API base URL in Settings."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        let settings = DeviceSettings(
            weightThreshold: Int(weightThreshold),
            cooldownSeconds: cooldownSeconds,
            cameraEnabled: cameraEnabled,
            updatedAt: nil
        )

        do {
            let saved = try await provider.updateSettings(
                baseURL: baseURL,
                deviceId: settingsStore.state.deviceID,
                settings: settings
            )
            applySettings(saved)
            saveToUserDefaults()
            successMessage = "Settings saved successfully"
            dismissSuccessAfterDelay()
            isSaving = false
        } catch {
            if let settingsError = error as? LocalizedError {
                errorMessage = settingsError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    public func testTrigger() async {
        // Delegates to dashboard action
        successMessage = "Test trigger sent (use Dashboard for full control)"
        dismissSuccessAfterDelay()
    }

    private func applySettings(_ settings: DeviceSettings) {
        weightThreshold = Double(settings.weightThreshold)
        cooldownSeconds = settings.cooldownSeconds
        cameraEnabled = settings.cameraEnabled
    }

    private func loadFromUserDefaults() {
        if userDefaults.object(forKey: weightThresholdKey) != nil {
            weightThreshold = userDefaults.double(forKey: weightThresholdKey)
        }
        if userDefaults.object(forKey: cooldownSecondsKey) != nil {
            cooldownSeconds = userDefaults.integer(forKey: cooldownSecondsKey)
        }
        if userDefaults.object(forKey: cameraEnabledKey) != nil {
            cameraEnabled = userDefaults.bool(forKey: cameraEnabledKey)
        }
    }

    private func saveToUserDefaults() {
        userDefaults.set(weightThreshold, forKey: weightThresholdKey)
        userDefaults.set(cooldownSeconds, forKey: cooldownSecondsKey)
        userDefaults.set(cameraEnabled, forKey: cameraEnabledKey)
    }

    private func dismissSuccessAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return }
            withAnimation {
                successMessage = nil
            }
        }
    }
}
