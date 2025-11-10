import Foundation
import SwiftUI

public struct WeightCardState: Equatable {
    public var currentGrams: Double?
    public var rollingAverageGrams: Double?
    public var visitsToday: Int
    public var lastEventDate: Date?

    public static let placeholder = WeightCardState(
        currentGrams: nil,
        rollingAverageGrams: nil,
        visitsToday: 0,
        lastEventDate: nil
    )

    public var currentDisplay: String {
        guard let value = currentGrams else { return "--" }
        return String(format: "%.0f g", value)
    }

    public var averageDisplay: String {
        guard let value = rollingAverageGrams else { return "--" }
        return String(format: "%.0f g", value)
    }

    public var visitsDisplay: String {
        "\(visitsToday)"
    }

    public var lastEventDisplay: String {
        guard let date = lastEventDate else { return "No visits logged" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

public struct VisitStatusCardState: Equatable {
    public enum Presence: String {
        case present
        case absent
        case unknown
    }

    public var presence: Presence
    public var lastEvent: Date?
    public var actionStatus: String?

    public static let placeholder = VisitStatusCardState(
        presence: .unknown,
        lastEvent: nil,
        actionStatus: nil
    )

    public var presenceText: String {
        switch presence {
        case .present: return "Bird present"
        case .absent: return "No bird detected"
        case .unknown: return "Waiting for first event"
        }
    }

    public var presenceColor: Color {
        switch presence {
        case .present: return .green
        case .absent: return .secondary
        case .unknown: return .orange
        }
    }

    public var lastEventDisplay: String {
        guard let date = lastEvent else { return "Event log pending" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
