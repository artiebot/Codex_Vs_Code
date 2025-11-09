import Combine
import Foundation
import SwiftUI

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published private(set) var sections: [GallerySection] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isOffline: Bool = false

    private(set) var captures: [Capture] = []

    private let connectivityMonitor: ConnectivityMonitor
    private var cancellables = Set<AnyCancellable>()
    private var provider: CaptureProvider
    private var settings: GallerySettings

    init(
        settings: GallerySettings = GallerySettings(),
        connectivityMonitor: ConnectivityMonitor = .shared
    ) {
        self.settings = settings
        self.connectivityMonitor = connectivityMonitor
        do {
            provider = try GalleryViewModel.resolveProvider(for: settings)
        } catch {
            provider = EmptyCaptureProvider()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        connectivityMonitor.$isOffline
            .receive(on: DispatchQueue.main)
            .sink { [weak self] offline in
                guard let self else { return }
                self.isOffline = offline && self.settings.provider.requiresConnectivity
            }
            .store(in: &cancellables)
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            DiskCache.shared.clearExpired(ttl: settings.cacheTTL, category: .thumbnails)
            DiskCache.shared.clearExpired(ttl: settings.cacheTTL, category: .assets)
            captures = try await provider.loadCaptures()
            sections = captures.groupedByDay()
            lastUpdated = Date()
            BadgeUpdater.updateBadge(with: captures)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    func reloadWith(settings: GallerySettings) {
        self.settings = settings
        errorMessage = nil
        do {
            provider = try Self.resolveProvider(for: settings)
        } catch {
            provider = EmptyCaptureProvider()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isOffline = connectivityMonitor.isOffline && settings.provider.requiresConnectivity
    }

    func pipeline(for capture: Capture) -> ImagePipeline {
        ImagePipeline(capture: capture, provider: provider, cacheTTL: settings.cacheTTL)
    }

    func assetURL(for capture: Capture) async throws -> URL {
        try await provider.assetURL(for: capture)
    }

    func currentSettings() -> GallerySettings {
        settings
    }

    private static func resolveProvider(for settings: GallerySettings) throws -> CaptureProvider {
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
            return PresignedCaptureProvider(
                endpoint: endpoint,
                fallbackEndpoint: settings.legacyManifestURL,
                cacheTTL: settings.cacheTTL
            )
        }
    }
}

private final class EmptyCaptureProvider: CaptureProvider {
    func loadCaptures() async throws -> [Capture] { [] }
    func thumbnailData(for capture: Capture) async throws -> Data { throw CaptureProviderError.assetUnavailable }
    func assetURL(for capture: Capture) async throws -> URL { throw CaptureProviderError.assetUnavailable }
}
