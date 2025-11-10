import Foundation
import SwiftUI

@MainActor
public final class DetailViewModel: ObservableObject {
    @Published public private(set) var assetURL: URL?
    @Published public private(set) var isLoadingAsset: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var showSuccessToast: Bool = false

    public let capture: Capture

    private let provider: CaptureProvider
    private let settingsProvider: () -> SettingsState
    private let photoSaver: PhotoSaver

    private var didAutoSave = false

    public init(
        capture: Capture,
        provider: CaptureProvider,
        settingsProvider: @escaping () -> SettingsState,
        photoSaver: PhotoSaver = .shared
    ) {
        self.capture = capture
        self.provider = provider
        self.settingsProvider = settingsProvider
        self.photoSaver = photoSaver
    }

    public func prepareAsset() async {
        guard !isLoadingAsset else { return }
        isLoadingAsset = true
        errorMessage = nil
        defer { isLoadingAsset = false }

        do {
            let url = try await provider.assetURL(for: capture)
            assetURL = url

            let settings = settingsProvider()
            if settings.autoSaveToPhotos && !didAutoSave {
                try await photoSaver.saveIfNeeded(capture: capture, url: url, settings: settings)
                didAutoSave = true
                showSuccessToast = true
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    public func dismissToast() {
        showSuccessToast = false
    }
}
