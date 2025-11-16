import SwiftUI
import AVKit

public struct FeederView: View {
    @ObservedObject var viewModel: FeederViewModel

    public init(viewModel: FeederViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let battery = viewModel.battery {
                        BatteryCard(battery: battery)
                    }

                    PhotosSection(
                        photos: viewModel.photoItems,
                        retentionDays: viewModel.retentionPolicy?.photoRetentionDays,
                        isLoading: viewModel.isLoading,
                        onShare: { viewModel.share($0) },
                        onDelete: { viewModel.delete($0) }
                    )

                    VideosSection(
                        videos: viewModel.videoItems,
                        retentionDays: viewModel.retentionPolicy?.videoRetentionDays,
                        isLoading: viewModel.isLoading,
                        onShare: { viewModel.share($0) },
                        onDelete: { viewModel.delete($0) }
                    )
                }
                .padding()

                if viewModel.isLoading && viewModel.photoItems.isEmpty && viewModel.videoItems.isEmpty {
                    ProgressView()
                        .padding(.top, 24)
                }
            }
            .background(DesignSystem.background.ignoresSafeArea())
            .navigationTitle("SkyFeeder")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.onAppear()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(item: $viewModel.shareItem) { item in
                ShareActivityView(activityItems: [item.mediaURL])
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

// MARK: - Battery Card

struct BatteryCard: View {
    let battery: BatteryStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Battery bar
                BatteryBarView(percentage: battery.percentage)
                    .frame(width: 120, height: 50)

                Spacer()

                // Percentage text
                Text("\(battery.percentage)%")
                    .font(DesignSystem.largeTitle())
                    .foregroundColor(batteryColor(for: battery.percentage))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(battery.isChargingViaSolar ? DesignSystem.primaryTeal : DesignSystem.textSecondary)
                        .frame(width: 8, height: 8)
                    Text(battery.isChargingViaSolar ? "Charging via solar" : "On battery")
                        .font(DesignSystem.body())
                        .foregroundColor(DesignSystem.textSecondary)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(battery.isOnline ? DesignSystem.statusOnline : DesignSystem.statusOffline)
                        .frame(width: 8, height: 8)
                    Text(battery.isOnline ? "Feeder is online" : "Feeder is offline")
                        .font(DesignSystem.body())
                        .foregroundColor(DesignSystem.textSecondary)
                }
            }
        }
        .padding()
        .background(DesignSystem.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    func batteryColor(for percentage: Int) -> Color {
        switch percentage {
        case ..<20:
            return DesignSystem.batteryRed
        case 20..<50:
            return DesignSystem.batteryYellow
        default:
            return DesignSystem.batteryGreen
        }
    }
}

// MARK: - Battery Bar View

struct BatteryBarView: View {
    let percentage: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))

                // Fill
                RoundedRectangle(cornerRadius: 8)
                    .fill(fillColor)
                    .frame(width: geometry.size.width * CGFloat(percentage) / 100)
            }
        }
    }

    var fillColor: Color {
        switch percentage {
        case ..<20:
            return DesignSystem.batteryRed
        case 20..<50:
            return DesignSystem.batteryYellow
        default:
            return DesignSystem.batteryGreen
        }
    }
}

// MARK: - Photos Section

struct PhotosSection: View {
    let photos: [FeederMediaItem]
    let retentionDays: Int?
    let isLoading: Bool
    let onShare: (FeederMediaItem) -> Void
    let onDelete: (FeederMediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(DesignSystem.title2())
                .foregroundColor(DesignSystem.textPrimary)

            Text(retentionSubtitle(defaultDays: 7))
                .font(DesignSystem.caption())
                .foregroundColor(DesignSystem.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    if photos.isEmpty {
                        EmptyMediaPlaceholder(
                            message: isLoading ? "Loading photos..." : "No photos captured yet."
                        )
                    } else {
                        ForEach(photos) { photo in
                            MediaCard(
                                item: photo,
                                onShare: { onShare(photo) },
                                onDelete: { onDelete(photo) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func retentionSubtitle(defaultDays: Int) -> String {
        if let days = retentionDays {
            return "Photos are automatically removed after \(days) days."
        } else {
            return "Photos are automatically removed after \(defaultDays) days."
        }
    }
}

// MARK: - Videos Section

struct VideosSection: View {
    let videos: [FeederMediaItem]
    let retentionDays: Int?
    let isLoading: Bool
    let onShare: (FeederMediaItem) -> Void
    let onDelete: (FeederMediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Videos")
                .font(DesignSystem.title2())
                .foregroundColor(DesignSystem.textPrimary)

            Text(retentionSubtitle(defaultDays: 3))
                .font(DesignSystem.caption())
                .foregroundColor(DesignSystem.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    if videos.isEmpty {
                        EmptyMediaPlaceholder(
                            message: isLoading ? "Checking for videos..." : "No videos yet."
                        )
                    } else {
                        ForEach(videos) { video in
                            MediaCard(
                                item: video,
                                onShare: { onShare(video) },
                                onDelete: { onDelete(video) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func retentionSubtitle(defaultDays: Int) -> String {
        if let days = retentionDays {
            return "Videos are automatically removed after \(days) days."
        } else {
            return "Videos are automatically removed after \(defaultDays) days."
        }
    }
}

// MARK: - Media Card

struct MediaCard: View {
    let item: FeederMediaItem
    let onShare: () -> Void
    let onDelete: () -> Void

    @State private var showingVideoPlayer = false

    var body: some View {
        ZStack {
            // Thumbnail
            AsyncImage(url: item.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(3/4, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(3/4, contentMode: .fill)
                    .overlay {
                        ProgressView()
                    }
            }
            .frame(width: 180, height: 240)
            .clipped()

            // Gradient overlay at bottom
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
            }

            // Content overlay
            VStack {
                // Top right buttons
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button(action: onShare) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(8)
                }

                Spacer()

                // Bottom left info
                VStack(alignment: .leading, spacing: 4) {
                    Text(weightText)
                        .font(DesignSystem.caption())
                        .foregroundColor(.white)

                    Text(item.capturedAt, style: .date)
                        .font(DesignSystem.caption2())
                        .foregroundColor(.white.opacity(0.8))

                    Text("Expires on \(item.expiresAt, style: .date)")
                        .font(DesignSystem.caption2())
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Play button for videos
            if item.type == .video {
                Button(action: { showingVideoPlayer = true }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                }
            }
        }
        .frame(width: 180, height: 240)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .sheet(isPresented: $showingVideoPlayer) {
            if item.type == .video {
                VideoPlayerView(url: item.mediaURL)
            }
        }
    }

    private var weightText: String {
        if item.weightGrams > 0 {
            return "Weight: \(Int(item.weightGrams))g"
        } else {
            return "Weight unavailable"
        }
    }
}

struct EmptyMediaPlaceholder: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.title)
                .foregroundColor(DesignSystem.textSecondary.opacity(0.8))
            Text(message)
                .font(DesignSystem.body())
                .multilineTextAlignment(.center)
                .foregroundColor(DesignSystem.textSecondary)
        }
        .frame(width: 200, height: 200)
        .background(DesignSystem.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Video Player

struct VideoPlayerView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VideoPlayer(player: AVPlayer(url: url))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
