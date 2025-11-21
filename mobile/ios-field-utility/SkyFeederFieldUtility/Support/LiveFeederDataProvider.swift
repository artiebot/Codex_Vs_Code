import Foundation
import SkyFeederUI

@MainActor
struct LiveFeederDataProvider: FeederDataProviding {
    private let photoRetentionDays: Int
    private let videoRetentionDays: Int
    private let urlSession: URLSession
    private let telemetryProvider: TelemetryProvider
    private let settingsStore: SettingsStore

    init(
        settingsStore: SettingsStore,
        photoRetentionDays: Int = 7,
        videoRetentionDays: Int = 3,
        urlSession: URLSession = .shared,
        telemetryProvider: TelemetryProvider = TelemetryProvider()
    ) {
        self.settingsStore = settingsStore
        self.photoRetentionDays = photoRetentionDays
        self.videoRetentionDays = videoRetentionDays
        self.urlSession = urlSession
        self.telemetryProvider = telemetryProvider
    }

    func fetchBatteryStatus() async throws -> BatteryStatus {
        guard let base = settingsStore.state.apiBaseURL else {
            throw FeederDataProviderError.missingEndpoint
        }

        let telemetry = try await telemetryProvider.fetchTelemetry(
            baseURL: base,
            deviceId: settingsStore.state.deviceID
        )

        return BatteryStatus(
            percentage: telemetry.batteryPercent,
            isChargingViaSolar: telemetry.isChargingViaSolar,
            isOnline: true
        )
    }

    func fetchRetentionPolicy() async throws -> RetentionPolicy {
        RetentionPolicy(photoRetentionDays: photoRetentionDays, videoRetentionDays: videoRetentionDays)
    }

    func fetchMediaSnapshot() async throws -> FeederMediaSnapshot {
        let gallerySettings = GallerySettings(userDefaults: .standard)
        let galleryViewModel = GalleryViewModel(settings: gallerySettings)
        await galleryViewModel.refresh()

        let captures = galleryViewModel.captures
        let mediaItems = captures.compactMap { capture -> FeederMediaItem? in
            guard
                let thumbnailURL = resourceURL(for: capture.thumbnail),
                let assetURL = resourceURL(for: capture.asset)
            else {
                return nil
            }

            let type = mediaType(for: capture)
            let expiryDays = type == .photo ? photoRetentionDays : videoRetentionDays
            let expiresAt = capture.capturedAt.addingTimeInterval(Double(expiryDays) * 24 * 60 * 60)

            return FeederMediaItem(
                id: capture.title,
                type: type,
                thumbnailURL: thumbnailURL,
                mediaURL: assetURL,
                weightGrams: capture.weightGrams,
                capturedAt: capture.capturedAt,
                expiresAt: expiresAt
            )
        }

        let photos = mediaItems.filter { $0.type == .photo }
        let videos = mediaItems.filter { $0.type == .video }
        return FeederMediaSnapshot(photos: photos, videos: videos)
    }

    func delete(mediaItem: FeederMediaItem) async throws {
        guard let baseURL = SettingsState(userDefaults: .standard).apiBaseURL else {
            throw FeederDataProviderError.missingEndpoint
        }

        let url = baseURL
            .appendingPathComponent("api", isDirectory: false)
            .appendingPathComponent("media", isDirectory: false)
            .appendingPathComponent(mediaItem.id, isDirectory: false)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw FeederDataProviderError.requestFailed("Invalid URL components")
        }
        
        components.queryItems = [
            URLQueryItem(name: "deviceId", value: settingsStore.state.deviceID)
        ]
        
        guard let finalURL = components.url else {
            throw FeederDataProviderError.requestFailed("Failed to construct URL")
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "DELETE"

        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FeederDataProviderError.requestFailed("Missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FeederDataProviderError.requestFailed("HTTP \(http.statusCode)")
        }

        purgeCache(for: mediaItem)
    }

    private func resourceURL(for resource: CaptureResource) -> URL? {
        switch resource.location {
        case .file(let url):
            return url
        case .remote(let url):
            return url
        }
    }

    private func mediaType(for capture: Capture) -> FeederMediaType {
        let contentType = capture.asset.contentType.lowercased()
        if contentType.contains("video") {
            return .video
        } else {
            return .photo
        }
    }

    private func purgeCache(for item: FeederMediaItem) {
        let cache = DiskCache.shared
        let fileManager = FileManager.default
        let thumbURL = cache.url(forKey: item.thumbnailURL.absoluteString, category: .thumbnails)
        let assetURL = cache.url(forKey: item.mediaURL.absoluteString, category: .assets)
        try? fileManager.removeItem(at: thumbURL)
        try? fileManager.removeItem(at: assetURL)
    }
}
