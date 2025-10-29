import SwiftUI

struct CaptureDetailView: View {
    let capture: Capture
    @ObservedObject private var viewModel: GalleryViewModel
    @StateObject private var pipeline: ImagePipeline

    @State private var assetURL: URL?
    @State private var isLoadingAsset = false
    @State private var assetError: String?

    init(capture: Capture, viewModel: GalleryViewModel) {
        self.capture = capture
        self._viewModel = ObservedObject(initialValue: viewModel)
        _pipeline = StateObject(wrappedValue: viewModel.pipeline(for: capture))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                    if let image = pipeline.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    } else {
                        ProgressView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 12) {
                    Text(capture.title)
                        .font(.title2.weight(.semibold))
                    Label(capture.formattedDate, systemImage: "calendar")
                    Label(capture.formattedSize, systemImage: "internaldrive")
                    if let duration = capture.duration {
                        Label("Duration: \(capture.formattedDuration)", systemImage: "clock")
                            .accessibilityLabel("Duration \(duration) seconds")
                    }
                    if !capture.annotations.isEmpty {
                        Label(capture.annotations.joined(separator: ", "), systemImage: "tag")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isLoadingAsset {
                    ProgressView("Preparing asset…")
                }

                if let assetError {
                    Label(assetError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }

                if let assetURL {
                    ShareLink(item: assetURL) {
                        Label("Share capture", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await pipeline.load()
            await prepareAsset()
        }
    }

    private func prepareAsset() async {
        guard !isLoadingAsset else { return }
        isLoadingAsset = true
        assetError = nil
        do {
            assetURL = try await viewModel.assetURL(for: capture)
        } catch {
            assetError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoadingAsset = false
    }
}
