import Foundation
import SwiftUI
import UIKit

@MainActor
public final class ImagePipeline: ObservableObject {
    @Published public private(set) var image: Image?

    private let capture: Capture
    private let provider: CaptureProvider
    private let cacheTTL: TimeInterval
    private let cacheManager: CacheManager

    public init(
        capture: Capture,
        provider: CaptureProvider,
        cacheTTL: TimeInterval,
        cacheManager: CacheManager = .shared
    ) {
        self.capture = capture
        self.provider = provider
        self.cacheTTL = cacheTTL
        self.cacheManager = cacheManager
    }

    public func load() async {
        if let cached = cacheManager.data(forKey: capture.thumbnail.cacheKey, ttl: cacheTTL, category: .thumbnails),
           let uiImage = UIImage(data: cached) {
            image = Image(uiImage: uiImage)
            return
        }
        do {
            let data = try await provider.thumbnailData(for: capture)
            if let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
                _ = try? cacheManager.store(data: data, forKey: capture.thumbnail.cacheKey, category: .thumbnails)
            }
        } catch {
            image = Image(systemName: "exclamationmark.triangle")
        }
    }
}
