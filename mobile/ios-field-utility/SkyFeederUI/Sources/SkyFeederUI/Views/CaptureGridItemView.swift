import SwiftUI

public struct CaptureGridItemView: View {
    @StateObject private var pipeline: ImagePipeline
    private let capture: Capture

    public init(capture: Capture, pipeline: ImagePipeline) {
        _pipeline = StateObject(wrappedValue: pipeline)
        self.capture = capture
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
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
            HStack(spacing: 12) {
                Label(capture.formattedSize, systemImage: "internaldrive")
                if !capture.formattedDuration.isEmpty {
                    Label(capture.formattedDuration, systemImage: "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
        .onAppear { Task { await pipeline.load() } }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("capture-card-\(capture.id.uuidString)")
    }
}
