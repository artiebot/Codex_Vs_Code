import Foundation

/// Represents a single bird visit event with its associated media.
public struct BirdVisit: Identifiable, Codable {
    public let id: String
    public let timestamp: Date
    public let weightGrams: Double?
    public let media: [MediaItem] // photos and/or clips that belong to this visit session
    
    public init(
        id: String,
        timestamp: Date,
        weightGrams: Double?,
        media: [MediaItem]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.weightGrams = weightGrams
        self.media = media
    }
}

public extension BirdVisit {
    var primaryMedia: MediaItem? { media.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }.first }
    var thumbnailUrl: URL? { primaryMedia?.url }
    var primaryClip: MediaItem? { media.first(where: { $0.type == .clip }) }
    var videoUrl: URL? { primaryClip?.url }
}
