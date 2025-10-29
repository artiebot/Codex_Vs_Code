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
        provider: CaptureProvider,
        connectivityMonitor: ConnectivityMonitor = .shared,
        settings: GallerySettings = GallerySettings()
    ) {
        self.provider = provider
        self.connectivityMonitor = connectivityMonitor
        self.settings = settings

        connectivityMonitor.$isOffline
            .receive(on: DispatchQueue.main)
            .sink { [weak self] offline in
                self?.isOffline = offline
            }
            .store(in: &cancellables)
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            DiskCache.shared.clearExpired(ttl: settings.cacheTTL)
            captures = try await provider.loadCaptures()
            sections = captures.groupedByDay()
            lastUpdated = Date()
            BadgeUpdater.updateBadgeIfNeeded(captures: captures, enableBadge: settings.enableFavoritesBadge)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    func reloadWith(settings: GallerySettings) {
        self.settings = settings
        errorMessage = nil
        switch settings.provider {
        case .sample:
            provider = SampleCaptureProvider()
        case .filesystem:
            let path = settings.filesystemRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                errorMessage = "Filesystem root is not configured."
                return
            }
            provider = FilesystemCaptureProvider(root: URL(fileURLWithPath: path, isDirectory: true))
        case .presigned:
            guard let endpoint = settings.presignedEndpoint else {
                errorMessage = "Presigned endpoint is not set."
                return
            }
            provider = PresignedCaptureProvider(endpoint: endpoint, cacheTTL: settings.cacheTTL)
        }
    }

    func pipeline(for capture: Capture) -> ImagePipeline {
        ImagePipeline(capture: capture, provider: provider, cacheTTL: settings.cacheTTL)
    }

    func markSeen(_ capture: Capture) {
        BadgeUpdater.markAsSeen(capture)
        BadgeUpdater.updateBadgeIfNeeded(captures: captures, enableBadge: settings.enableFavoritesBadge)
    }

    func assetURL(for capture: Capture) async throws -> URL {
        try await provider.assetURL(for: capture)
    }
}
