import SwiftUI

struct WeightMonitorCardView: View {
    let state: WeightCardState

    var body: some View {
        DashboardCardContainer(title: "Weight Monitor", icon: "scalemass") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(state.currentDisplay)
                            .font(.system(.title2, design: .rounded).monospacedDigit())
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Rolling Avg.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(state.averageDisplay)
                            .font(.system(.title2, design: .rounded).monospacedDigit())
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading) {
                        Text("Visits Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(state.visitsDisplay)
                            .font(.system(.title3, design: .rounded).monospacedDigit())
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Last Event")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(state.lastEventDisplay)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}
