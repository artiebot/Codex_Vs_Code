import Foundation

public struct FeederMediaSnapshot {
    public let photos: [FeederMediaItem]
    public let videos: [FeederMediaItem]

    public init(photos: [FeederMediaItem], videos: [FeederMediaItem]) {
        self.photos = photos
        self.videos = videos
    }
}

@MainActor
public protocol FeederDataProviding {
    func fetchBatteryStatus() async throws -> BatteryStatus
    func fetchRetentionPolicy() async throws -> RetentionPolicy
    func fetchMediaSnapshot() async throws -> FeederMediaSnapshot
    func delete(mediaItem: FeederMediaItem) async throws
}

public enum FeederDataProviderError: LocalizedError {
    case unsupportedDeletion
    case missingEndpoint
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedDeletion:
            return "Deleting captures is not supported yet."
        case .missingEndpoint:
            return "Cannot determine API endpoint for deleting media."
        case .requestFailed(let reason):
            return "Delete failed: \(reason)."
        }
    }
}

public struct MockFeederDataProvider: FeederDataProviding {
    public init() {}

    public func fetchBatteryStatus() async throws -> BatteryStatus {
        BatteryStatus(percentage: 78, isChargingViaSolar: true, isOnline: true)
    }

    public func fetchRetentionPolicy() async throws -> RetentionPolicy {
        RetentionPolicy(photoRetentionDays: 7, videoRetentionDays: 3)
    }

    public func fetchMediaSnapshot() async throws -> FeederMediaSnapshot {
        FeederMediaSnapshot(
            photos: mockPhotos(),
            videos: mockVideos()
        )
    }

    public func delete(mediaItem: FeederMediaItem) async throws {
        // No-op for mock provider
    }

    private func mockPhotos() -> [FeederMediaItem] {
        let now = Date()
        let calendar = Calendar.current
        return [
            FeederMediaItem(
                id: "photo-1",
                type: .photo,
                thumbnailURL: URL(string: "https://placekitten.com/300/400")!,
                mediaURL: URL(string: "https://placekitten.com/1200/1600")!,
                weightGrams: 453,
                capturedAt: calendar.date(byAdding: .day, value: -2, to: now)!,
                expiresAt: calendar.date(byAdding: .day, value: 5, to: now)!
            ),
            FeederMediaItem(
                id: "photo-2",
                type: .photo,
                thumbnailURL: URL(string: "https://placekitten.com/301/400")!,
                mediaURL: URL(string: "https://placekitten.com/1201/1600")!,
                weightGrams: 289,
                capturedAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                expiresAt: calendar.date(byAdding: .day, value: 6, to: now)!
            )
        ]
    }

    private func mockVideos() -> [FeederMediaItem] {
        let now = Date()
        let calendar = Calendar.current
        return [
            FeederMediaItem(
                id: "video-1",
                type: .video,
                thumbnailURL: URL(string: "https://placekitten.com/303/400")!,
                mediaURL: URL(string: "https://placekitten.com/1203/1600")!,
                weightGrams: 421,
                capturedAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                expiresAt: calendar.date(byAdding: .day, value: 2, to: now)!
            )
        ]
    }
}
