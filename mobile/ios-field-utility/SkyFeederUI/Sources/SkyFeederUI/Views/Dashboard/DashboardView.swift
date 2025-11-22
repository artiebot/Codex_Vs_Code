import SwiftUI
import AVKit

public struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @State private var showingDevicePicker = false
    @State private var selectedVideo: BirdVisit?
    @State private var selectedVisit: BirdVisit?
    
    public init(viewModel: DashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.background.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .tint(DesignSystem.primaryTeal)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 1. Top Status Bar
                            topStatusBar
                            
                            // 2. Video Gallery Card
                            VideoGalleryCard(
                                item: viewModel.selectedGalleryItem,
                                onPlay: {
                                    if let item = viewModel.selectedGalleryItem, let url = item.videoUrl {
                                        selectedVideo = item
                                    }
                                },
                                onNext: viewModel.selectNextGalleryItem,
                                onPrevious: viewModel.selectPreviousGalleryItem,
                                onSeeAll: {
                                    // TODO: Navigate to full gallery
                                }
                            )
                            
                            // 3. Visits Graph
                            VisitsGraphView(stats: viewModel.weeklyStats)
                            
                            // 4. Recent Activity
                            RecentActivityList(
                                visits: viewModel.recentVisits,
                                onSelect: { visit in
                                    selectedVisit = visit
                                }
                            )
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.loadData()
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadData()
            }
            .sheet(item: $selectedVideo) { video in
                if let url = video.videoUrl {
                    VideoPlayerView(url: url)
                }
            }
            .sheet(item: $selectedVisit) { visit in
                // Simple detail view for now
                if let url = visit.thumbnailUrl {
                    ZoomableImageView(url: url)
                }
            }
        }
    }
    
    private var topStatusBar: some View {
        HStack {
            // Device Selector
            Button(action: { showingDevicePicker = true }) {
                HStack(spacing: 4) {
                    Text(viewModel.currentDevice?.name ?? "Select Device")
                        .font(DesignSystem.headline())
                        .foregroundColor(DesignSystem.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(DesignSystem.textSecondary)
                }
            }
            
            Spacer()
            
            // Status Icons
            if let device = viewModel.currentDevice {
                HStack(spacing: 12) {
                    statusItem(
                        icon: "battery.100", // Dynamic icon based on % would be better
                        text: "\(device.batteryPercentage)%"
                    )
                    statusItem(
                        icon: "wifi",
                        text: "\(device.wifiSignalStrength)%" // Using % for simplicity as per design, though it's RSSI
                    )
                    statusItem(
                        icon: "thermometer",
                        text: "\(Int(device.temperatureCelsius))°C"
                    )
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    private func statusItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundColor(DesignSystem.textSecondary)
    }
}
