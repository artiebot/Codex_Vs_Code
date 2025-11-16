import Foundation

public enum CaptureProviderSelection: String, CaseIterable, Identifiable {
    case filesystem
    case presigned

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .filesystem:
            return "Local Folder"
        case .presigned:
            return "Presigned HTTP"
        }
    }

    public var requiresConnectivity: Bool {
        switch self {
        case .filesystem:
            return false
        case .presigned:
            return true
        }
    }
}

public struct SettingsState: Equatable {
    public var provider: CaptureProviderSelection
    public var filesystemRootPath: String
    public var baseURL: URL?
    public var deviceID: String
    public var autoSaveToPhotos: Bool
    public var cacheTTL: TimeInterval

    public init(
        provider: CaptureProviderSelection = .presigned,
        filesystemRootPath: String = "",
        baseURL: URL? = URL(string: "http://10.0.0.4:8080/gallery"),
        deviceID: String = "dev1",
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

extension SettingsState {
    enum Keys {
        static let provider = "gallery.provider"
        static let filesystemRoot = "gallery.filesystemRoot"
        static let baseURL = "gallery.baseURL"
        static let deviceID = "gallery.deviceID"
        static let autoSave = "gallery.autoSave"
        static let cacheTTL = "gallery.cacheTTL"
    }

    public init(userDefaults: UserDefaults = .standard) {
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
        deviceID = userDefaults.string(forKey: Keys.deviceID) ?? "dev1"
        autoSaveToPhotos = userDefaults.object(forKey: Keys.autoSave) as? Bool ?? false
        let ttl = userDefaults.double(forKey: Keys.cacheTTL)
        cacheTTL = ttl == 0 ? 60 * 60 * 6 : ttl
    }

    public func persist(userDefaults: UserDefaults = .standard) {
        userDefaults.set(provider.rawValue, forKey: Keys.provider)
        userDefaults.set(filesystemRootPath, forKey: Keys.filesystemRoot)
        userDefaults.set(baseURL?.absoluteString, forKey: Keys.baseURL)
        userDefaults.set(deviceID, forKey: Keys.deviceID)
        userDefaults.set(autoSaveToPhotos, forKey: Keys.autoSave)
        userDefaults.set(cacheTTL, forKey: Keys.cacheTTL)
    }

    public var manifestURL: URL? {
        guard provider == .presigned, let baseURL else { return nil }
        return baseURL
            .appendingPathComponent(deviceID, isDirectory: true)
            .appendingPathComponent("captures_index.json", isDirectory: false)
    }

    public var apiBaseURL: URL? {
        guard let baseURL else { return nil }
        let trimmed = baseURL.appendingPathComponent("", isDirectory: false)
        guard var components = URLComponents(url: trimmed, resolvingAgainstBaseURL: false) else {
            return trimmed
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url ?? trimmed.deletingLastPathComponent()
    }
}
