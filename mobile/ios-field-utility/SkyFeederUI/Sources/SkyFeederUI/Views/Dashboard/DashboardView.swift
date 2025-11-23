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
                            topStatusBar
                            
                            VideoGalleryCard(
                                item: viewModel.selectedGalleryItem,
                                onPlay: {
                                    if let item = viewModel.selectedGalleryItem, item.videoUrl != nil {
                                        selectedVideo = item
                                    }
                                },
                                onNext: viewModel.selectNextGalleryItem,
                                onPrevious: viewModel.selectPreviousGalleryItem,
                                onSeeAll: {
                                    // TODO: full gallery route
                                }
                            )
                            
                            VisitsGraphView(stats: viewModel.weeklyStats)
                            
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
                if let url = visit.thumbnailUrl {
                    ZoomableImageView(url: url)
                }
            }
        }
    }
    
    private var topStatusBar: some View {
        HStack {
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
            
            if let device = viewModel.currentDevice {
                HStack(spacing: 12) {
                    statusItem(icon: "battery.100", text: "\(device.batteryPercentage)%")
                    statusItem(icon: "wifi", text: wifiBars(from: device.wifiSignalStrength))
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
    
    private func wifiBars(from rssi: Int) -> String {
        switch rssi {
        case ..<(-80):
            return "Weak"
        case -80..<(-65):
            return "Fair"
        default:
            return "Good"
        }
    }
}
