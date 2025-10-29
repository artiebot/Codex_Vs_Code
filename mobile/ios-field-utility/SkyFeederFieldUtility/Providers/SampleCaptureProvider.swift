import Foundation

final class SampleCaptureProvider: CaptureProvider {
    private let captures: [Capture]

    init(referenceDate: Date = Date(), diskCache: DiskCache = .shared) {
        var working: [Capture] = []
        let formatter = ISO8601DateFormatter()
        let sampleThumbnailData = Data(base64Encoded: SampleCaptureProvider.samplePNGBase64) ?? Data()
        let sampleAssetData = Data(base64Encoded: SampleCaptureProvider.sampleMP4Base64) ?? Data()

        for offset in 0..<8 {
            let captureDate = Calendar.current.date(byAdding: .hour, value: -offset * 3, to: referenceDate) ?? referenceDate
            let thumbKey = "sample-thumb-\(offset)"
            let assetKey = "sample-asset-\(offset)"
            let thumbURL = (try? diskCache.store(data: sampleThumbnailData, forKey: thumbKey)) ?? diskCache.url(forKey: thumbKey)
            let assetURL = (try? diskCache.store(data: sampleAssetData, forKey: assetKey)) ?? diskCache.url(forKey: assetKey)

            let capture = Capture(
                id: UUID(),
                title: "Capture \(formatter.string(from: captureDate))",
                capturedAt: captureDate,
                duration: 42,
                fileSizeBytes: sampleAssetData.count,
                thumbnail: CaptureResource(location: .file(thumbURL), contentType: "image/png"),
                asset: CaptureResource(location: .file(assetURL), contentType: "video/mp4"),
                source: .filesystem,
                annotations: ["Sample"],
                isFavorite: offset % 3 == 0
            )
            working.append(capture)
        }
        captures = working.sorted { $0.capturedAt > $1.capturedAt }
    }

    func loadCaptures() async throws -> [Capture] {
        captures
    }

    func thumbnailData(for capture: Capture) async throws -> Data {
        guard case .file(let url) = capture.thumbnail.location else {
            throw CaptureProviderError.assetUnavailable
        }
        return try Data(contentsOf: url)
    }

    func assetURL(for capture: Capture) async throws -> URL {
        guard case .file(let url) = capture.asset.location else {
            throw CaptureProviderError.assetUnavailable
        }
        return url
    }
}

private extension SampleCaptureProvider {
    /// 40x40 transparent PNG placeholder
    static let samplePNGBase64 = "iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAADhJREFUeNpi/P//PwMlgImBQjDwH0YqBiNggGEA4j8QbQxE1YBqkMJQg0wGoYBqmDgxIYBAMAXR4M5bAZpnAAAAAElFTkSuQmCC"

    /// Tiny MP4 header stub (not a playable file but keeps share/export flows exercised)
    static let sampleMP4Base64 = "AAAAIGZ0eXBtcDQyAAAAAG1wNDFtcDQxaXNvbTEyNQAAACBtZGF0AAAAAA=="
}
