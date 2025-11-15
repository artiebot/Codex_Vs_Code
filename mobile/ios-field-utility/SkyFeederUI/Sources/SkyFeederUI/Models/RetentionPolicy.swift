import Foundation

public struct RetentionPolicy: Codable, Equatable {
    public let photoRetentionDays: Int
    public let videoRetentionDays: Int

    public init(photoRetentionDays: Int, videoRetentionDays: Int) {
        self.photoRetentionDays = photoRetentionDays
        self.videoRetentionDays = videoRetentionDays
    }
}
