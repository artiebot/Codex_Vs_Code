import Foundation

public struct LogEntry: Identifiable, Hashable {
    public let id = UUID()
    public let timestamp: Date
    public let message: String

    public init(timestamp: Date, message: String) {
        self.timestamp = timestamp
        self.message = message
    }
}
