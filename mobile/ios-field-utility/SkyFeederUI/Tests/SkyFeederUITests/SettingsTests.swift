import XCTest
@testable import SkyFeederUI

final class SettingsTests: XCTestCase {
    func testCacheManagerStoresAndExpiresData() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TestCache-\(UUID().uuidString)", isDirectory: true)
        let cache = CacheManager(baseDirectory: tempDir, limits: [.thumbnails: 1024 * 1024, .assets: 1024 * 1024])
        let key = "example"
        let payload = Data("hello".utf8)

        let url = try cache.store(data: payload, forKey: key, category: .thumbnails)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(cache.data(forKey: key, ttl: 60, category: .thumbnails), payload)

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: url.path)
        XCTAssertNil(cache.data(forKey: key, ttl: 10, category: .thumbnails))
    }

    func testSettingsStateManifestURL() {
        var state = SettingsState(
            provider: .presigned,
            filesystemRootPath: "",
            baseURL: URL(string: "http://10.0.0.4:8080/gallery"),
            deviceID: "kit-01",
            autoSaveToPhotos: true,
            cacheTTL: 7200
        )
        let expected = URL(string: "http://10.0.0.4:8080/gallery/kit-01/captures_index.json")
        XCTAssertEqual(state.manifestURL, expected)

        state.provider = .filesystem
        XCTAssertNil(state.manifestURL)
    }

    func testSettingsStatePersistenceRoundTrip() {
        let suiteName = "test.gallery.settings"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)

        var state = SettingsState(
            provider: .presigned,
            filesystemRootPath: "/tmp",
            baseURL: URL(string: "https://example.com/gallery"),
            deviceID: "device-123",
            autoSaveToPhotos: true,
            cacheTTL: 7200
        )
        state.persist(userDefaults: suite)

        let restored = SettingsState(userDefaults: suite)
        XCTAssertEqual(restored.provider, .presigned)
        XCTAssertEqual(restored.filesystemRootPath, "/tmp")
        XCTAssertEqual(restored.baseURL, URL(string: "https://example.com/gallery"))
        XCTAssertEqual(restored.deviceID, "device-123")
        XCTAssertEqual(restored.autoSaveToPhotos, true)
        XCTAssertEqual(restored.cacheTTL, 7200)
    }
}
