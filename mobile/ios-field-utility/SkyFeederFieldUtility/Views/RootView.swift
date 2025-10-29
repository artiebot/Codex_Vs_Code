import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: ApplicationRouter
    @StateObject private var galleryViewModel = GalleryViewModel(provider: SampleCaptureProvider(), settings: GallerySettings(userDefaults: .standard))

    var body: some View {
        NavigationStack(path: $router.path) {
            GalleryView(viewModel: galleryViewModel)
                .navigationDestination(for: ApplicationRouter.Destination.self) { destination in
                    switch destination {
                    case .detail(let capture):
                        CaptureDetailView(capture: capture, viewModel: galleryViewModel)
                    case .settings:
                        SettingsView(viewModel: SettingsViewModel(settings: GallerySettings(userDefaults: .standard))) { newSettings in
                            galleryViewModel.reloadWith(settings: newSettings)
                            Task { await galleryViewModel.refresh() }
                        }
                    }
                }
        }
    }
}
