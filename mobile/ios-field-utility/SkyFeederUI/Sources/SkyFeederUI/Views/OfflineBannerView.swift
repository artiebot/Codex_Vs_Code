import SwiftUI

public struct OfflineBannerView: View {
    public let isOffline: Bool

    public init(isOffline: Bool) {
        self.isOffline = isOffline
    }

    public var body: some View {
        if isOffline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                Text("Offline - showing last cached content")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityIdentifier("offline-banner")
        }
    }
}
