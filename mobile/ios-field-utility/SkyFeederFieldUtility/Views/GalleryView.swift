import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var router: ApplicationRouter
    @StateObject private var viewModel: GalleryViewModel
    init(viewModel: GalleryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 12) {
            OfflineStatusBanner(isOffline: viewModel.isOffline)
                .animation(.easeInOut, value: viewModel.isOffline)

            if viewModel.isLoading {
                ProgressView("Loading captures…")
                    .padding()
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.2)))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if viewModel.sections.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .imageScale(.large)
                                .foregroundStyle(.secondary)
                            Text("No captures yet")
                                .font(.headline)
                            Text("Pull to refresh after the field kit uploads new media, or adjust the provider in Settings.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    ForEach(viewModel.sections) { section in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(section.title)
                                .font(.title3.weight(.semibold))
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                                ForEach(section.captures) { capture in
                                    Button {
                                        router.showDetail(for: capture)
                                        viewModel.markSeen(capture)
                                    } label: {
                                        CaptureGridItemView(
                                            capture: capture,
                                            pipeline: viewModel.pipeline(for: capture)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Gallery")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    router.showSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .task {
            let stored = GallerySettings(userDefaults: .standard)
            viewModel.reloadWith(settings: stored)
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}
