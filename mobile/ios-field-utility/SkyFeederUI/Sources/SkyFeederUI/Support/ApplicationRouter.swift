import Combine
import Foundation

public final class ApplicationRouter: ObservableObject {
    public enum Destination: Hashable {
        case detail(Capture)
        case settings
        case deviceSettings
        case storageManagement
    }

    @Published public var path: [Destination] = []

    public init() {}

    public func showDetail(for capture: Capture) {
        path.append(.detail(capture))
    }

    public func showSettings() {
        path.append(.settings)
    }

    public func showDeviceSettings() {
        path.append(.deviceSettings)
    }

    public func showStorageManagement() {
        path.append(.storageManagement)
    }

    public func popToRoot() {
        path.removeAll()
    }
}
