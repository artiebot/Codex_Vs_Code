import Foundation

public final class PresignedCaptureProvider: CaptureProvider {
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
    }

    private let endpoint: URL
    private let urlSession: URLSession
    private let cacheManager: CacheManager
    private let cacheTTL: TimeInterval

    public init(endpoint: URL, urlSession: URLSession = .shared, cacheManager: CacheManager = .shared, cacheTTL: TimeInterval) {
        self.endpoint = endpoint
        self.urlSession = urlSession
        self.cacheManager = cacheManager
        self.cacheTTL = cacheTTL
    }

    public func loadCaptures() async throws -> [Capture] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw CaptureProviderError.networkFailure("Unexpected response from manifest endpoint")
        }
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
                source: .presigned
            )
        }
    }

    public func thumbnailData(for capture: Capture) async throws -> Data {
        switch capture.thumbnail.location {
        case .file(let url):
            return try Data(contentsOf: url)
        case .remote(let url):
            if let cached = cacheManager.data(forKey: capture.thumbnail.cacheKey, ttl: cacheTTL, category: .thumbnails) {
                return cached
            }
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw CaptureProviderError.networkFailure("Thumbnail download failed")
            }
            _ = try cacheManager.store(data: data, forKey: capture.thumbnail.cacheKey, category: .thumbnails)
            return data
        }
    }

    public func assetURL(for capture: Capture) async throws -> URL {
        switch capture.asset.location {
        case .file(let url):
            return url
        case .remote(let url):
            if let cachedData = cacheManager.data(forKey: capture.asset.cacheKey, ttl: cacheTTL, category: .assets) {
                let fileURL = cacheManager.url(forKey: capture.asset.cacheKey, category: .assets)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    _ = try cacheManager.store(data: cachedData, forKey: capture.asset.cacheKey, category: .assets)
                }
                return fileURL
            }
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw CaptureProviderError.networkFailure("Asset download failed")
            }
            let fileURL = try cacheManager.store(data: data, forKey: capture.asset.cacheKey, category: .assets)
            return fileURL
        }
    }
}
