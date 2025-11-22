import Foundation

public class LiveStatsService: StatsServiceProtocol {
    private let provider: MediaProvider
    private let settingsState: SettingsState
    
    public init(settingsState: SettingsState) {
        self.provider = MediaProvider()
        self.settingsState = settingsState
    }
    
    public func getWeeklyStats() async throws -> [DailyVisitStats] {
        guard let baseURL = settingsState.apiBaseURL else {
            throw MediaProviderError.missingAPIBase
        }
        
        // Fetch enough data to cover a week
        // Ideally backend should provide this, but we'll aggregate locally for now
        let limit = 100 
        async let photos = provider.fetchPhotos(baseURL: baseURL, deviceId: settingsState.deviceID, limit: limit)
        async let videos = provider.fetchVideos(baseURL: baseURL, deviceId: settingsState.deviceID, limit: limit)
        
        let allMedia = try await (photos + videos)
        
        // Group by day
        let calendar = Calendar.current
        let today = Date()
        var stats: [DailyVisitStats] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -6 + i, to: today) {
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                let visitsForDay = allMedia.filter {
                    guard let timestamp = $0.timestamp else { return false }
                    return timestamp >= startOfDay && timestamp < endOfDay
                }
                
                stats.append(DailyVisitStats(
                    date: date,
                    visitCount: visitsForDay.count,
                    birdsDetectedCount: visitsForDay.count // Assuming all captures are birds for now
                ))
            }
        }
        
        return stats
    }
}
