import Foundation

public enum FeederMediaType: String, Codable {
    case photo
    case video
}

public struct FeederMediaItem: Identifiable, Codable, Hashable {
    public let id: String
    public let type: FeederMediaType
    public let thumbnailURL: URL
    public let mediaURL: URL
    public let weightGrams: Double
    public let capturedAt: Date
    public let expiresAt: Date

    public init(
        id: String,
        type: FeederMediaType,
        thumbnailURL: URL,
        mediaURL: URL,
        weightGrams: Double,
        capturedAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.type = type
        self.thumbnailURL = thumbnailURL
        self.mediaURL = mediaURL
        self.weightGrams = weightGrams
        self.capturedAt = capturedAt
        self.expiresAt = expiresAt
    }
}
