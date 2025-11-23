import Foundation

public class LiveDeviceService: DeviceServiceProtocol {
    private let provider: DevicesProvider
    private let telemetryProvider: TelemetryProvider
    private let settingsState: SettingsState
    
    public init(settingsState: SettingsState) {
        self.provider = DevicesProvider()
        self.telemetryProvider = TelemetryProvider()
        self.settingsState = settingsState
    }
    
    public func getDevices() async throws -> [DeviceStatus] {
        guard let baseURL = settingsState.apiBaseURL else {
            throw MediaProviderError.missingAPIBase
        }
        
        let summaries = try await provider.fetchDevices(baseURL: baseURL)
        
        return summaries.map { summary in
            DeviceStatus(
                id: summary.id,
                name: summary.id,
                batteryPercentage: summary.batteryPercentage,
                wifiSignalStrength: 0, // Placeholder, fetch in getCurrentDevice
                temperatureCelsius: 0.0, // Placeholder
                isOnline: summary.isOnline
            )
        }
    }
    
    public func getCurrentDevice() async throws -> DeviceStatus? {
        let devices = try await getDevices()
        let selectedId = settingsState.deviceID // Use deviceID from settings
        
        guard let device = devices.first(where: { $0.id == selectedId }) ?? devices.first else {
            return nil
        }
        
        // Try to fetch telemetry for the current device to get real stats
        if let baseURL = settingsState.apiBaseURL {
            do {
                let telemetry = try await telemetryProvider.fetchTelemetry(baseURL: baseURL, deviceId: device.id)
                return DeviceStatus(
                    id: device.id,
                    name: device.name,
                    // Telemetry battery is now optional; fall back to the device summary value when missing.
                    batteryPercentage: telemetry.batteryPercent ?? device.batteryPercentage,
                    wifiSignalStrength: telemetry.signalStrengthDbm,
                    temperatureCelsius: telemetry.internalTempC,
                    isOnline: device.isOnline
                )
            } catch {
                print("Failed to fetch telemetry for \(device.id): \(error)")
                // Return device with defaults if telemetry fails
                return device
            }
        }
        
        return device
    }
}
