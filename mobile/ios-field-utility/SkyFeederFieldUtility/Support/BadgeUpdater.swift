import Foundation
import UIKit

enum BadgeUpdater {
    private static let lastOpenedKey = "gallery.lastOpenedAt"

    static func updateBadge(with captures: [Capture]) {
        let defaults = UserDefaults.standard
        let lastOpened = defaults.object(forKey: lastOpenedKey) as? Date ?? .distantPast
        let unseen = captures.filter { $0.capturedAt > lastOpened }
        UIApplication.shared.applicationIconBadgeNumber = max(unseen.count, 0)
    }

    static func markOpened() {
        let now = Date()
        let defaults = UserDefaults.standard
        defaults.set(now, forKey: lastOpenedKey)
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}
