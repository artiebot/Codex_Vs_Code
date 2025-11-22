import Foundation

/// Represents the status of a connected SkyFeeder device.
public struct DeviceStatus: Identifiable, Codable {
    public let id: String
    public let name: String
    public let batteryPercentage: Int
    public let wifiSignalStrength: Int // RSSI in dBm
    public let temperatureCelsius: Double
    public let isOnline: Bool
    
    public init(
        id: String,
        name: String,
        batteryPercentage: Int,
        wifiSignalStrength: Int,
        temperatureCelsius: Double,
        isOnline: Bool
    ) {
        self.id = id
        self.name = name
        self.batteryPercentage = batteryPercentage
        self.wifiSignalStrength = wifiSignalStrength
        self.temperatureCelsius = temperatureCelsius
        self.isOnline = isOnline
    }
    
    // Mock data for previews and testing
    public static let mock = DeviceStatus(
        id: "sf-01",
        name: "SkyFeeder-01",
        batteryPercentage: 92,
        wifiSignalStrength: -62,
        temperatureCelsius: 21.0,
        isOnline: true
    )
}
