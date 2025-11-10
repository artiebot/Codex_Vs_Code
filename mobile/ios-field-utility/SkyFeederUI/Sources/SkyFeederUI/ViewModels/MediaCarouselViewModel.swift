import Foundation

@MainActor
public final class MediaCarouselViewModel: ObservableObject {
    public enum Kind {
        case photos
        case videos
    }

    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var items: [MediaItem] = []

    private let settingsStore: SettingsStore
    private let provider: MediaProvider
    private let kind: Kind

    public init(
        settingsStore: SettingsStore,
        kind: Kind,
        provider: MediaProvider = MediaProvider()
    ) {
        self.settingsStore = settingsStore
        self.kind = kind
        self.provider = provider
    }

    public func refresh() async {
        guard let baseURL = settingsStore.state.apiBaseURL else {
            errorMessage = MediaProviderError.missingAPIBase.errorDescription
            return
        }
        isLoading = true
        do {
            switch kind {
            case .photos:
                items = try await provider.fetchPhotos(baseURL: baseURL, deviceId: settingsStore.state.deviceID)
            case .videos:
                items = try await provider.fetchVideos(baseURL: baseURL, deviceId: settingsStore.state.deviceID)
            }
            errorMessage = nil
        } catch {
            if let mediaError = error as? LocalizedError {
                errorMessage = mediaError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}
