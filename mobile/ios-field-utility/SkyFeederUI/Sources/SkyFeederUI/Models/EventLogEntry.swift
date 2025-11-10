import Foundation

public struct EventLogEntry: Identifiable, Equatable {
    public enum Source {
        case websocket
        case local
    }

    public let id = UUID()
    public let timestamp: Date
    public let message: String
    public let iconName: String
    public let source: Source

    public static func fromWebSocket(_ payload: EventPayload) -> EventLogEntry {
        let message = payload.message ?? payload.event ?? payload.type
        let iconName: String
        switch payload.type {
        case "upload_status":
            iconName = payload.status == "success" ? "checkmark.circle.fill" : "exclamationmark.circle"
        case "gallery_ack":
            iconName = "photo"
        case "trigger", "manual_trigger":
            iconName = "bolt.fill"
        default:
            iconName = "dot.circle"
        }
        return EventLogEntry(
            timestamp: payload.date,
            message: message ?? "Event received",
            iconName: iconName,
            source: .websocket
        )
    }
}

public struct EventPayload: Decodable {
    public let type: String
    public let message: String?
    public let event: String?
    public let status: String?
    public let ts: Double?

    public var date: Date {
        if let ts {
            return Date(timeIntervalSince1970: ts / 1000)
        }
        return Date()
    }
}
