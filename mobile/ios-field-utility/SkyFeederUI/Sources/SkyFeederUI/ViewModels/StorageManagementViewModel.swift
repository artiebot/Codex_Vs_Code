import Foundation

@MainActor
public final class StorageManagementViewModel: ObservableObject {
    @Published public private(set) var isDeleting = false
    @Published public private(set) var isDownloading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var successMessage: String?
    @Published public private(set) var downloadedLogsURL: URL?

    private let settingsStore: SettingsStore
    private let actionProvider: DashboardActionProvider
    private let logsProvider: LogsProvider

    public init(
        settingsStore: SettingsStore,
        actionProvider: DashboardActionProvider = DashboardActionProvider(),
        logsProvider: LogsProvider = LogsProvider()
    ) {
        self.settingsStore = settingsStore
        self.actionProvider = actionProvider
        self.logsProvider = logsProvider
    }

    public func deleteAllPhotos() async {
        guard let baseURL = settingsStore.state.apiBaseURL else {
            errorMessage = "Missing API base URL."
            return
        }

        isDeleting = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await performCleanup(
                baseURL: baseURL,
                action: .cleanupPhotos
            )
            successMessage = response.message ?? "All photos deleted"
            dismissMessageAfterDelay()
            isDeleting = false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isDeleting = false
        }
    }

    public func deleteAllVideos() async {
        guard let baseURL = settingsStore.state.apiBaseURL else {
            errorMessage = "Missing API base URL."
            return
        }

        isDeleting = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await performCleanup(
                baseURL: baseURL,
                action: .cleanupVideos
            )
            successMessage = response.message ?? "All videos deleted"
            dismissMessageAfterDelay()
            isDeleting = false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isDeleting = false
        }
    }

    public func downloadLogs() async {
        guard let baseURL = settingsStore.state.apiBaseURL else {
            errorMessage = "Missing API base URL."
            return
        }

        isDownloading = true
        errorMessage = nil
        successMessage = nil
        downloadedLogsURL = nil

        do {
            let logsText = try await logsProvider.fetchLogs(
                baseURL: baseURL,
                services: ["presign-api", "ws-relay", "minio"],
                lines: 300
            )

            // Save to temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileURL = tempDir.appendingPathComponent("skyfeeder-logs-\(timestamp).txt")
            try logsText.write(to: fileURL, atomically: true, encoding: .utf8)

            downloadedLogsURL = fileURL
            successMessage = "Logs downloaded successfully"
            dismissMessageAfterDelay()
            isDownloading = false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isDownloading = false
        }
    }

    private func performCleanup(
        baseURL: URL,
        action: CleanupAction
    ) async throws -> CleanupResponse {
        let url = baseURL.appendingPathComponent(action.rawValue)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Payload: Encodable {
            let deviceId: String
        }

        request.httpBody = try JSONEncoder().encode(Payload(deviceId: settingsStore.state.deviceID))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StorageManagementError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw StorageManagementError.httpStatus(http.statusCode)
        }

        return try JSONDecoder().decode(CleanupResponse.self, from: data)
    }

    private func dismissMessageAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return }
            withAnimation {
                successMessage = nil
                errorMessage = nil
            }
        }
    }
}

enum CleanupAction: String {
    case cleanupPhotos = "api/cleanup/photos"
    case cleanupVideos = "api/cleanup/videos"
}

struct CleanupResponse: Decodable {
    let success: Bool
    let deviceId: String
    let deleted: Int
    let message: String?
}

enum StorageManagementError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Cleanup response was invalid."
        case .httpStatus(let code):
            return "Cleanup failed (HTTP \(code))."
        }
    }
}
