import Foundation
import Combine

@MainActor
public class DashboardViewModel: ObservableObject {
    @Published public var currentDevice: DeviceStatus?
    @Published public var weeklyStats: [DailyVisitStats] = []
    @Published public var recentVisits: [BirdVisit] = []
    @Published public var videoGallery: [BirdVisit] = []
    @Published public var selectedGalleryItem: BirdVisit?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private let deviceService: DeviceServiceProtocol
    private let visitService: VisitServiceProtocol
    private let statsService: StatsServiceProtocol
    
    public init(
        deviceService: DeviceServiceProtocol = MockDeviceService(),
        visitService: VisitServiceProtocol = MockVisitService(),
        statsService: StatsServiceProtocol = MockStatsService()
    ) {
        self.deviceService = deviceService
        self.visitService = visitService
        self.statsService = statsService
    }

    /// Convenience initializer to use live services tied to the current settings.
    public convenience init(settingsStore: SettingsStore) {
        let state = settingsStore.state
        self.init(
            deviceService: LiveDeviceService(settingsState: state),
            visitService: LiveVisitService(settingsState: state),
            statsService: LiveStatsService(settingsState: state)
        )
    }
    
    public func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let device = deviceService.getCurrentDevice()
            async let stats = statsService.getWeeklyStats()
            async let visits = visitService.getRecentVisits(limit: 10)
            async let gallery = visitService.getVideoGallery(limit: 5)
            
            self.currentDevice = try await device
            self.weeklyStats = try await stats
            self.recentVisits = try await visits
            self.videoGallery = try await gallery
            
            if let firstVideo = self.videoGallery.first {
                self.selectedGalleryItem = firstVideo
            }
            
        } catch {
            self.errorMessage = "Failed to load dashboard data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    public func selectNextGalleryItem() {
        guard let current = selectedGalleryItem,
              let index = videoGallery.firstIndex(where: { $0.id == current.id }),
              index < videoGallery.count - 1 else { return }
        selectedGalleryItem = videoGallery[index + 1]
    }
    
    public func selectPreviousGalleryItem() {
        guard let current = selectedGalleryItem,
              let index = videoGallery.firstIndex(where: { $0.id == current.id }),
              index > 0 else { return }
        selectedGalleryItem = videoGallery[index - 1]
    }
}
