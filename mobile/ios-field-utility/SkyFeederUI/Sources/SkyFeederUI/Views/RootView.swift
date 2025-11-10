import SwiftUI

public struct SkyFeederRootView: View {
    @StateObject private var router: ApplicationRouter
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var galleryViewModel: GalleryViewModel
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var liveStreamViewModel: LiveStreamViewModel
    @StateObject private var photosViewModel: MediaCarouselViewModel
    @StateObject private var videosViewModel: MediaCarouselViewModel
    @StateObject private var eventLogViewModel: EventLogViewModel

    public init(settingsStore: SettingsStore) {
        let router = ApplicationRouter()
        _router = StateObject(wrappedValue: router)
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _galleryViewModel = StateObject(wrappedValue: GalleryViewModel(settingsStore: settingsStore))
        _dashboardViewModel = StateObject(
            wrappedValue: DashboardViewModel(settingsStore: settingsStore)
        )
        _liveStreamViewModel = StateObject(
            wrappedValue: LiveStreamViewModel(settingsStore: settingsStore)
        )
        _photosViewModel = StateObject(
            wrappedValue: MediaCarouselViewModel(settingsStore: settingsStore, kind: .photos)
        )
        _videosViewModel = StateObject(
            wrappedValue: MediaCarouselViewModel(settingsStore: settingsStore, kind: .videos)
        )
        _eventLogViewModel = StateObject(
            wrappedValue: EventLogViewModel(settingsStore: settingsStore)
        )
    }

    public var body: some View {
        TabView {
            NavigationStack(path: $router.path) {
                DashboardView(
                    viewModel: dashboardViewModel,
                    liveStreamViewModel: liveStreamViewModel,
                    photosViewModel: photosViewModel,
                    videosViewModel: videosViewModel,
                    eventLogViewModel: eventLogViewModel
                )
                .navigationDestination(for: ApplicationRouter.Destination.self) { destination in
                    switch destination {
                    case .deviceSettings:
                        DeviceSettingsView(
                            viewModel: DeviceSettingsViewModel(settingsStore: settingsStore)
                        )
                    case .storageManagement:
                        StorageManagementView(
                            viewModel: StorageManagementViewModel(settingsStore: settingsStore)
                        )
                    case .settings:
                        SettingsView(viewModel: SettingsViewModel(store: settingsStore)) { _ in
                            Task { await dashboardViewModel.refresh() }
                        }
                    case .detail:
                        EmptyView()
                    }
                }
            }
            .tabItem {
                Label("Dashboard", systemImage: "rectangle.grid.2x2")
            }

            NavigationStack(path: $router.path) {
                GalleryView(viewModel: galleryViewModel)
                    .navigationDestination(for: ApplicationRouter.Destination.self) { destination in
                        switch destination {
                        case .detail(let capture):
                            DetailView(
                                viewModel: galleryViewModel.detailViewModel(for: capture),
                                pipeline: galleryViewModel.pipeline(for: capture)
                            )
                        case .settings:
                            SettingsView(viewModel: SettingsViewModel(store: settingsStore)) { _ in
                                Task { await galleryViewModel.refresh() }
                            }
                        case .deviceSettings, .storageManagement:
                            EmptyView()
                        }
                    }
            }
            .tabItem {
                Label("Gallery", systemImage: "photo.on.rectangle")
            }
        }
        .environmentObject(router)
    }
}

