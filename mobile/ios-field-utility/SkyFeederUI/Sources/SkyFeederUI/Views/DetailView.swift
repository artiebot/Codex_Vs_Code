import SwiftUI

public struct DetailView: View {
    @StateObject private var viewModel: DetailViewModel
    @StateObject private var pipeline: ImagePipeline
    @State private var isSharePresented = false

    public init(viewModel: DetailViewModel, pipeline: ImagePipeline) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _pipeline = StateObject(wrappedValue: pipeline)
    }

    public var body: some View {
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
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.capture.title)
                        .font(.title2.weight(.semibold))
                    Label(viewModel.capture.formattedDate, systemImage: "calendar")
                    Label(viewModel.capture.formattedSize, systemImage: "internaldrive")
                    if let duration = viewModel.capture.duration, !viewModel.capture.formattedDuration.isEmpty {
                        Label("Duration: \(viewModel.capture.formattedDuration)", systemImage: "clock")
                            .accessibilityLabel("Duration \(duration) seconds")
                    }
                    if !viewModel.capture.annotations.isEmpty {
                        Label(viewModel.capture.annotations.joined(separator: ", "), systemImage: "tag")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.isLoadingAsset {
                    ProgressView("Preparing asset...")
                        .accessibilityIdentifier("detail-loading-indicator")
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("detail-error-banner")
                }

                if let assetURL = viewModel.assetURL {
                    Button {
                        isSharePresented = true
                    } label: {
                        Label("Share capture", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("detail-share-button")
                    .sheet(isPresented: $isSharePresented) {
                        ShareActivityView(activityItems: [assetURL])
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await pipeline.load()
            await viewModel.prepareAsset()
        }
        .overlay(alignment: .bottom) {
            if viewModel.showSuccessToast {
                SuccessToast(message: "Saved to Photos") {
                    viewModel.dismissToast()
                }
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
