import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: GallerySettings

    init(settings: GallerySettings = GallerySettings()) {
        self.settings = settings
    }

    func save() {
        settings.persist()
    }
}
