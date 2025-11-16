import Foundation

public enum LogsSummaryProviderError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Logs summary response was invalid."
        case .httpStatus(let code):
            return "Logs summary request failed (HTTP \(code))."
        }
    }
}

public final class LogsSummaryProvider {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func fetchSummary(
        baseURL: URL,
        deviceId: String,
        limit: Int = 50
    ) async throws -> [LogEntry] {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("api/logs/summary"),
            resolvingAgainstBaseURL: false
        ) else {
            throw LogsSummaryProviderError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "deviceId", value: deviceId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        guard let url = components.url else {
            throw LogsSummaryProviderError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw LogsSummaryProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LogsSummaryProviderError.httpStatus(http.statusCode)
        }

        struct Record: Decodable {
            let timestamp: Date
            let message: String
        }

        let records = try decoder.decode([Record].self, from: data)
        return records.map { LogEntry(timestamp: $0.timestamp, message: $0.message) }
    }
}

