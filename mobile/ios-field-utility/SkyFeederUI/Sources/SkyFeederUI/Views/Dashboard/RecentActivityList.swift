import SwiftUI

struct RecentActivityList: View {
    let visits: [BirdVisit]
    let onSelect: (BirdVisit) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(DesignSystem.title2())
                .foregroundColor(DesignSystem.textPrimary)
            
            LazyVStack(spacing: 12) {
                ForEach(visits) { visit in
                    Button(action: { onSelect(visit) }) {
                        HStack(spacing: 12) {
                            // Thumbnail
                            AsyncImage(url: visit.thumbnailUrl) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Rectangle().fill(Color.gray.opacity(0.3))
                                }
                            }
                            .frame(width: 80, height: 80)
                            .cornerRadius(12)
                            .clipped()
                            
                            // Info
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(visit.speciesName ?? "Unidentified")
                                        .font(DesignSystem.headline())
                                        .foregroundColor(DesignSystem.textPrimary)
                                    Spacer()
                                    if let weight = visit.weightGrams {
                                        Text("\(Int(weight)) g")
                                            .font(DesignSystem.body())
                                            .foregroundColor(DesignSystem.textSecondary)
                                    }
                                }
                                
                                Text("\(visit.timestamp.formatted(date: .abbreviated, time: .omitted))")
                                    .font(DesignSystem.caption())
                                    .foregroundColor(DesignSystem.textSecondary)
                                
                                HStack {
                                    Circle()
                                        .fill(DesignSystem.primaryTeal)
                                        .frame(width: 8, height: 8)
                                    Text(visit.confidence != nil ? "Confidence" : "Bird detected")
                                        .font(DesignSystem.caption())
                                        .foregroundColor(DesignSystem.textSecondary)
                                    
                                    Spacer()
                                    
                                    if let confidence = visit.confidence {
                                        Text("\(Int(confidence * 100)) %")
                                            .font(DesignSystem.caption())
                                            .foregroundColor(DesignSystem.textSecondary)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(DesignSystem.cardBackground)
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}
