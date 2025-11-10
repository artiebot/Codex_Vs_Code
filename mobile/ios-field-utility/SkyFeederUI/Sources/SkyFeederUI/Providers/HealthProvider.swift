import Foundation

public struct HealthSnapshot: Decodable, Equatable {
    public struct ServiceStatus: Decodable, Equatable {
        public let status: String
        public let latencyMs: Double?
    }

    public struct WeightMetrics: Decodable, Equatable {
        public let currentGrams: Double?
        public let rollingAverageGrams: Double?
        public let visitsToday: Int?
        public let lastEventTs: Date?
        public let sourceDay: String?

        enum CodingKeys: String, CodingKey {
            case currentGrams
            case rollingAverageGrams
            case visitsToday
            case lastEventTs
            case sourceDay
        }
    }

    public struct VisitMetrics: Decodable, Equatable {
        public let today: Int?
        public let totalEvents: Int?
        public let lastEventTs: Date?
    }

    public struct StorageStats: Decodable, Equatable {
        public let count: Int
        public let totalBytes: Int
    }

    public struct DiskStats: Decodable, Equatable {
        public let freeBytes: Int?
    }

    public struct LogStats: Decodable, Equatable {
        public let sizeBytes: Int
    }

    public struct Storage: Decodable, Equatable {
        public let photos: StorageStats
        public let videos: StorageStats
        public let logs: LogStats
        public let disk: DiskStats
        public let freeSpaceBytes: Int?
    }

    public let deviceId: String
    public let timestamp: Date
    public let uptimeSeconds: Int?
    public let latencyMs: Double?
    public let services: [String: ServiceStatus]
    public let storage: Storage?
    public let weightMetrics: WeightMetrics
    public let visitMetrics: VisitMetrics
}

public enum HealthProviderError: LocalizedError {
    case missingAPIBase
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .missingAPIBase:
            return "Missing API base URL. Update the gallery Base URL in Settings."
        case .invalidResponse:
            return "The health endpoint returned an unexpected payload."
        case .httpStatus(let code):
            return "Health endpoint returned HTTP \(code)."
        }
    }
}

public final class HealthProvider {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func fetchSnapshot(baseURL: URL, deviceId: String) async throws -> HealthSnapshot {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("api/health"), resolvingAgainstBaseURL: false) else {
            throw HealthProviderError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "deviceId", value: deviceId)
        ]
        guard let url = components.url else {
            throw HealthProviderError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw HealthProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HealthProviderError.httpStatus(http.statusCode)
        }

        struct Payload: Decodable {
            let deviceId: String
            let timestamp: Date
            let uptimeSeconds: Int?
            let latencyMs: Double?
            let services: [String: HealthSnapshot.ServiceStatus]
            let storage: HealthSnapshot.Storage?
            let metrics: Metrics

            struct Metrics: Decodable {
                let weight: HealthSnapshot.WeightMetrics
                let visits: HealthSnapshot.VisitMetrics
            }
        }

        let payload = try decoder.decode(Payload.self, from: data)
        return HealthSnapshot(
            deviceId: payload.deviceId,
            timestamp: payload.timestamp,
            uptimeSeconds: payload.uptimeSeconds,
            latencyMs: payload.latencyMs,
            services: payload.services,
            storage: payload.storage,
            weightMetrics: payload.metrics.weight,
            visitMetrics: payload.metrics.visits
        )
    }
}
