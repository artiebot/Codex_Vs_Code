import Foundation

@MainActor
public class FeederViewModel: ObservableObject {
    @Published public var battery: BatteryStatus?
    @Published public var photoItems: [FeederMediaItem] = []
    @Published public var videoItems: [FeederMediaItem] = []
    @Published public var retentionPolicy: RetentionPolicy?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var shareItem: FeederMediaItem?

    private let dataProvider: FeederDataProviding

    public init(
        dataProvider: FeederDataProviding = MockFeederDataProvider()
    ) {
        self.dataProvider = dataProvider
    }

    public func onAppear() {
        Task {
            await refresh()
        }
    }

    public func refresh() async {
        isLoading = true
        errorMessage = nil

        // Always try to load media; telemetry failures should not block the gallery.
        do {
            let snapshot = try await dataProvider.fetchMediaSnapshot()
            photoItems = snapshot.photos
            videoItems = snapshot.videos
        } catch {
            errorMessage = error.localizedDescription
        }

        // Fetch battery and retention policy opportunistically; ignore errors.
        if let batteryStatus = try? await dataProvider.fetchBatteryStatus() {
            battery = batteryStatus
        }
        if let policy = try? await dataProvider.fetchRetentionPolicy() {
            retentionPolicy = policy
        }

        isLoading = false
    }

    public func share(_ item: FeederMediaItem) {
        shareItem = item
    }

    public func delete(_ item: FeederMediaItem) {
        Task {
            do {
                try await dataProvider.delete(mediaItem: item)
                photoItems.removeAll { $0.id == item.id }
                videoItems.removeAll { $0.id == item.id }
            } catch {
                errorMessage = "Failed to delete item: \(error.localizedDescription)"
            }
        }
    }
}
