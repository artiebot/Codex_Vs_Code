import Foundation

public struct ConnectivityDiagnostics: Codable, Equatable {
    public let statusText: String // e.g. "Healthy", "Degraded"
    public let recentFailures: Int
    public let averageRoundtripMs: Int?
    public let lastSync: Date?

    public init(
        statusText: String,
        recentFailures: Int,
        averageRoundtripMs: Int?,
        lastSync: Date?
    ) {
        self.statusText = statusText
        self.recentFailures = recentFailures
        self.averageRoundtripMs = averageRoundtripMs
        self.lastSync = lastSync
    }
}
