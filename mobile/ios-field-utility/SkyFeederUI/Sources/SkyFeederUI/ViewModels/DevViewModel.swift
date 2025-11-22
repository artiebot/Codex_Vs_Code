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
    private let devicesProvider: DevicesProvider
    private let connectivityProvider: ConnectivityProvider
    private let telemetryProvider: TelemetryProvider
    private let logsSummaryProvider: LogsSummaryProvider
    private let actionProvider: DashboardActionProvider

    public init(
        settingsStore: SettingsStore,
        settingsProvider: SettingsProvider = SettingsProvider(),
        devicesProvider: DevicesProvider = DevicesProvider(),
        connectivityProvider: ConnectivityProvider = ConnectivityProvider(),
        telemetryProvider: TelemetryProvider = TelemetryProvider(),
        logsSummaryProvider: LogsSummaryProvider = LogsSummaryProvider(),
        actionProvider: DashboardActionProvider = DashboardActionProvider()
    ) {
        self.settingsStore = settingsStore
        self.settingsProvider = settingsProvider
        self.devicesProvider = devicesProvider
        self.connectivityProvider = connectivityProvider
        self.telemetryProvider = telemetryProvider
        self.logsSummaryProvider = logsSummaryProvider
        self.actionProvider = actionProvider
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
            guard let baseURL = settingsStore.state.apiBaseURL else {
                throw SettingsProviderError.invalidResponse
            }

            async let devicesTask: [DeviceSummary] = devicesProvider.fetchDevices(baseURL: baseURL)
            async let connectivityTask: ConnectivityDiagnostics = connectivityProvider.fetchConnectivity(
                baseURL: baseURL,
                deviceId: settingsStore.state.deviceID
            )
            async let telemetryTask: TelemetryResponse = telemetryProvider.fetchTelemetry(
                baseURL: baseURL,
                deviceId: settingsStore.state.deviceID
            )
            async let settingsTask: DeviceSettings = settingsProvider.fetchSettings(
                baseURL: baseURL,
                deviceId: settingsStore.state.deviceID
            )
            async let logsTask: [LogEntry] = logsSummaryProvider.fetchSummary(
                baseURL: baseURL,
                deviceId: settingsStore.state.deviceID,
                limit: 50
            )

            let devicesResult = try await devicesTask
            let connectivityResult = try await connectivityTask
            let telemetryResult = try await telemetryTask
            let settingsResult = try await settingsTask
            let logsResult = try await logsTask

            devices = devicesResult
            filterDevices()
            connectivity = connectivityResult
            telemetry = TelemetrySnapshot(
                packVoltage: telemetryResult.packVoltage,
                solarWatts: telemetryResult.solarWatts,
                loadWatts: telemetryResult.loadWatts,
                internalTempC: telemetryResult.internalTempC,
                signalStrengthDbm: telemetryResult.signalStrengthDbm
            )
            retentionPolicy = RetentionPolicy(
                photoRetentionDays: settingsResult.photoRetentionDays,
                videoRetentionDays: settingsResult.videoRetentionDays
            )
            logs = logsResult
            captureCooldownSeconds = settingsResult.cooldownSeconds
            ambMiniStatus = mapModeToAmbMiniStatus(telemetryResult.mode)
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

    // MARK: - API Methods

    private func mapModeToAmbMiniStatus(_ mode: String) -> String {
        switch mode.lowercased() {
        case "sleeping":
            return "Sleeping"
        case "capture":
            return "Capturing"
        case "idle":
            return "Idle"
        case "offline":
            return "Offline"
        default:
            return "Unknown (\(mode))"
        }
    }

    private func performCleanup() async throws {
        guard let baseURL = settingsStore.state.apiBaseURL else {
            throw DashboardActionError.missingAPIBase
        }
        let deviceId = settingsStore.state.deviceID

        // Clean up both photos and videos
        _ = try await actionProvider.perform(action: .cleanupPhotos, baseURL: baseURL, deviceId: deviceId)
        _ = try await actionProvider.perform(action: .cleanupVideos, baseURL: baseURL, deviceId: deviceId)
    }

    private func performForceTelemetry() async throws {
        // Force telemetry is simply a refresh of the current data
        // The refresh() method already fetches fresh telemetry from the backend
    }

    private func performRequestSnapshot() async throws {
        guard let baseURL = settingsStore.state.apiBaseURL else {
            throw DashboardActionError.missingAPIBase
        }
        let deviceId = settingsStore.state.deviceID

        _ = try await actionProvider.perform(action: .snapshot, baseURL: baseURL, deviceId: deviceId)
    }

    private func performReboot() async throws {
        guard let baseURL = settingsStore.state.apiBaseURL else {
            throw DashboardActionError.missingAPIBase
        }
        let deviceId = settingsStore.state.deviceID

        _ = try await actionProvider.perform(action: .reboot, baseURL: baseURL, deviceId: deviceId)
    }
}
