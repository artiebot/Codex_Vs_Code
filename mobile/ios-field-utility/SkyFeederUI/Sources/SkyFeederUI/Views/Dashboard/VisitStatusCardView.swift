import SwiftUI

struct VisitStatusCardView: View {
    let state: VisitStatusCardState
    let triggerAction: () -> Void
    let snapshotAction: () -> Void

    var body: some View {
        DashboardCardContainer(title: "Visit Status", icon: "bird") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(state.presenceText)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(state.presenceColor)
                    Spacer()
                    Text(state.lastEventDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        triggerAction()
                    } label: {
                        Label("Trigger", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        snapshotAction()
                    } label: {
                        Label("Snapshot", systemImage: "camera")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
