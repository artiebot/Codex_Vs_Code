import Foundation

public enum MediaProviderError: LocalizedError {
    case missingAPIBase
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .missingAPIBase:
            return "Missing API base URL."
        case .invalidResponse:
            return "Unexpected media response."
        case .httpStatus(let code):
            return "Media request failed (HTTP \(code))."
        }
    }
}

public final class MediaProvider {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func fetchPhotos(baseURL: URL, deviceId: String, limit: Int = 20) async throws -> [MediaItem] {
        try await fetchMedia(
            baseURL: baseURL,
            path: "api/photos",
            key: "photos",
            deviceId: deviceId,
            limit: limit
        )
    }

    public func fetchVideos(baseURL: URL, deviceId: String, limit: Int = 20) async throws -> [MediaItem] {
        try await fetchMedia(
            baseURL: baseURL,
            path: "api/videos",
            key: "videos",
            deviceId: deviceId,
            limit: limit
        )
    }

    private func fetchMedia(
        baseURL: URL,
        path: String,
        key: String,
        deviceId: String,
        limit: Int
    ) async throws -> [MediaItem] {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw MediaProviderError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "deviceId", value: deviceId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        guard let url = components.url else {
            throw MediaProviderError.invalidResponse
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw MediaProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MediaProviderError.httpStatus(http.statusCode)
        }

        struct MediaResponse: Decodable {
            let photos: [MediaItem]?
            let videos: [MediaItem]?
        }

        let payload = try decoder.decode(MediaResponse.self, from: data)
        switch key {
        case "photos":
            return payload.photos ?? []
        case "videos":
            return payload.videos ?? []
        default:
            return []
        }
    }
}
