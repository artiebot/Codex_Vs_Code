import Foundation

public struct TelemetrySnapshot: Codable, Equatable {
    public let packVoltage: Double
    public let solarWatts: Double
    public let loadWatts: Double
    public let internalTempC: Double
    public let signalStrengthDbm: Int

    public init(
        packVoltage: Double,
        solarWatts: Double,
        loadWatts: Double,
        internalTempC: Double,
        signalStrengthDbm: Int
    ) {
        self.packVoltage = packVoltage
        self.solarWatts = solarWatts
        self.loadWatts = loadWatts
        self.internalTempC = internalTempC
        self.signalStrengthDbm = signalStrengthDbm
    }
}
