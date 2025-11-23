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

        // Fetch enough media to create visit sessions
        let fetchLimit = max(limit * 3, 30)
        async let photos = provider.fetchPhotos(baseURL: baseURL, deviceId: settingsState.deviceID, limit: fetchLimit)
        async let videos = provider.fetchVideos(baseURL: baseURL, deviceId: settingsState.deviceID, limit: fetchLimit)

        let allMedia = try await (photos + videos)
        let grouped = groupMediaIntoVisits(allMedia)

        return Array(grouped.prefix(limit))
    }
    
    public func getVideoGallery(limit: Int) async throws -> [BirdVisit] {
        guard let baseURL = settingsState.apiBaseURL else {
            throw MediaProviderError.missingAPIBase
        }

        let videos = try await provider.fetchVideos(baseURL: baseURL, deviceId: settingsState.deviceID, limit: limit)
        let visits = videos.map { media in
            BirdVisit(
                id: media.id,
                timestamp: media.timestamp ?? Date(),
                weightGrams: nil,
                media: [media]
            )
        }
        return visits
    }

    // MARK: - Helpers

    /// Group media captures into visit sessions using a rolling window.
    private func groupMediaIntoVisits(_ media: [MediaItem]) -> [BirdVisit] {
        let window: TimeInterval = 30 // seconds to coalesce into the same visit
        let sorted = media.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }

        var visits: [BirdVisit] = []
        var currentSession: [MediaItem] = []

        for item in sorted {
            guard let ts = item.timestamp else { continue }
            if let lastTs = currentSession.last?.timestamp, ts.timeIntervalSince(lastTs) <= window {
                currentSession.append(item)
            } else {
                if let first = currentSession.first {
                    visits.append(BirdVisit(
                        id: currentSession.map { $0.id }.joined(separator: "-"),
                        timestamp: first.timestamp ?? Date(),
                        weightGrams: nil,
                        media: currentSession
                    ))
                }
                currentSession = [item]
            }
        }

        if let first = currentSession.first {
            visits.append(BirdVisit(
                id: currentSession.map { $0.id }.joined(separator: "-"),
                timestamp: first.timestamp ?? Date(),
                weightGrams: nil,
                media: currentSession
            ))
        }

        // Newest first for UI
        return visits.sorted { $0.timestamp > $1.timestamp }
    }
}
