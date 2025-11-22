import Foundation

/// Protocol for fetching statistics.
public protocol StatsServiceProtocol {
    func getWeeklyStats() async throws -> [DailyVisitStats]
}

/// Mock implementation of StatsService.
public class MockStatsService: StatsServiceProtocol {
    public init() {}
    
    public func getWeeklyStats() async throws -> [DailyVisitStats] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return DailyVisitStats.mockWeek()
    }
}
