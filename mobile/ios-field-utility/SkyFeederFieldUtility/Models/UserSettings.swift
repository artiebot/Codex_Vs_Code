import Foundation

enum CaptureProviderSelection: String, CaseIterable, Identifiable {
    case sample
    case filesystem
    case presigned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sample:
            return "Sample Data"
        case .filesystem:
            return "Local Filesystem"
        case .presigned:
            return "Presigned HTTP"
        }
    }
}

struct GallerySettings: Equatable {
    var provider: CaptureProviderSelection
    var filesystemRootPath: String
    var presignedEndpoint: URL?
    var cacheTTL: TimeInterval
    var enableFavoritesBadge: Bool

    init(
        provider: CaptureProviderSelection = .sample,
        filesystemRootPath: String = "",
        presignedEndpoint: URL? = nil,
        cacheTTL: TimeInterval = 60 * 60 * 6,
        enableFavoritesBadge: Bool = true
    ) {
        self.provider = provider
        self.filesystemRootPath = filesystemRootPath
        self.presignedEndpoint = presignedEndpoint
        self.cacheTTL = cacheTTL
        self.enableFavoritesBadge = enableFavoritesBadge
    }
}

extension GallerySettings {
    private enum Keys {
        static let provider = "gallery.provider"
        static let filesystemRoot = "gallery.filesystemRoot"
        static let presignedEndpoint = "gallery.presignedEndpoint"
        static let cacheTTL = "gallery.cacheTTL"
        static let favoritesBadge = "gallery.favoritesBadge"
    }

    init(userDefaults: UserDefaults = .standard) {
        if let stored = userDefaults.string(forKey: Keys.provider),
           let selection = CaptureProviderSelection(rawValue: stored) {
            provider = selection
        } else {
            provider = .sample
        }
        filesystemRootPath = userDefaults.string(forKey: Keys.filesystemRoot) ?? ""
        if let value = userDefaults.string(forKey: Keys.presignedEndpoint) {
            presignedEndpoint = URL(string: value)
        } else {
            presignedEndpoint = nil
        }
        let ttl = userDefaults.double(forKey: Keys.cacheTTL)
        cacheTTL = ttl == 0 ? 60 * 60 * 6 : ttl
        enableFavoritesBadge = userDefaults.object(forKey: Keys.favoritesBadge) as? Bool ?? true
    }

    func persist(userDefaults: UserDefaults = .standard) {
        userDefaults.set(provider.rawValue, forKey: Keys.provider)
        userDefaults.set(filesystemRootPath, forKey: Keys.filesystemRoot)
        userDefaults.set(presignedEndpoint?.absoluteString, forKey: Keys.presignedEndpoint)
        userDefaults.set(cacheTTL, forKey: Keys.cacheTTL)
        userDefaults.set(enableFavoritesBadge, forKey: Keys.favoritesBadge)
    }
}
