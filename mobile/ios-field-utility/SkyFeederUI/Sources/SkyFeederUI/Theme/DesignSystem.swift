import SwiftUI

public struct DesignSystem {
    // MARK: - Colors
    public static let background = Color(hex: "#F5F6F8")
    public static let primaryTeal = Color(hex: "#0F9A95")
    public static let cardBackground = Color.white
    public static let separator = Color(.systemGray4)

    public static let textPrimary = Color(hex: "#111111")
    public static let textSecondary = Color(hex: "#6F6F6F")

    public static let batteryGreen = Color(hex: "#34C759")
    public static let batteryYellow = Color(hex: "#FFCC00")
    public static let batteryRed = Color(hex: "#FF3B30")

    public static let statusOnline = Color(hex: "#34C759")
    public static let statusOffline = Color(hex: "#FF3B30")

    // MARK: - Typography
    public static func largeTitle() -> Font { .system(.largeTitle, design: .rounded).weight(.semibold) }
    public static func title() -> Font { .system(.title, design: .rounded).weight(.semibold) }
    public static func title2() -> Font { .system(.title2, design: .rounded).weight(.semibold) }
    public static func title3() -> Font { .system(.title3, design: .rounded).weight(.semibold) }
    public static func headline() -> Font { .system(.headline, design: .rounded) }
    public static func body() -> Font { .system(.body, design: .rounded) }
    public static func subheadline() -> Font { .system(.subheadline, design: .rounded) }
    public static func caption() -> Font { .system(.caption, design: .rounded) }
    public static func caption2() -> Font { .system(.caption2, design: .rounded) }
}

// MARK: - Color Hex Extension
public extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 8:
            (a, r, g, b) = (
                (int & 0xFF000000) >> 24,
                (int & 0x00FF0000) >> 16,
                (int & 0x0000FF00) >> 8,
                int & 0x000000FF
            )
        case 6:
            (a, r, g, b) = (
                255,
                (int & 0xFF0000) >> 16,
                (int & 0x00FF00) >> 8,
                int & 0x000000FF
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
