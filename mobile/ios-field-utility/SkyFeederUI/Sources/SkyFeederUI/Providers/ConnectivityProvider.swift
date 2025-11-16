import Foundation

public enum ConnectivityProviderError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Connectivity response was invalid."
        case .httpStatus(let code):
            return "Connectivity request failed (HTTP \(code))."
        }
    }
}

public final class ConnectivityProvider {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func fetchConnectivity(baseURL: URL, deviceId: String) async throws -> ConnectivityDiagnostics {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("api/connectivity"),
            resolvingAgainstBaseURL: false
        ) else {
            throw ConnectivityProviderError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "deviceId", value: deviceId)]
        guard let url = components.url else {
            throw ConnectivityProviderError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw ConnectivityProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ConnectivityProviderError.httpStatus(http.statusCode)
        }

        struct Payload: Decodable {
            let status: String
            let recentFailures: Int
            let averageRoundtripMs: Int?
            let lastSync: Date?
        }

        let payload = try decoder.decode(Payload.self, from: data)
        let statusText: String
        switch payload.status.lowercased() {
        case "healthy":
            statusText = "Healthy"
        case "degraded":
            statusText = "Degraded"
        case "down":
            statusText = "Down"
        default:
            statusText = payload.status
        }

        return ConnectivityDiagnostics(
            statusText: statusText,
            recentFailures: payload.recentFailures,
            averageRoundtripMs: payload.averageRoundtripMs,
            lastSync: payload.lastSync
        )
    }
}

