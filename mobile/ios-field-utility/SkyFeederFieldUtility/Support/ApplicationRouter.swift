import Combine
import Foundation

final class ApplicationRouter: ObservableObject {
    enum Destination: Hashable {
        case detail(Capture)
        case settings
    }

    @Published var path: [Destination] = []

    func showDetail(for capture: Capture) {
        path.append(.detail(capture))
    }

    func showSettings() {
        path.append(.settings)
    }

    func popToRoot() {
        path.removeAll()
    }
}
