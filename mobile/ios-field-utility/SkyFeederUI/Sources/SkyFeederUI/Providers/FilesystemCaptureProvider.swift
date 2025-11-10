import Foundation

public final class FilesystemCaptureProvider: CaptureProvider {
    private struct ManifestEntry: Codable {
        let id: UUID
        let title: String
        let capturedAt: Date
        let duration: TimeInterval?
        let fileSizeBytes: Int
        let thumbnailPath: String
        let assetPath: String
        let contentType: String
    }

    private let root: URL
    private let manifestName: String
    private let fileManager: FileManager

    public init(root: URL, manifestName: String = "captures_index.json", fileManager: FileManager = .default) {
        self.root = root
        self.manifestName = manifestName
        self.fileManager = fileManager
    }

    public func loadCaptures() async throws -> [Capture] {
        let manifestURL = root.appendingPathComponent(manifestName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw CaptureProviderError.missingManifest
        }
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([ManifestEntry].self, from: data)
        return entries.map { entry in
            Capture(
                id: entry.id,
                title: entry.title,
                capturedAt: entry.capturedAt,
                duration: entry.duration,
                fileSizeBytes: entry.fileSizeBytes,
                thumbnail: CaptureResource(
                    location: .file(root.appendingPathComponent(entry.thumbnailPath)),
                    contentType: entry.contentType
                ),
                asset: CaptureResource(
                    location: .file(root.appendingPathComponent(entry.assetPath)),
                    contentType: entry.contentType
                ),
                source: .filesystem
            )
        }
    }

    public func thumbnailData(for capture: Capture) async throws -> Data {
        guard case .file(let url) = capture.thumbnail.location else {
            throw CaptureProviderError.invalidConfiguration("Thumbnail for filesystem capture must be a local file.")
        }
        return try Data(contentsOf: url)
    }

    public func assetURL(for capture: Capture) async throws -> URL {
        guard case .file(let url) = capture.asset.location else {
            throw CaptureProviderError.assetUnavailable
        }
        guard fileManager.fileExists(atPath: url.path) else {
            throw CaptureProviderError.assetUnavailable
        }
        return url
    }
}
