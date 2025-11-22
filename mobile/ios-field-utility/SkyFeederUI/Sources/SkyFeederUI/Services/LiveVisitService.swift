import Foundation

public class LiveVisitService: VisitServiceProtocol {
    private let provider: MediaProvider
    private let settingsState: SettingsState
    
    public init(settingsState: SettingsState) {
        self.provider = MediaProvider()
        self.settingsState = settingsState
    }
    
    public func getRecentVisits(limit: Int) async throws -> [BirdVisit] {
        guard let baseURL = settingsState.apiBaseURL else {
            throw MediaProviderError.missingAPIBase
        }
        
        async let photos = provider.fetchPhotos(baseURL: baseURL, deviceId: settingsState.deviceID, limit: limit)
        async let videos = provider.fetchVideos(baseURL: baseURL, deviceId: settingsState.deviceID, limit: limit)
        
        let allMedia = try await (photos + videos)
        
        let sorted = allMedia.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
        
        return sorted.prefix(limit).map { item in
            BirdVisit(
                id: item.id,
                speciesName: "Unknown", // Metadata not yet available in MediaItem
                timestamp: item.timestamp ?? Date(),
                weightGrams: nil, // Metadata not yet available
                confidence: nil,
                thumbnailUrl: item.url, // Using main URL as thumbnail for now
                videoUrl: item.type == .clip ? item.url : nil,
                isVideo: item.type == .clip
            )
        }
    }
    
    public func getVideoGallery(limit: Int) async throws -> [BirdVisit] {
        guard let baseURL = settingsState.apiBaseURL else {
            throw MediaProviderError.missingAPIBase
        }
        
        let videos = try await provider.fetchVideos(baseURL: baseURL, deviceId: settingsState.deviceID, limit: limit)
        
        return videos.map { item in
            BirdVisit(
                id: item.id,
                speciesName: "Unknown",
                timestamp: item.timestamp ?? Date(),
                weightGrams: nil,
                confidence: nil,
                thumbnailUrl: item.url,
                videoUrl: item.url,
                isVideo: true
            )
        }
    }
}
