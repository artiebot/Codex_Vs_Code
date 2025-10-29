import XCTest
@testable import SkyFeederFieldUtility

final class FieldUtilityTests: XCTestCase {
    func testDiskCacheStoresAndExpiresData() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TestCache-\(UUID().uuidString)", isDirectory: true)
        let cache = DiskCache(baseDirectory: tempDir, limits: [.thumbnails: 1024 * 1024, .assets: 1024 * 1024])
        let key = "example"
        let payload = Data("hello".utf8)
        let url = try cache.store(data: payload, forKey: key, category: .thumbnails)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(cache.data(forKey: key, ttl: 60, category: .thumbnails), payload)

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: url.path)
        XCTAssertNil(cache.data(forKey: key, ttl: 10, category: .thumbnails))
    }

    func testGallerySettingsManifestURL() {
        var settings = GallerySettings(
            provider: .presigned,
            filesystemRootPath: "",
            baseURL: URL(string: "http://10.0.0.4:8080/gallery"),
            deviceID: "kit-01",
            autoSaveToPhotos: true,
            cacheTTL: 7200
        )
        let expected = URL(string: "http://10.0.0.4:8080/gallery/kit-01/captures_index.json")
        XCTAssertEqual(settings.manifestURL, expected)

        settings.provider = .filesystem
        XCTAssertNil(settings.manifestURL)
    }

    func testGallerySettingsPersistenceRoundTrip() {
        let suite = UserDefaults(suiteName: "test.gallery.settings")!
        suite.removePersistentDomain(forName: "test.gallery.settings")

        var settings = GallerySettings(
            provider: .presigned,
            filesystemRootPath: "/tmp",
            baseURL: URL(string: "http://10.0.0.4:8080/gallery"),
            deviceID: "device-123",
            autoSaveToPhotos: true,
            cacheTTL: 7200
        )
        settings.persist(userDefaults: suite)

        let restored = GallerySettings(userDefaults: suite)
        XCTAssertEqual(restored.provider, .presigned)
        XCTAssertEqual(restored.filesystemRootPath, "/tmp")
        XCTAssertEqual(restored.baseURL, URL(string: "http://10.0.0.4:8080/gallery"))
        XCTAssertEqual(restored.deviceID, "device-123")
        XCTAssertEqual(restored.autoSaveToPhotos, true)
        XCTAssertEqual(restored.cacheTTL, 7200)
    }
}
