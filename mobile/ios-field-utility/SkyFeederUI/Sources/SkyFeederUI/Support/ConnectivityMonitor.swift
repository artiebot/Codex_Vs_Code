import Foundation
import Network

@MainActor
public final class ConnectivityMonitor: ObservableObject {
    public static let shared = ConnectivityMonitor()

    @Published public private(set) var isOffline: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.skyfeeder.connectivity")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOffline = !(path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
}
