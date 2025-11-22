import SwiftUI
import Charts

struct VisitsGraphView: View {
    let stats: [DailyVisitStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visits This Week")
                .font(DesignSystem.title2())
                .foregroundColor(DesignSystem.textPrimary)
            
            if stats.isEmpty {
                Text("No data available")
                    .foregroundColor(DesignSystem.textSecondary)
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(stats) { stat in
                        LineMark(
                            x: .value("Day", stat.date, unit: .day),
                            y: .value("Visits", stat.visitCount)
                        )
                        .foregroundStyle(DesignSystem.primaryTeal)
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Day", stat.date, unit: .day),
                            y: .value("Visits", stat.visitCount)
                        )
                        .foregroundStyle(DesignSystem.primaryTeal)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday())
                            .foregroundStyle(DesignSystem.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                            .foregroundStyle(DesignSystem.textSecondary.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(DesignSystem.textSecondary)
                    }
                }
                .frame(height: 150)
                
                // Stats Summary
                HStack(spacing: 32) {
                    VStack(alignment: .leading) {
                        HStack {
                            Rectangle()
                                .fill(DesignSystem.primaryTeal)
                                .frame(width: 12, height: 2)
                            Text("Birds detected")
                                .font(DesignSystem.caption())
                                .foregroundColor(DesignSystem.textSecondary)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("\(totalVisits) visits")
                            .font(DesignSystem.headline())
                            .foregroundColor(DesignSystem.textPrimary)
                        Text("Peak day")
                            .font(DesignSystem.caption())
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Mos. \(peakDay)")
                            .font(DesignSystem.headline())
                            .foregroundColor(DesignSystem.textPrimary)
                        Text("Most common:")
                            .font(DesignSystem.caption())
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var totalVisits: Int {
        stats.reduce(0) { $0 + $1.visitCount }
    }
    
    private var peakDay: String {
        guard let max = stats.max(by: { $0.visitCount < $1.visitCount }) else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: max.date)
    }
}
