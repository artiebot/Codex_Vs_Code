import XCTest
@testable import SkyFeederFieldUtility

final class FieldUtilityTests: XCTestCase {
    func testDiskCacheStoresAndExpiresData() throws {
        let cache = DiskCache(directoryName: "TestCache-\(UUID().uuidString)")
        let key = "example"
        let payload = Data("hello".utf8)
        let url = try cache.store(data: payload, forKey: key)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(cache.data(forKey: key, ttl: 60), payload)

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: url.path)
        XCTAssertNil(cache.data(forKey: key, ttl: 10))
    }

    func testSampleProviderProducesDeterministicCaptures() async throws {
        let provider = SampleCaptureProvider(referenceDate: Date(timeIntervalSince1970: 0))
        let captures = try await provider.loadCaptures()
        XCTAssertEqual(captures.count, 8)
        XCTAssertTrue(captures.first!.capturedAt > captures.last!.capturedAt)
    }

    func testGallerySettingsPersistenceRoundTrip() {
        let suite = UserDefaults(suiteName: "test.gallery.settings")!
        suite.removePersistentDomain(forName: "test.gallery.settings")

        var settings = GallerySettings(provider: .presigned, filesystemRootPath: "/tmp", presignedEndpoint: URL(string: "https://example.com/manifest.json"), cacheTTL: 7200, enableFavoritesBadge: false)
        settings.persist(userDefaults: suite)

        let restored = GallerySettings(userDefaults: suite)
        XCTAssertEqual(restored.provider, .presigned)
        XCTAssertEqual(restored.filesystemRootPath, "/tmp")
        XCTAssertEqual(restored.presignedEndpoint, URL(string: "https://example.com/manifest.json"))
        XCTAssertEqual(restored.cacheTTL, 7200)
        XCTAssertEqual(restored.enableFavoritesBadge, false)
    }
}
