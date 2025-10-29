import Foundation
import SwiftUI
import UIKit

@MainActor
final class ImagePipeline: ObservableObject {
    @Published var image: Image?

    private let capture: Capture
    private let provider: CaptureProvider
    private let cacheTTL: TimeInterval

    init(capture: Capture, provider: CaptureProvider, cacheTTL: TimeInterval) {
        self.capture = capture
        self.provider = provider
        self.cacheTTL = cacheTTL
    }

    func load() async {
        if let cached = DiskCache.shared.data(forKey: capture.thumbnail.cacheKey, ttl: cacheTTL),
           let uiImage = UIImage(data: cached) {
            image = Image(uiImage: uiImage)
            return
        }
        do {
            let data = try await provider.thumbnailData(for: capture)
            if let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
                _ = try? DiskCache.shared.store(data: data, forKey: capture.thumbnail.cacheKey)
            }
        } catch {
            image = Image(systemName: "exclamationmark.triangle")
        }
    }
}
