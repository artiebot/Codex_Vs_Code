import Foundation
import UIKit

enum BadgeUpdater {
    private static let seenKey = "gallery.seenCaptureIDs"

    static func updateBadgeIfNeeded(captures: [Capture], enableBadge: Bool) {
        guard enableBadge else {
            UIApplication.shared.applicationIconBadgeNumber = 0
            return
        }

        let defaults = UserDefaults.standard
        let seen = defaults.array(forKey: seenKey) as? [String] ?? []
        let seenSet = Set(seen)
        let unseen = captures.filter { !seenSet.contains($0.id.uuidString) }
        UIApplication.shared.applicationIconBadgeNumber = unseen.count
    }

    static func markAsSeen(_ capture: Capture) {
        let defaults = UserDefaults.standard
        var seen = Set(defaults.array(forKey: seenKey) as? [String] ?? [])
        seen.insert(capture.id.uuidString)
        defaults.set(Array(seen), forKey: seenKey)
    }
}
