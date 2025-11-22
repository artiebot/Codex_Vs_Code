import Foundation
import Combine

@MainActor
public class DeveloperViewModel: ObservableObject {
    @Published public var batteryVoltage: Double = 3.92
    @Published public var batteryCurrent: Double = 0.15
    @Published public var remainingHours: Int = 14
    
    @Published public var rssi: Int = -62
    @Published public var ssid: String = "SkyNet_2.4G"
    @Published public var pingTimeMs: Int = 45
    @Published public var isConnected: Bool = true
    
    @Published public var logs: [LogEntry] = []
    
    public init() {
        // Mock logs
        self.logs = [
            LogEntry(timestamp: Date(), message: "System started", level: .info),
            LogEntry(timestamp: Date().addingTimeInterval(-60), message: "Wifi connected", level: .info),
            LogEntry(timestamp: Date().addingTimeInterval(-120), message: "Failed to sync time", level: .error)
        ]
    }
    
    public func sendDiagnostics() {
        // TODO: Implement send diagnostics
    }
    
    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let message: String
        public let level: LogLevel
    }
    
    public enum LogLevel {
        case info, warning, error
    }
}
