import Foundation
import UIKit

@MainActor
public final class LiveStreamViewModel: ObservableObject {
    @Published public private(set) var latestFrame: UIImage?
    @Published public private(set) var isStreaming = false
    @Published public private(set) var statusMessage: String?

    private let settingsStore: SettingsStore
    private let session: URLSession
    private var task: Task<Void, Never>?
    private var retryIndex = 0
    private let retrySequence: [TimeInterval] = [1, 2, 4, 8, 16]
    private let steadyStateInterval: TimeInterval = 2

    public init(
        settingsStore: SettingsStore,
        session: URLSession = .shared
    ) {
        self.settingsStore = settingsStore
        self.session = session
    }

    deinit {
        task?.cancel()
    }

    public func start() {
        guard !isStreaming else { return }
        isStreaming = true
        task = Task { [weak self] in
            await self?.streamLoop()
        }
    }

    public func stop() {
        isStreaming = false
        task?.cancel()
        task = nil
    }

    private func streamLoop() async {
        while !Task.isCancelled && isStreaming {
            do {
                try await fetchFrame()
                statusMessage = nil
                retryIndex = 0
                try? await Task.sleep(for: .seconds(steadyStateInterval))
            } catch {
                statusMessage = error.localizedDescription
                let delay = retrySequence[min(retryIndex, retrySequence.count - 1)]
                retryIndex = min(retryIndex + 1, retrySequence.count - 1)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func fetchFrame() async throws {
        guard let apiBase = settingsStore.state.apiBaseURL else {
            throw LiveStreamError.missingBaseURL
        }
        let url = apiBase.appendingPathComponent("camera/stream")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw LiveStreamError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(
                name: "t",
                value: String(Int(Date().timeIntervalSince1970))
            )
        ]
        guard let finalURL = components.url else {
            throw LiveStreamError.invalidURL
        }
        var request = URLRequest(url: finalURL)
        request.timeoutInterval = 6

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LiveStreamError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LiveStreamError.httpStatus(http.statusCode)
        }

        guard let image = UIImage(data: data) else {
            throw LiveStreamError.decodeFailed
        }
        latestFrame = image
    }
}

enum LiveStreamError: LocalizedError {
    case missingBaseURL
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Set the Base URL in Settings to enable live streaming."
        case .invalidURL:
            return "Live stream URL is invalid."
        case .invalidResponse:
            return "Camera stream returned an unexpected response."
        case .httpStatus(let code):
            return "Camera stream offline (HTTP \(code))."
        case .decodeFailed:
            return "Stream data could not be decoded."
        }
    }
}
