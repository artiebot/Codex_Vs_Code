import Foundation

public struct MediaItem: Identifiable, Codable, Equatable {
    public enum MediaType: String, Codable {
        case photo
        case clip
    }

    public var id: String { filename }
    public let filename: String
    public let url: URL
    public let timestamp: Date?
    public let sizeBytes: Int?
    public let type: MediaType

    enum CodingKeys: String, CodingKey {
        case filename
        case url
        case timestamp
        case sizeBytes
        case type
    }
}
