import CryptoKit
import Foundation

final class DiskCache {
    enum Category: String, CaseIterable {
        case thumbnails = "thumbs"
        case assets = "full"
    }

    static let shared = DiskCache()

    private let baseDirectory: URL
    private let directories: [Category: URL]
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.skyfeeder.diskcache")
    private let limits: [Category: UInt64]

    init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default,
        limits: [Category: UInt64] = [
            .thumbnails: 50 * 1024 * 1024,
            .assets: 1024 * 1024 * 1024
        ]
    ) {
        self.fileManager = fileManager
        self.limits = limits
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            self.baseDirectory = caches.appendingPathComponent("com.skyfeeder", isDirectory: true)
        } else {
            self.baseDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.skyfeeder", isDirectory: true)
        }

        var resolvedDirectories: [Category: URL] = [:]
        for category in Category.allCases {
            let directory = self.baseDirectory.appendingPathComponent(category.rawValue, isDirectory: true)
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            resolvedDirectories[category] = directory
        }
        directories = resolvedDirectories
    }

    func data(forKey key: String, ttl: TimeInterval, category: Category) -> Data? {
        let url = fileURL(for: key, category: category)
        var resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        if let modificationDate = resourceValues?.contentModificationDate {
            let age = Date().timeIntervalSince(modificationDate)
            if ttl > 0, age > ttl {
                try? fileManager.removeItem(at: url)
                return nil
            }
            // update modification date to reflect recent access
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        }
        return try? Data(contentsOf: url)
    }

    func store(data: Data, forKey key: String, category: Category) throws -> URL {
        let url = fileURL(for: key, category: category)
        try data.write(to: url, options: .atomic)
        evictIfNeeded(for: category)
        return url
    }

    func url(forKey key: String, category: Category) -> URL {
        fileURL(for: key, category: category)
    }

    func clearExpired(ttl: TimeInterval, category: Category) {
        queue.async { [fileManager, directories] in
            guard ttl > 0, let directory = directories[category] else { return }
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

    private func fileURL(for key: String, category: Category) -> URL {
        let hashed = Self.hash(key)
        guard let directory = directories[category] else {
            return baseDirectory.appendingPathComponent(category.rawValue, isDirectory: true).appendingPathComponent(hashed)
        }
        return directory.appendingPathComponent(hashed)
    }

    private func evictIfNeeded(for category: Category) {
        queue.async { [fileManager, directories, limits] in
            guard let limit = limits[category], limit > 0, let directory = directories[category] else { return }
            guard let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { return }
            var entries: [(url: URL, modified: Date, size: UInt64)] = []
            var total: UInt64 = 0
            for url in urls {
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let modified = values.contentModificationDate,
                      let size = values.fileSize else { continue }
                let size64 = UInt64(size)
                total += size64
                entries.append((url, modified, size64))
            }
            guard total > limit else { return }
            let sorted = entries.sorted { $0.modified < $1.modified }
            var remaining = total
            for entry in sorted {
                if remaining <= limit { break }
                try? fileManager.removeItem(at: entry.url)
                if remaining >= entry.size {
                    remaining -= entry.size
                } else {
                    remaining = 0
                }
            }
        }
    }

    private static func hash(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
