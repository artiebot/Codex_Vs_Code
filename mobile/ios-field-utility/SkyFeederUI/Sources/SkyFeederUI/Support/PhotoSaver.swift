import Foundation
import Photos

public enum PhotoSaveError: LocalizedError {
    case authorizationDenied
    case unknown

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Photos permission is required to save captures."
        case .unknown:
            return "Unable to save to Photos."
        }
    }
}

public final class PhotoSaver {
    public static let shared = PhotoSaver()

    private init() {}

    public func saveIfNeeded(capture: Capture, url: URL, settings: SettingsState) async throws {
        guard settings.autoSaveToPhotos else { return }
        try await save(capture: capture, url: url)
    }

    public func save(capture: Capture, url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoSaveError.authorizationDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                if capture.asset.contentType.lowercased().contains("video") || url.pathExtension.lowercased() == "mp4" {
                    PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } else {
                    PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: PhotoSaveError.unknown)
                }
            }
        }
    }
}
