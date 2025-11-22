import Foundation

/// Represents aggregated visit statistics for a single day.
public struct DailyVisitStats: Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public let visitCount: Int
    public let birdsDetectedCount: Int
    
    public init(date: Date, visitCount: Int, birdsDetectedCount: Int) {
        self.id = UUID()
        self.date = date
        self.visitCount = visitCount
        self.birdsDetectedCount = birdsDetectedCount
    }
    
    // Mock data helper
    public static func mockWeek() -> [DailyVisitStats] {
        let calendar = Calendar.current
        let today = Date()
        var stats: [DailyVisitStats] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -6 + i, to: today) {
                // Generate a sine-wave like pattern for the graph
                let base = 5.0
                let amplitude = 5.0
                let value = base + amplitude * sin(Double(i) * 0.8)
                let count = Int(value) + Int.random(in: 0...3)
                
                stats.append(DailyVisitStats(
                    date: date,
                    visitCount: count,
                    birdsDetectedCount: max(0, count - Int.random(in: 0...2))
                ))
            }
        }
        return stats
    }
}
