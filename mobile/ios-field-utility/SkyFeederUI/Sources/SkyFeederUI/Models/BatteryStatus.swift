import Foundation

public struct BatteryStatus: Codable, Equatable {
    public let percentage: Int // 0–100
    public let isChargingViaSolar: Bool
    public let isOnline: Bool

    public init(percentage: Int, isChargingViaSolar: Bool, isOnline: Bool) {
        self.percentage = percentage
        self.isChargingViaSolar = isChargingViaSolar
        self.isOnline = isOnline
    }
}
