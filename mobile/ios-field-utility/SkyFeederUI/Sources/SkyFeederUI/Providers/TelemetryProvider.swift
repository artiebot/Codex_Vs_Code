import Foundation

public enum TelemetryProviderError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Telemetry response was invalid."
        case .httpStatus(let code):
            return "Telemetry request failed (HTTP \(code))."
        }
    }
}

public struct TelemetryResponse: Decodable {
    public let batteryPercent: Int?
    public let isChargingViaSolar: Bool?
    public let packVoltage: Double
    public let solarWatts: Double
    public let loadWatts: Double
    public let internalTempC: Double
    public let signalStrengthDbm: Int
    public let mode: String
}

public final class TelemetryProvider {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func fetchTelemetry(baseURL: URL, deviceId: String) async throws -> TelemetryResponse {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("api/telemetry"),
            resolvingAgainstBaseURL: false
        ) else {
            throw TelemetryProviderError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "deviceId", value: deviceId)]
        guard let url = components.url else {
            throw TelemetryProviderError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw TelemetryProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw TelemetryProviderError.httpStatus(http.statusCode)
        }

        return try decoder.decode(TelemetryResponse.self, from: data)
    }
}

