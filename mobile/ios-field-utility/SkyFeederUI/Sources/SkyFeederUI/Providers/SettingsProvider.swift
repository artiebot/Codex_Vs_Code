import Foundation

public enum SettingsProviderError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Settings response was invalid."
        case .httpStatus(let code):
            return "Settings request failed (HTTP \(code))."
        }
    }
}

public struct DeviceSettings: Codable, Equatable {
    public let weightThreshold: Int
    public let cooldownSeconds: Int
    public let cameraEnabled: Bool
    public let updatedAt: Date?

    public static let defaults = DeviceSettings(
        weightThreshold: 50,
        cooldownSeconds: 300,
        cameraEnabled: true,
        updatedAt: nil
    )
}

public final class SettingsProvider {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        self.encoder = JSONEncoder()
    }

    public func fetchSettings(baseURL: URL, deviceId: String) async throws -> DeviceSettings {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("api/settings"),
            resolvingAgainstBaseURL: false
        ) else {
            throw SettingsProviderError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "deviceId", value: deviceId)]
        guard let url = components.url else {
            throw SettingsProviderError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw SettingsProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SettingsProviderError.httpStatus(http.statusCode)
        }

        struct Payload: Decodable {
            let deviceId: String
            let settings: DeviceSettings
        }

        let payload = try decoder.decode(Payload.self, from: data)
        return payload.settings
    }

    public func updateSettings(
        baseURL: URL,
        deviceId: String,
        settings: DeviceSettings
    ) async throws -> DeviceSettings {
        let url = baseURL.appendingPathComponent("api/settings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Payload: Encodable {
            let deviceId: String
            let settings: Settings

            struct Settings: Encodable {
                let weightThreshold: Int
                let cooldownSeconds: Int
                let cameraEnabled: Bool
            }
        }

        let payload = Payload(
            deviceId: deviceId,
            settings: Payload.Settings(
                weightThreshold: settings.weightThreshold,
                cooldownSeconds: settings.cooldownSeconds,
                cameraEnabled: settings.cameraEnabled
            )
        )
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SettingsProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SettingsProviderError.httpStatus(http.statusCode)
        }

        struct Response: Decodable {
            let success: Bool
            let deviceId: String
            let settings: DeviceSettings
        }

        let responsePayload = try decoder.decode(Response.self, from: data)
        return responsePayload.settings
    }
}
