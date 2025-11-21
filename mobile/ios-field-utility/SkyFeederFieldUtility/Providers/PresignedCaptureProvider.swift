import Foundation
import os.log

final class PresignedCaptureProvider: CaptureProvider {
    private struct ManifestResponse: Codable {
        let captures: [ManifestCapture]
    }

    private struct ManifestCapture: Codable {
        let id: UUID
        let title: String
        let capturedAt: Date
        let duration: TimeInterval?
        let fileSizeBytes: Int
        let thumbnailURL: URL
        let assetURL: URL
        let contentType: String
        let weightGrams: Double?
    }

    private let endpoint: URL
    private let fallbackEndpoint: URL?
    private let urlSession: URLSession
    private let diskCache: DiskCache
    private let cacheTTL: TimeInterval
    private let logger = Logger(subsystem: "com.skyfeeder.field", category: "PresignedCaptureProvider")

    init(endpoint: URL, fallbackEndpoint: URL? = nil, urlSession: URLSession = .shared, diskCache: DiskCache = .shared, cacheTTL: TimeInterval) {
        self.endpoint = endpoint
        self.fallbackEndpoint = fallbackEndpoint
        self.urlSession = urlSession
        self.diskCache = diskCache
        self.cacheTTL = cacheTTL
    }

    func loadCaptures() async throws -> [Capture] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CaptureProviderError.networkFailure("Unexpected response from manifest endpoint")
            }

            if httpResponse.statusCode == 404, let fallbackURL = fallbackEndpoint {
                logger.info("Manifest not found at \(self.endpoint.absoluteString), retrying with legacy endpoint \(fallbackURL.absoluteString)")
                return try await loadCapturesFromURL(fallbackURL)
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw CaptureProviderError.networkFailure("Unexpected response from manifest endpoint (HTTP \(httpResponse.statusCode))")
            }

            logger.info("Successfully loaded manifest from \(self.endpoint.absoluteString)")
            return try parseManifest(from: data)
        } catch {
            if fallbackEndpoint != nil {
                logger.error("Failed to load manifest: \(error.localizedDescription)")
            }
            throw error
        }
    }

    private func loadCapturesFromURL(_ url: URL) async throws -> [Capture] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw CaptureProviderError.networkFailure("Unexpected response from manifest endpoint")
        }

        logger.info("Successfully loaded manifest from legacy endpoint \(url.absoluteString)")
        return try parseManifest(from: data)
    }

    private func parseManifest(from data: Data) throws -> [Capture] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ManifestResponse.self, from: data)
        return manifest.captures.map { item in
            Capture(
                id: item.id,
                title: item.title,
                capturedAt: item.capturedAt,
                duration: item.duration,
                fileSizeBytes: item.fileSizeBytes,
                thumbnail: CaptureResource(location: .remote(item.thumbnailURL), contentType: item.contentType),
                asset: CaptureResource(location: .remote(item.assetURL), contentType: item.contentType),
                source: .presigned,
                weightGrams: item.weightGrams ?? 0
            )
        }
    }

    func thumbnailData(for capture: Capture) async throws -> Data {
        switch capture.thumbnail.location {
        case .file(let url):
            return try Data(contentsOf: url)
        case .remote(let url):
            if let cached = diskCache.data(forKey: capture.thumbnail.cacheKey, ttl: cacheTTL, category: .thumbnails) {
                return cached
            }
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw CaptureProviderError.networkFailure("Thumbnail download failed")
            }
            _ = try diskCache.store(data: data, forKey: capture.thumbnail.cacheKey, category: .thumbnails)
            return data
        }
    }

    func assetURL(for capture: Capture) async throws -> URL {
        switch capture.asset.location {
        case .file(let url):
            return url
        case .remote(let url):
            if let cachedData = diskCache.data(forKey: capture.asset.cacheKey, ttl: cacheTTL, category: .assets) {
                let fileURL = diskCache.url(forKey: capture.asset.cacheKey, category: .assets)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    _ = try diskCache.store(data: cachedData, forKey: capture.asset.cacheKey, category: .assets)
                }
                return fileURL
            }
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw CaptureProviderError.networkFailure("Asset download failed")
            }
            let fileURL = try diskCache.store(data: data, forKey: capture.asset.cacheKey, category: .assets)
            return fileURL
        }
    }
}
