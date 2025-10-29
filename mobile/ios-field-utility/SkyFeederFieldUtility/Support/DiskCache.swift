import CryptoKit
import Foundation

final class DiskCache {
    static let shared = DiskCache()

    private let directory: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.skyfeeder.diskcache")

    init(directoryName: String = "SkyFeederCache", fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            directory = caches.appendingPathComponent(directoryName, isDirectory: true)
        } else {
            directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(directoryName, isDirectory: true)
        }
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func data(forKey key: String, ttl: TimeInterval) -> Data? {
        let url = fileURL(for: key)
        var resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        if let modificationDate = resourceValues?.contentModificationDate {
            let age = Date().timeIntervalSince(modificationDate)
            if ttl > 0, age > ttl {
                try? fileManager.removeItem(at: url)
                return nil
            }
        }
        return try? Data(contentsOf: url)
    }

    func store(data: Data, forKey key: String) throws -> URL {
        let url = fileURL(for: key)
        try data.write(to: url, options: .atomic)
        return url
    }

    func url(forKey key: String) -> URL {
        fileURL(for: key)
    }

    func clearExpired(ttl: TimeInterval) {
        queue.async { [directory, fileManager] in
            guard ttl > 0 else { return }
            let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            urls.forEach { url in
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modificationDate = values.contentModificationDate else { return }
                if Date().timeIntervalSince(modificationDate) > ttl {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
    }

    private func fileURL(for key: String) -> URL {
        let hashed = Self.hash(key)
        return directory.appendingPathComponent(hashed)
    }

    private static func hash(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
