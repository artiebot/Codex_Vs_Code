import Foundation

/// Represents a single bird visit event.
public struct BirdVisit: Identifiable, Codable {
    public let id: String
    public let speciesName: String?
    public let timestamp: Date
    public let weightGrams: Double?
    public let confidence: Double? // 0.0 to 1.0
    public let thumbnailUrl: URL?
    public let videoUrl: URL?
    public let isVideo: Bool
    
    public init(
        id: String,
        speciesName: String?,
        timestamp: Date,
        weightGrams: Double?,
        confidence: Double?,
        thumbnailUrl: URL?,
        videoUrl: URL?,
        isVideo: Bool
    ) {
        self.id = id
        self.speciesName = speciesName
        self.timestamp = timestamp
        self.weightGrams = weightGrams
        self.confidence = confidence
        self.thumbnailUrl = thumbnailUrl
        self.videoUrl = videoUrl
        self.isVideo = isVideo
    }
    
    // Mock data
    public static let mocks: [BirdVisit] = [
        BirdVisit(
            id: "v1",
            speciesName: "Blue Jay",
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            weightGrams: 79.0,
            confidence: 0.95,
            thumbnailUrl: URL(string: "https://example.com/bluejay.jpg"),
            videoUrl: URL(string: "https://example.com/bluejay.mp4"),
            isVideo: true
        ),
        BirdVisit(
            id: "v2",
            speciesName: "Unidentified bird",
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            weightGrams: 22.0,
            confidence: 0.93,
            thumbnailUrl: URL(string: "https://example.com/sparrow.jpg"),
            videoUrl: nil,
            isVideo: false
        ),
        BirdVisit(
            id: "v3",
            speciesName: "House Finch",
            timestamp: Date().addingTimeInterval(-86400), // Yesterday
            weightGrams: 25.0,
            confidence: 0.88,
            thumbnailUrl: URL(string: "https://example.com/finch.jpg"),
            videoUrl: URL(string: "https://example.com/finch.mp4"),
            isVideo: true
        ),
        BirdVisit(
            id: "v4",
            speciesName: "Cardinal",
            timestamp: Date().addingTimeInterval(-100000),
            weightGrams: 45.0,
            confidence: 0.99,
            thumbnailUrl: URL(string: "https://example.com/cardinal.jpg"),
            videoUrl: URL(string: "https://example.com/cardinal.mp4"),
            isVideo: true
        )
    ]
}
