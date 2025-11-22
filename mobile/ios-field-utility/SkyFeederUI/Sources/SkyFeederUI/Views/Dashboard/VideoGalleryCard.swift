import SwiftUI

struct VideoGalleryCard: View {
    let item: BirdVisit?
    let onPlay: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onSeeAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Video Gallery")
                    .font(DesignSystem.title2())
                    .foregroundColor(DesignSystem.textPrimary)
                
                Spacer()
                
                Button(action: onSeeAll) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(DesignSystem.textSecondary)
                }
            }
            
            // Main Card
            ZStack {
                if let item = item {
                    // Thumbnail
                    AsyncImage(url: item.thumbnailUrl) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().fill(Color.gray.opacity(0.3))
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Rectangle().fill(Color.gray.opacity(0.3))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 220)
                    .clipped()
                    .cornerRadius(16)
                    
                    // Play Button
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(radius: 4)
                    }
                    
                    // Navigation Arrows
                    HStack {
                        Button(action: onPrevious) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.leading, 8)
                        
                        Spacer()
                        
                        Button(action: onNext) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.trailing, 8)
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 220)
                        .cornerRadius(16)
                        .overlay(Text("No videos available").foregroundColor(DesignSystem.textSecondary))
                }
            }
        }
    }
}
