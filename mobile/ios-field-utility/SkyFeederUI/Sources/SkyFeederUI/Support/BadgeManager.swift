import Foundation
import UIKit

public enum BadgeManager {
    private static let lastOpenedKey = "gallery.lastOpenedAt"

    public static func updateBadge(with captures: [Capture], userDefaults: UserDefaults = .standard) {
        let lastOpened = userDefaults.object(forKey: lastOpenedKey) as? Date ?? .distantPast
        let unseen = captures.filter { $0.capturedAt > lastOpened }
        UIApplication.shared.applicationIconBadgeNumber = max(unseen.count, 0)
    }

    public static func markOpened(userDefaults: UserDefaults = .standard) {
        let now = Date()
        userDefaults.set(now, forKey: lastOpenedKey)
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}
