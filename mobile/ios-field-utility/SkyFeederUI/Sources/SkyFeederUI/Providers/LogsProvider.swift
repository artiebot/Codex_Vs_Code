import Foundation

public enum LogsProviderError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Logs response was invalid."
        case .httpStatus(let code):
            return "Logs request failed (HTTP \(code))."
        }
    }
}

public final class LogsProvider {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchLogs(
        baseURL: URL,
        services: [String] = ["presign-api", "ws-relay", "minio"],
        lines: Int = 300
    ) async throws -> String {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("api/logs"),
            resolvingAgainstBaseURL: false
        ) else {
            throw LogsProviderError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "services", value: services.joined(separator: ",")),
            URLQueryItem(name: "lines", value: "\(lines)")
        ]
        guard let url = components.url else {
            throw LogsProviderError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw LogsProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LogsProviderError.httpStatus(http.statusCode)
        }

        guard let logsText = String(data: data, encoding: .utf8) else {
            throw LogsProviderError.invalidResponse
        }

        return logsText
    }
}
