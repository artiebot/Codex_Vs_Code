import Foundation
import Combine

@MainActor
public class DevViewModel: ObservableObject {
    @Published public var devices: [DeviceSummary] = []
    @Published public var filteredDevices: [DeviceSummary] = []
    @Published public var searchText: String = "" {
        didSet {
            filterDevices()
        }
    }
    @Published public var connectivity: ConnectivityDiagnostics?
    @Published public var telemetry: TelemetrySnapshot?
    @Published public var retentionPolicy: RetentionPolicy?
    @Published public var logs: [LogEntry] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var captureCooldownSeconds: Int?
    @Published public var ambMiniStatus: String = "Unknown"

    private let settingsStore: SettingsStore
    private let settingsProvider: SettingsProvider

    public init(settingsStore: SettingsStore, settingsProvider: SettingsProvider = SettingsProvider()) {
        self.settingsStore = settingsStore
        self.settingsProvider = settingsProvider
    }

    public func onAppear() {
        Task {
            await refresh()
        }
    }

    public func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            devices = try await fetchDevices()
            filterDevices()
            connectivity = try await fetchConnectivity()
            telemetry = try await fetchTelemetry()
            retentionPolicy = try await fetchRetentionPolicy()
            logs = try await fetchLogs()
            captureCooldownSeconds = try? await fetchCaptureCooldown()
            ambMiniStatus = await resolveAmbMiniStatus()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func runCleanupNow() {
        Task {
            do {
                try await performCleanup()
                addLog(message: "Cleanup completed successfully")
            } catch {
                errorMessage = "Cleanup failed: \(error.localizedDescription)"
            }
        }
    }

    public func forceTelemetry() {
        Task {
            do {
                try await performForceTelemetry()
                addLog(message: "Telemetry refresh requested")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await refresh()
            } catch {
                errorMessage = "Force telemetry failed: \(error.localizedDescription)"
            }
        }
    }

    public func requestSnapshot() {
        Task {
            do {
                try await performRequestSnapshot()
                addLog(message: "Snapshot requested")
            } catch {
                errorMessage = "Request snapshot failed: \(error.localizedDescription)"
            }
        }
    }

    public func reboot() {
        Task {
            do {
                try await performReboot()
                addLog(message: "Reboot command sent")
            } catch {
                errorMessage = "Reboot failed: \(error.localizedDescription)"
            }
        }
    }

    public func factoryReset() {
        addLog(message: "Factory reset not implemented (dangerous operation)")
    }

    private func filterDevices() {
        if searchText.isEmpty {
            filteredDevices = devices
        } else {
            filteredDevices = devices.filter { $0.id.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func addLog(message: String) {
        let entry = LogEntry(timestamp: Date(), message: message)
        logs.insert(entry, at: 0)
    }

    // MARK: - API Methods (mocked)

    private func fetchDevices() async throws -> [DeviceSummary] {
        // For now, Dev tools target the single configured device.
        let id = settingsStore.state.deviceID
        return [
            DeviceSummary(
                id: id,
                isOnline: true,
                batteryPercentage: 78,
                lastContact: Date()
            )
        ]
    }

    private func fetchConnectivity() async throws -> ConnectivityDiagnostics {
        try await Task.sleep(nanoseconds: 300_000_000)
        return ConnectivityDiagnostics(
            statusText: "Healthy",
            recentFailures: 0,
            averageRoundtripMs: 320,
            lastSync: Date().addingTimeInterval(-120)
        )
    }

    private func fetchTelemetry() async throws -> TelemetrySnapshot {
        // TODO: Replace with real telemetry endpoint when available.
        try await Task.sleep(nanoseconds: 300_000_000)
        return TelemetrySnapshot(
            packVoltage: 3.92,
            solarWatts: 3.6,
            loadWatts: 1.2,
            internalTempC: 24.5,
            signalStrengthDbm: -63
        )
    }

    private func fetchCaptureCooldown() async throws -> Int {
        guard let base = settingsStore.state.apiBaseURL else {
            throw SettingsProviderError.invalidResponse
        }
        let settings = try await settingsProvider.fetchSettings(
            baseURL: base,
            deviceId: settingsStore.state.deviceID
        )
        return settings.cooldownSeconds
    }

    private func resolveAmbMiniStatus() async -> String {
        // TODO: Replace with real device mode when backend exposes it.
        // For now, derive a coarse status from connectivity/telemetry presence.
        if connectivity == nil {
            return "Unknown"
        }
        if telemetry == nil {
            return "Sleeping (no telemetry sample)"
        }
        return "Active (captures/telemetry available)"
    }

    private func fetchRetentionPolicy() async throws -> RetentionPolicy {
        try await Task.sleep(nanoseconds: 300_000_000)
        return RetentionPolicy(photoRetentionDays: 7, videoRetentionDays: 3)
    }

    private func fetchLogs() async throws -> [LogEntry] {
        try await Task.sleep(nanoseconds: 300_000_000)
        let now = Date()
        return [
            LogEntry(timestamp: now.addingTimeInterval(-60), message: "Received response 200"),
            LogEntry(timestamp: now.addingTimeInterval(-180), message: "Request sent"),
            LogEntry(timestamp: now.addingTimeInterval(-240), message: "Received response 200")
        ]
    }

    private func performCleanup() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    private func performForceTelemetry() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    private func performRequestSnapshot() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    private func performReboot() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }
}
