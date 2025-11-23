import Foundation

/// Protocol for fetching bird visits and media.
public protocol VisitServiceProtocol {
    func getRecentVisits(limit: Int) async throws -> [BirdVisit]
    func getVideoGallery(limit: Int) async throws -> [BirdVisit]
}

/// Mock implementation of VisitService.
public class MockVisitService: VisitServiceProtocol {
    public init() {}
    
    public func getRecentVisits(limit: Int) async throws -> [BirdVisit] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        let now = Date()
        let sample = (0..<limit).map { idx in
            let ts = now.addingTimeInterval(Double(-idx * 600))
            let media = MediaItem(
                filename: "mock-\(idx).jpg",
                url: URL(string: "https://example.com/mock-\(idx).jpg")!,
                timestamp: ts,
                sizeBytes: 1024 * 10,
                type: .photo
            )
            return BirdVisit(
                id: "mock-\(idx)",
                timestamp: ts,
                weightGrams: nil,
                media: [media]
            )
        }
        return sample
    }
    
    public func getVideoGallery(limit: Int) async throws -> [BirdVisit] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        let now = Date()
        let sample = (0..<limit).map { idx in
            let ts = now.addingTimeInterval(Double(-idx * 900))
            let media = MediaItem(
                filename: "mock-video-\(idx).mp4",
                url: URL(string: "https://example.com/mock-video-\(idx).mp4")!,
                timestamp: ts,
                sizeBytes: 1024 * 1024,
                type: .clip
            )
            return BirdVisit(
                id: "mock-video-\(idx)",
                timestamp: ts,
                weightGrams: nil,
                media: [media]
            )
        }
        return sample
    }
}
