import Foundation

public struct DeviceSummary: Identifiable, Codable, Equatable {
    public let id: String // e.g. "sf-1234"
    public let isOnline: Bool
    public let batteryPercentage: Int
    public let lastContact: Date

    public init(id: String, isOnline: Bool, batteryPercentage: Int, lastContact: Date) {
        self.id = id
        self.isOnline = isOnline
        self.batteryPercentage = batteryPercentage
        self.lastContact = lastContact
    }

    private enum CodingKeys: String, CodingKey {
        case id = "deviceId"
        case isOnline
        case batteryPercentage = "batteryPercent"
        case lastContact
    }
}
