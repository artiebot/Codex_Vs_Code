import SwiftUI

struct EventLogView: View {
    @ObservedObject var viewModel: EventLogViewModel

    var body: some View {
        DashboardCardContainer(title: "Event Log", icon: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 12) {
                eventListContent
                connectionStatus
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var eventListContent: some View {
        Group {
            if viewModel.events.isEmpty {
                Text("No events yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(viewModel.events) { event in
                    HStack(spacing: 8) {
                        Image(systemName: event.iconName)
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.message)
                                .font(.caption)
                            Text(event.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var connectionStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(viewModel.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
