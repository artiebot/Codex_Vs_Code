import Combine
import Foundation
import SwiftUI

@MainActor
public final class GalleryViewModel: ObservableObject {
    @Published public private(set) var sections: [GallerySection] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lastUpdated: Date?
    @Published public private(set) var isOffline: Bool = false

    public private(set) var captures: [Capture] = []
    public private(set) var settings: SettingsState

    private let connectivityMonitor: ConnectivityMonitor
    private let cacheManager: CacheManager
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var provider: CaptureProvider

    public init(
        settingsStore: SettingsStore,
        connectivityMonitor: ConnectivityMonitor = .shared,
        cacheManager: CacheManager = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.settings = settingsStore.state
        self.connectivityMonitor = connectivityMonitor
        self.cacheManager = cacheManager
        self.userDefaults = userDefaults

        do {
            provider = try GalleryViewModel.resolveProvider(for: settingsStore.state)
        } catch {
            provider = EmptyCaptureProvider()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        settingsStore.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.apply(settings: newState)
            }
            .store(in: &cancellables)

        connectivityMonitor.$isOffline
            .receive(on: DispatchQueue.main)
            .sink { [weak self] offline in
                guard let self else { return }
                self.isOffline = offline && self.settings.provider.requiresConnectivity
            }
            .store(in: &cancellables)
    }

    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            cacheManager.clearExpired(ttl: settings.cacheTTL, category: .thumbnails)
            cacheManager.clearExpired(ttl: settings.cacheTTL, category: .assets)
            let loaded = try await provider.loadCaptures()
            captures = loaded
            sections = loaded.groupedByDay()
            lastUpdated = Date()
            BadgeManager.updateBadge(with: loaded, userDefaults: userDefaults)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    public func markGalleryOpened() {
        BadgeManager.markOpened(userDefaults: userDefaults)
    }

    public func pipeline(for capture: Capture) -> ImagePipeline {
        ImagePipeline(capture: capture, provider: provider, cacheTTL: settings.cacheTTL)
    }

    public func detailViewModel(for capture: Capture) -> DetailViewModel {
        DetailViewModel(
            capture: capture,
            provider: provider,
            settingsProvider: { [weak self] in
                self?.settings ?? SettingsState()
            }
        )
    }

    public func assetURL(for capture: Capture) async throws -> URL {
        try await provider.assetURL(for: capture)
    }

    public func currentSettings() -> SettingsState {
        settings
    }

    private func apply(settings newSettings: SettingsState) {
        settings = newSettings
        do {
            provider = try Self.resolveProvider(for: newSettings)
            errorMessage = nil
        } catch {
            provider = EmptyCaptureProvider()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isOffline = connectivityMonitor.isOffline && newSettings.provider.requiresConnectivity
    }

    private static func resolveProvider(for settings: SettingsState) throws -> CaptureProvider {
        switch settings.provider {
        case .filesystem:
            let path = settings.filesystemRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                throw CaptureProviderError.invalidConfiguration("Filesystem root is not configured.")
            }
            return FilesystemCaptureProvider(root: URL(fileURLWithPath: path, isDirectory: true))
        case .presigned:
            guard let endpoint = settings.manifestURL else {
                throw CaptureProviderError.invalidConfiguration("Manifest URL is not set.")
            }
            return PresignedCaptureProvider(endpoint: endpoint, cacheTTL: settings.cacheTTL)
        }
    }
}

private final class EmptyCaptureProvider: CaptureProvider {
    func loadCaptures() async throws -> [Capture] { [] }
    func thumbnailData(for capture: Capture) async throws -> Data { throw CaptureProviderError.assetUnavailable }
    func assetURL(for capture: Capture) async throws -> URL { throw CaptureProviderError.assetUnavailable }
}
