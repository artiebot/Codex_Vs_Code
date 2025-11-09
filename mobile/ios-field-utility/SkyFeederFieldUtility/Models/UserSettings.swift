import Foundation

enum CaptureProviderSelection: String, CaseIterable, Identifiable {
    case filesystem
    case presigned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .filesystem:
            return "Local Folder"
        case .presigned:
            return "Presigned HTTP"
        }
    }

    var requiresConnectivity: Bool {
        switch self {
        case .filesystem:
            return false
        case .presigned:
            return true
        }
    }
}

struct GallerySettings: Equatable {
    var provider: CaptureProviderSelection
    var filesystemRootPath: String
    var baseURL: URL?
    var deviceID: String
    var autoSaveToPhotos: Bool
    var cacheTTL: TimeInterval

    init(
        provider: CaptureProviderSelection = .presigned,
        filesystemRootPath: String = "",
        baseURL: URL? = URL(string: "http://10.0.0.4:8080/gallery"),
        deviceID: String = "field-kit-1",
        autoSaveToPhotos: Bool = false,
        cacheTTL: TimeInterval = 60 * 60 * 6
    ) {
        self.provider = provider
        self.filesystemRootPath = filesystemRootPath
        self.baseURL = baseURL
        self.deviceID = deviceID
        self.autoSaveToPhotos = autoSaveToPhotos
        self.cacheTTL = cacheTTL
    }
}

extension GallerySettings {
    private enum Keys {
        static let provider = "gallery.provider"
        static let filesystemRoot = "gallery.filesystemRoot"
        static let baseURL = "gallery.baseURL"
        static let deviceID = "gallery.deviceID"
        static let autoSave = "gallery.autoSave"
        static let cacheTTL = "gallery.cacheTTL"
    }

    init(userDefaults: UserDefaults = .standard) {
        if let stored = userDefaults.string(forKey: Keys.provider),
           let selection = CaptureProviderSelection(rawValue: stored) {
            provider = selection
        } else {
            provider = .presigned
        }
        filesystemRootPath = userDefaults.string(forKey: Keys.filesystemRoot) ?? ""
        if let value = userDefaults.string(forKey: Keys.baseURL) {
            baseURL = URL(string: value)
        } else {
            baseURL = URL(string: "http://10.0.0.4:8080/gallery")
        }
        deviceID = userDefaults.string(forKey: Keys.deviceID) ?? "field-kit-1"
        autoSaveToPhotos = userDefaults.object(forKey: Keys.autoSave) as? Bool ?? false
        let ttl = userDefaults.double(forKey: Keys.cacheTTL)
        cacheTTL = ttl == 0 ? 60 * 60 * 6 : ttl
    }

    func persist(userDefaults: UserDefaults = .standard) {
        userDefaults.set(provider.rawValue, forKey: Keys.provider)
        userDefaults.set(filesystemRootPath, forKey: Keys.filesystemRoot)
        userDefaults.set(baseURL?.absoluteString, forKey: Keys.baseURL)
        userDefaults.set(deviceID, forKey: Keys.deviceID)
        userDefaults.set(autoSaveToPhotos, forKey: Keys.autoSave)
        userDefaults.set(cacheTTL, forKey: Keys.cacheTTL)
    }

    var manifestURL: URL? {
        guard provider == .presigned, let baseURL else { return nil }
        return baseURL
            .appendingPathComponent(deviceID, isDirectory: true)
            .appendingPathComponent("indices", isDirectory: true)
            .appendingPathComponent("latest.json", isDirectory: false)
    }

    var legacyManifestURL: URL? {
        guard provider == .presigned, let baseURL else { return nil }
        return baseURL
            .appendingPathComponent(deviceID, isDirectory: true)
            .appendingPathComponent("captures_index.json", isDirectory: false)
    }
}
