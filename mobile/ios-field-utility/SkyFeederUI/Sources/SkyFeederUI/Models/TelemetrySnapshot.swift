import Foundation

public struct TelemetrySnapshot: Codable, Equatable {
    public let packVoltage: Double
    public let solarWatts: Double
    public let loadWatts: Double
    public let internalTempC: Double
    public let signalStrengthDbm: Int
    public let batteryPercent: Int?
    public let isChargingViaSolar: Bool?

    public init(
        packVoltage: Double,
        solarWatts: Double,
        loadWatts: Double,
        internalTempC: Double,
        signalStrengthDbm: Int,
        batteryPercent: Int? = nil,
        isChargingViaSolar: Bool? = nil
    ) {
        self.packVoltage = packVoltage
        self.solarWatts = solarWatts
        self.loadWatts = loadWatts
        self.internalTempC = internalTempC
        self.signalStrengthDbm = signalStrengthDbm
        self.batteryPercent = batteryPercent
        self.isChargingViaSolar = isChargingViaSolar
    }
}
