import Foundation
import Combine

@MainActor
public class FeederViewModel: ObservableObject {
    @Published public var battery: BatteryStatus?
    @Published public var photoItems: [FeederMediaItem] = []
    @Published public var videoItems: [FeederMediaItem] = []
    @Published public var retentionPolicy: RetentionPolicy?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var shareItem: FeederMediaItem?

    private let settingsStore: SettingsStore

    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    public func onAppear() {
        Task {
            await refresh()
        }
    }

    public func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch battery status
            battery = try await fetchBatteryStatus()

            // Fetch retention policy
            retentionPolicy = try await fetchRetentionPolicy()

            // Fetch media items
            let photos = try await fetchPhotos()
            let videos = try await fetchVideos()

            photoItems = photos
            videoItems = videos
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func share(_ item: FeederMediaItem) {
        shareItem = item
    }

    public func delete(_ item: FeederMediaItem) {
        Task {
            do {
                try await performDelete(item)
                photoItems.removeAll { $0.id == item.id }
                videoItems.removeAll { $0.id == item.id }
            } catch {
                errorMessage = "Failed to delete item: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - API Methods (to be implemented or mocked)

    private func fetchBatteryStatus() async throws -> BatteryStatus {
        // Mock implementation - replace with actual API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return BatteryStatus(percentage: 78, isChargingViaSolar: true, isOnline: true)
    }

    private func fetchRetentionPolicy() async throws -> RetentionPolicy {
        // Mock implementation - replace with actual API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return RetentionPolicy(photoRetentionDays: 7, videoRetentionDays: 3)
    }

    private func fetchPhotos() async throws -> [FeederMediaItem] {
        // Mock implementation - replace with actual API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return mockPhotos()
    }

    private func fetchVideos() async throws -> [FeederMediaItem] {
        // Mock implementation - replace with actual API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return mockVideos()
    }

    private func performDelete(_ item: FeederMediaItem) async throws {
        // Mock implementation - replace with actual API call
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    // MARK: - Mock Data

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
            ),
            FeederMediaItem(
                id: "photo-3",
                type: .photo,
                thumbnailURL: URL(string: "https://placekitten.com/302/400")!,
                mediaURL: URL(string: "https://placekitten.com/1202/1600")!,
                weightGrams: 512,
                capturedAt: calendar.date(byAdding: .hour, value: -6, to: now)!,
                expiresAt: calendar.date(byAdding: .day, value: 7, to: now)!
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
            ),
            FeederMediaItem(
                id: "video-2",
                type: .video,
                thumbnailURL: URL(string: "https://placekitten.com/304/400")!,
                mediaURL: URL(string: "https://placekitten.com/1204/1600")!,
                weightGrams: 394,
                capturedAt: calendar.date(byAdding: .hour, value: -12, to: now)!,
                expiresAt: calendar.date(byAdding: .day, value: 3, to: now)!
            )
        ]
    }
}
