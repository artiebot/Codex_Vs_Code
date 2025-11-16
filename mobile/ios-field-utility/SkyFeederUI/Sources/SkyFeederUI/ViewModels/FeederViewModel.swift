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

        do {
            async let batteryTask = dataProvider.fetchBatteryStatus()
            async let retentionTask = dataProvider.fetchRetentionPolicy()
            async let mediaTask = dataProvider.fetchMediaSnapshot()

            battery = try await batteryTask
            retentionPolicy = try await retentionTask
            let snapshot = try await mediaTask
            photoItems = snapshot.photos
            videoItems = snapshot.videos
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
                try await dataProvider.delete(mediaItem: item)
                photoItems.removeAll { $0.id == item.id }
                videoItems.removeAll { $0.id == item.id }
            } catch {
                errorMessage = "Failed to delete item: \(error.localizedDescription)"
            }
        }
    }
}
