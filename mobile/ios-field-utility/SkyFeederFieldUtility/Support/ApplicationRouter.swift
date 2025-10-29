import Combine
import Foundation

final class ApplicationRouter: ObservableObject {
    enum Destination {
        case gallery
        case placeholder
    }

    @Published var destination: Destination = .gallery
}
