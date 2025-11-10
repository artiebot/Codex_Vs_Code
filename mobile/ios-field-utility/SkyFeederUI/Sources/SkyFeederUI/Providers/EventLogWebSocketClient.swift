import Foundation

public protocol EventLogWebSocketClientDelegate: AnyObject {
    func eventLogClient(_ client: EventLogWebSocketClient, didReceive payload: EventPayload)
    func eventLogClient(_ client: EventLogWebSocketClient, didChangeState isConnected: Bool)
}

public final class EventLogWebSocketClient: NSObject {
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var isCancelled = false
    private var reconnectIndex = 0
    private let reconnectDelays: [TimeInterval] = [1, 2, 4, 8, 16]
    private var lastBaseURL: URL?
    private var lastDeviceId: String?

    public weak var delegate: EventLogWebSocketClientDelegate?

    public override init() {
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration)
        super.init()
    }

    public func connect(baseURL: URL, deviceId: String) {
        lastBaseURL = baseURL
        lastDeviceId = deviceId
        reconnectIndex = 0
        startConnection()
    }

    public func disconnect() {
        isCancelled = true
        reconnectTask?.cancel()
        reconnectTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        delegate?.eventLogClient(self, didChangeState: false)
    }

    private func startConnection() {
        guard !isCancelled,
              let baseURL = lastBaseURL,
              let deviceId = lastDeviceId,
              let url = makeWebSocketURL(baseURL: baseURL, deviceId: deviceId) else {
            return
        }
        task?.cancel(with: .goingAway, reason: nil)
        isCancelled = false
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        delegate?.eventLogClient(self, didChangeState: true)
        listen()
    }

    private func listen() {
        guard !isCancelled, let task else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.reconnectIndex = 0
                if case let .string(text) = message,
                   let data = text.data(using: .utf8),
                   let payload = try? JSONDecoder().decode(EventPayload.self, from: data) {
                    Task { @MainActor in
                        self.delegate?.eventLogClient(self, didReceive: payload)
                    }
                }
                self.listen()
            case .failure:
                Task { @MainActor in
                    self.delegate?.eventLogClient(self, didChangeState: false)
                }
                self.scheduleReconnect()
            }
        }
    }

    private func scheduleReconnect() {
        guard !isCancelled else { return }
        reconnectTask?.cancel()
        let delay = reconnectDelays[min(reconnectIndex, reconnectDelays.count - 1)]
        reconnectIndex = min(reconnectIndex + 1, reconnectDelays.count - 1)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.startConnection()
        }
    }

    private func makeWebSocketURL(baseURL: URL, deviceId: String) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        if let port = components.port, port == 8080 {
            components.port = 8081
        } else if components.port == nil {
            components.port = components.scheme == "wss" ? 443 : 8081
        }
        components.path = "/"
        components.queryItems = [URLQueryItem(name: "deviceId", value: deviceId)]
        return components.url
    }
}
