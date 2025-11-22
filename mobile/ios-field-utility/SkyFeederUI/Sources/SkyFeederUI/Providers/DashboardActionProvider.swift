import Foundation

public enum DashboardAction: String {
    case manualTrigger = "api/trigger/manual"
    case snapshot = "api/snapshot"
    case reboot = "api/reboot"
    case cleanupPhotos = "api/cleanup/photos"
    case cleanupVideos = "api/cleanup/videos"
}

public enum DashboardActionError: LocalizedError {
    case missingAPIBase
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .missingAPIBase:
            return "Missing API base URL."
        case .invalidResponse:
            return "Unexpected dashboard action response."
        case .httpStatus(let code):
            return "Dashboard action failed (HTTP \(code))."
        }
    }
}

public struct DashboardActionResult: Decodable {
    public let success: Bool
    public let message: String?
}

public final class DashboardActionProvider {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func perform(
        action: DashboardAction,
        baseURL: URL,
        deviceId: String
    ) async throws -> DashboardActionResult {
        let url = baseURL.appendingPathComponent(action.rawValue)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Payload: Encodable { let deviceId: String }
        request.httpBody = try JSONEncoder().encode(Payload(deviceId: deviceId))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DashboardActionError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw DashboardActionError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(DashboardActionResult.self, from: data)
    }
}
