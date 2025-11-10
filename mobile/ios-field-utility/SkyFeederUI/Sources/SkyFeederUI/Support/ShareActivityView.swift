import SwiftUI
import UIKit

public struct ShareActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil

    public init(activityItems: [Any], applicationActivities: [UIActivity]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.modalPresentationStyle = .formSheet
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // no-op
    }
}

