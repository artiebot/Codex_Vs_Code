import SwiftUI

public struct DashboardView: View {
    @EnvironmentObject private var router: ApplicationRouter
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var liveStreamViewModel: LiveStreamViewModel
    @StateObject private var photosViewModel: MediaCarouselViewModel
    @StateObject private var videosViewModel: MediaCarouselViewModel
    @StateObject private var eventLogViewModel: EventLogViewModel

    private let columns = [
        GridItem(.flexible(minimum: 160), spacing: 16),
        GridItem(.flexible(minimum: 160), spacing: 16)
    ]

    public init(
        viewModel: DashboardViewModel,
        liveStreamViewModel: LiveStreamViewModel,
        photosViewModel: MediaCarouselViewModel,
        videosViewModel: MediaCarouselViewModel,
        eventLogViewModel: EventLogViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _liveStreamViewModel = StateObject(wrappedValue: liveStreamViewModel)
        _photosViewModel = StateObject(wrappedValue: photosViewModel)
        _videosViewModel = StateObject(wrappedValue: videosViewModel)
        _eventLogViewModel = StateObject(wrappedValue: eventLogViewModel)
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                WeightMonitorCardView(state: viewModel.weightCard)
                VisitStatusCardView(
                    state: viewModel.visitCard,
                    triggerAction: {
                        Task { await viewModel.triggerManualVisit() }
                    },
                    snapshotAction: {
                        Task { await viewModel.takeSnapshot() }
                    }
                )

                LiveCameraCardView(viewModel: liveStreamViewModel)

                MediaCarouselView(
                    title: "Recent Photos",
                    icon: "photo.on.rectangle",
                    viewModel: photosViewModel
                )

                MediaCarouselView(
                    title: "Recent Videos",
                    icon: "film.stack",
                    viewModel: videosViewModel
                )

                EventLogView(viewModel: eventLogViewModel)

                // System Health Card
                if let snapshot = viewModel.healthSnapshot {
                    SystemHealthCardView(
                        services: snapshot.services,
                        uptimeSeconds: snapshot.uptimeSeconds,
                        latencyMs: snapshot.latencyMs
                    )
                }

                // Storage Info Card
                if let snapshot = viewModel.healthSnapshot, let storage = snapshot.storage {
                    StorageInfoCardView(
                        photoCount: storage.photos.count,
                        videoCount: storage.videos.count,
                        freeSpaceBytes: storage.freeSpaceBytes,
                        photoBytes: storage.photos.totalBytes,
                        videoBytes: storage.videos.totalBytes,
                        logBytes: storage.logs.sizeBytes
                    )
                }

                // Settings and Storage Management buttons
                VStack(spacing: 12) {
                    Button {
                        router.showDeviceSettings()
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Device Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button {
                        router.showStorageManagement()
                    } label: {
                        HStack {
                            Image(systemName: "externaldrive")
                            Text("Storage Management")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .gridCellColumns(2)
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    router.showSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if viewModel.isOffline {
                    OfflineBannerView(isOffline: true)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityIdentifier("dashboard-offline-banner")
                        .padding(.horizontal)
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.15))
                        )
                        .padding(.horizontal)
                        .transition(.opacity)
                }

                if let banner = viewModel.actionBanner {
                    ToastBanner(message: banner)
                        .padding(.horizontal)
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.refresh()
            viewModel.startAutoRefresh()
            liveStreamViewModel.start()
            await photosViewModel.refresh()
            await videosViewModel.refresh()
            eventLogViewModel.start()
        }
        .onDisappear {
            liveStreamViewModel.stop()
            eventLogViewModel.stop()
        }
    }
}

struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout.weight(.medium))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.thinMaterial, in: Capsule())
    }
}
