import SwiftUI

public struct SuccessToast: View {
    public let message: String
    public var onDismiss: (() -> Void)?

    public init(message: String, onDismiss: (() -> Void)? = nil) {
        self.message = message
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            if let onDismiss {
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
        .accessibilityIdentifier("success-toast")
    }
}
