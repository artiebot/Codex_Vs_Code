import SwiftUI

struct CaptureGridItemView: View {
    @StateObject private var pipeline: ImagePipeline
    private let capture: Capture

    init(capture: Capture, pipeline: ImagePipeline) {
        _pipeline = StateObject(wrappedValue: pipeline)
        self.capture = capture
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Group {
                            if let image = pipeline.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "photo")
                                    .imageScale(.large)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                    .clipped()
            }
            Text(capture.title)
                .font(.headline)
                .lineLimit(1)
            HStack {
                Label(capture.formattedSize, systemImage: "internaldrive")
                Label(capture.formattedDuration, systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
        .onAppear { Task { await pipeline.load() } }
    }
}
