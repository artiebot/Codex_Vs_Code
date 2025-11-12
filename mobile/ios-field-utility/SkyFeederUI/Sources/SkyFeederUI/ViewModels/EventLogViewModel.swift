import Foundation

@MainActor
public final class EventLogViewModel: ObservableObject {
    @Published public private(set) var events: [EventLogEntry] = []
    @Published public private(set) var isConnected = false

    private let settingsStore: SettingsStore
    private let client: EventLogWebSocketClient
    private var queuedPayloads: [EventPayload] = []

    public init(
        settingsStore: SettingsStore,
        client: EventLogWebSocketClient = EventLogWebSocketClient()
    ) {
        self.settingsStore = settingsStore
        self.client = client
        client.delegate = self
    }

    public func start() {
        guard let baseURL = settingsStore.state.apiBaseURL else {
            return
        }
        client.connect(baseURL: baseURL, deviceId: settingsStore.state.deviceID)
    }

    public func stop() {
        client.disconnect()
    }

    private func append(_ entry: EventLogEntry) {
        events.append(entry)
        if events.count > 50 {
            events.removeFirst(events.count - 50)
        }
    }

    public func appendLocal(message: String, icon: String) {
        let entry =
            EventLogEntry(
                timestamp: Date(),
                message: message,
                iconName: icon,
                source: .local
            )
        append(entry)
    }
}

extension EventLogViewModel: EventLogWebSocketClientDelegate {
    public nonisolated func eventLogClient(_ client: EventLogWebSocketClient, didReceive payload: EventPayload) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.isConnected {
                self.append(EventLogEntry.fromWebSocket(payload))
            } else {
                self.queue(payload)
            }
        }
    }

    public nonisolated func eventLogClient(_ client: EventLogWebSocketClient, didChangeState isConnected: Bool) {
        Task { @MainActor in
            self.isConnected = isConnected
            if isConnected {
                self.flushQueue()
            }
        }
    }

    private func queue(_ payload: EventPayload) {
        queuedPayloads.append(payload)
        if queuedPayloads.count > 100 {
            queuedPayloads.removeFirst(queuedPayloads.count - 100)
        }
    }

    private func flushQueue() {
        guard !queuedPayloads.isEmpty else { return }
        queuedPayloads.forEach { append(EventLogEntry.fromWebSocket($0)) }
        queuedPayloads.removeAll()
    }
}
