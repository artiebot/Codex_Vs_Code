import Foundation

protocol CaptureProvider {
    func loadCaptures() async throws -> [Capture]
    func thumbnailData(for capture: Capture) async throws -> Data
    func assetURL(for capture: Capture) async throws -> URL
}

enum CaptureProviderError: Error, LocalizedError {
    case missingManifest
    case invalidConfiguration(String)
    case networkFailure(String)
    case assetUnavailable

    var errorDescription: String? {
        switch self {
        case .missingManifest:
            return "Capture manifest is missing or unreadable."
        case .invalidConfiguration(let value):
            return "Invalid configuration: \(value)."
        case .networkFailure(let reason):
            return "Network request failed: \(reason)."
        case .assetUnavailable:
            return "The selected asset is no longer available."
        }
    }
}
