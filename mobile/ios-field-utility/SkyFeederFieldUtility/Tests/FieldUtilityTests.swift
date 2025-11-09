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
        let expected = URL(string: "http://10.0.0.4:8080/gallery/kit-01/indices/latest.json")
        let expectedLegacy = URL(string: "http://10.0.0.4:8080/gallery/kit-01/captures_index.json")
        XCTAssertEqual(settings.manifestURL, expected)
        XCTAssertEqual(settings.legacyManifestURL, expectedLegacy)

        settings.provider = .filesystem
        XCTAssertNil(settings.manifestURL)
        XCTAssertNil(settings.legacyManifestURL)
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

    func testPresignedCaptureProviderFallbackOn404() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let primaryURL = URL(string: "http://example.com/gallery/dev1/indices/latest.json")!
        let fallbackURL = URL(string: "http://example.com/gallery/dev1/captures_index.json")!

        MockURLProtocol.requestHandler = { request in
            if request.url == primaryURL {
                let response = HTTPURLResponse(url: primaryURL, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            } else if request.url == fallbackURL {
                let json = """
                {
                    "captures": [
                        {
                            "id": "12345678-1234-1234-1234-123456789012",
                            "title": "Test Capture",
                            "capturedAt": "2025-01-01T12:00:00Z",
                            "duration": 42.0,
                            "fileSizeBytes": 1024,
                            "thumbnailURL": "http://example.com/thumb.jpg",
                            "assetURL": "http://example.com/asset.mp4",
                            "contentType": "video/mp4"
                        }
                    ]
                }
                """
                let response = HTTPURLResponse(url: fallbackURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, json.data(using: .utf8)!)
            }
            fatalError("Unexpected request: \(request.url!)")
        }

        let provider = PresignedCaptureProvider(
            endpoint: primaryURL,
            fallbackEndpoint: fallbackURL,
            urlSession: session,
            cacheTTL: 3600
        )

        let captures = try await provider.loadCaptures()
        XCTAssertEqual(captures.count, 1)
        XCTAssertEqual(captures.first?.title, "Test Capture")
    }

    func testPresignedCaptureProviderSucceedsWithoutFallback() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let primaryURL = URL(string: "http://example.com/gallery/dev1/indices/latest.json")!
        let fallbackURL = URL(string: "http://example.com/gallery/dev1/captures_index.json")!

        var fallbackCalled = false

        MockURLProtocol.requestHandler = { request in
            if request.url == primaryURL {
                let json = """
                {
                    "captures": [
                        {
                            "id": "12345678-1234-1234-1234-123456789012",
                            "title": "Test Capture",
                            "capturedAt": "2025-01-01T12:00:00Z",
                            "duration": 42.0,
                            "fileSizeBytes": 1024,
                            "thumbnailURL": "http://example.com/thumb.jpg",
                            "assetURL": "http://example.com/asset.mp4",
                            "contentType": "video/mp4"
                        }
                    ]
                }
                """
                let response = HTTPURLResponse(url: primaryURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, json.data(using: .utf8)!)
            } else if request.url == fallbackURL {
                fallbackCalled = true
                fatalError("Fallback should not be called when primary succeeds")
            }
            fatalError("Unexpected request: \(request.url!)")
        }

        let provider = PresignedCaptureProvider(
            endpoint: primaryURL,
            fallbackEndpoint: fallbackURL,
            urlSession: session,
            cacheTTL: 3600
        )

        let captures = try await provider.loadCaptures()
        XCTAssertEqual(captures.count, 1)
        XCTAssertEqual(captures.first?.title, "Test Capture")
        XCTAssertFalse(fallbackCalled, "Fallback should not have been called")
    }
}

private class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Request handler not set")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
    }
}
