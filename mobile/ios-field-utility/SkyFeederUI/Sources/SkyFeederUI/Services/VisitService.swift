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
        return Array(BirdVisit.mocks.prefix(limit))
    }
    
    public func getVideoGallery(limit: Int) async throws -> [BirdVisit] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return BirdVisit.mocks.filter { $0.isVideo }.prefix(limit).map { $0 }
    }
}
