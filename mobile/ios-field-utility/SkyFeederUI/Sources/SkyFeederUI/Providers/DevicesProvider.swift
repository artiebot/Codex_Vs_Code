import Foundation

public enum DevicesProviderError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Devices response was invalid."
        case .httpStatus(let code):
            return "Devices request failed (HTTP \(code))."
        }
    }
}

public final class DevicesProvider {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func fetchDevices(baseURL: URL) async throws -> [DeviceSummary] {
        let url = baseURL.appendingPathComponent("api/devices")

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw DevicesProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw DevicesProviderError.httpStatus(http.statusCode)
        }

        return try decoder.decode([DeviceSummary].self, from: data)
    }
}

