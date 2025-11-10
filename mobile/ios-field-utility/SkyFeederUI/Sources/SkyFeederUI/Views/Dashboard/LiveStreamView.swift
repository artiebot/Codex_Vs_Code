import SwiftUI

struct LiveStreamView: View {
    @ObservedObject var viewModel: LiveStreamViewModel

    var body: some View {
        ZStack {
            if let image = viewModel.latestFrame {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minHeight: 140)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(alignment: .bottomTrailing) {
                        Text("Live")
                            .font(.caption.bold())
                            .padding(6)
                            .background(.thinMaterial, in: Capsule())
                            .padding(8)
                    }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting to live stream…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 140)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
            }
        }
        .animation(.easeInOut, value: viewModel.latestFrame)
    }
}
