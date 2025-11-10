import SwiftUI

struct EventLogView: View {
    @ObservedObject var viewModel: EventLogViewModel

    var body: some View {
        DashboardCardContainer(title: "Event Log", icon: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.events.isEmpty {
                    Text("Event log will appear here as soon as the device sends updates.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.events.reversed()) { event in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: event.iconName)
                                        .foregroundStyle(event.source == .local ? .accentColor : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.message)
                                            .font(.subheadline)
                                        Text(event.timestamp, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }

                HStack {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isConnected ? "Live feed connected" : "Waiting for WebSocket…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
