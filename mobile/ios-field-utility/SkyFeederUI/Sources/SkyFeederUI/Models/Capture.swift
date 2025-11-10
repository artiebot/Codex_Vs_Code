import Foundation

public struct Capture: Identifiable, Hashable, Codable {
    public enum Source: String, Codable {
        case filesystem
        case presigned
    }

    public let id: UUID
    public let title: String
    public let capturedAt: Date
    public let duration: TimeInterval?
    public let fileSizeBytes: Int
    public let thumbnail: CaptureResource
    public let asset: CaptureResource
    public let source: Source
    public var annotations: [String]
    public var isFavorite: Bool

    public init(
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

public struct CaptureResource: Hashable, Codable {
    public enum Location: Hashable, Codable {
        case file(URL)
        case remote(URL)
    }

    public let location: Location
    public let contentType: String

    public init(location: Location, contentType: String) {
        self.location = location
        self.contentType = contentType
    }
}

public extension CaptureResource {
    var cacheKey: String {
        switch location {
        case .file(let url):
            return url.absoluteString
        case .remote(let url):
            return url.absoluteString
        }
    }
}

public extension Capture {
    var formattedDate: String {
        Capture.dateFormatter.string(from: capturedAt)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .binary)
    }

    var formattedDuration: String {
        guard let duration else { return "" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? ""
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
