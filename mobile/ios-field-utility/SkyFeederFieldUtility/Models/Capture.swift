import Foundation

struct Capture: Identifiable, Hashable, Codable {
    enum Source: String, Codable {
        case filesystem
        case presigned
    }

    let id: UUID
    let title: String
    let capturedAt: Date
    let duration: TimeInterval?
    let fileSizeBytes: Int
    let thumbnail: CaptureResource
    let asset: CaptureResource
    let source: Source
    var annotations: [String]
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        capturedAt: Date,
        duration: TimeInterval? = nil,
        fileSizeBytes: Int,
        thumbnail: CaptureResource,
        asset: CaptureResource,
        source: Source,
        annotations: [String] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.duration = duration
        self.fileSizeBytes = fileSizeBytes
        self.thumbnail = thumbnail
        self.asset = asset
        self.source = source
        self.annotations = annotations
        self.isFavorite = isFavorite
    }
}

struct CaptureResource: Hashable, Codable {
    enum Location: Hashable, Codable {
        case file(URL)
        case remote(URL)
    }

    let location: Location
    let contentType: String

    init(location: Location, contentType: String) {
        self.location = location
        self.contentType = contentType
    }
}

extension CaptureResource {
    var cacheKey: String {
        switch location {
        case .file(let url):
            return url.absoluteString
        case .remote(let url):
            return url.absoluteString
        }
    }
}

extension Capture {
    var formattedDate: String {
        Capture.dateFormatter.string(from: capturedAt)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .binary)
    }

    var formattedDuration: String {
        guard let duration else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "—"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
