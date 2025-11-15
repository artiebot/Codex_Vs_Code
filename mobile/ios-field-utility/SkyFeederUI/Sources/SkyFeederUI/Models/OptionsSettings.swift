import Foundation

public enum CaptureType: String, Codable, CaseIterable {
    case photoOnly
    case videoOnly
    case photoAndShortVideo

    public var displayName: String {
        switch self {
        case .photoOnly: return "Photo only"
        case .videoOnly: return "Video only"
        case .photoAndShortVideo: return "Photo + short video"
        }
    }
}

public struct OptionsSettings: Codable, Equatable {
    public var minTriggerWeightGrams: Int
    public var captureType: CaptureType
    public var captureCooldownSeconds: Int
    public var quietHoursEnabled: Bool
    public var quietHoursStart: DateComponents // hour/minute
    public var quietHoursEnd: DateComponents
    public var notifyLowBattery: Bool
    public var notifyOnVisitor: Bool
    public var timeZoneAutoDetect: Bool

    public init(
        minTriggerWeightGrams: Int = 80,
        captureType: CaptureType = .photoAndShortVideo,
        captureCooldownSeconds: Int = 30,
        quietHoursEnabled: Bool = false,
        quietHoursStart: DateComponents = DateComponents(hour: 22, minute: 0),
        quietHoursEnd: DateComponents = DateComponents(hour: 6, minute: 0),
        notifyLowBattery: Bool = false,
        notifyOnVisitor: Bool = false,
        timeZoneAutoDetect: Bool = true
    ) {
        self.minTriggerWeightGrams = minTriggerWeightGrams
        self.captureType = captureType
        self.captureCooldownSeconds = captureCooldownSeconds
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.notifyLowBattery = notifyLowBattery
        self.notifyOnVisitor = notifyOnVisitor
        self.timeZoneAutoDetect = timeZoneAutoDetect
    }
}
