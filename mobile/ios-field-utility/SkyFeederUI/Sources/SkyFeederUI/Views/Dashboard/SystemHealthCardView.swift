import SwiftUI

struct SystemHealthCardView: View {
    let services: [String: ServiceStatus]
    let uptimeSeconds: Int?
    let latencyMs: Double?

    struct ServiceStatus {
        let name: String
        let status: String
        let latencyMs: Double?

        var isHealthy: Bool {
            status == "healthy"
        }

        var statusColor: Color {
            switch status {
            case "healthy":
                return .green
            case "degraded", "timeout":
                return .orange
            default:
                return .red
            }
        }
    }

    var body: some View {
        DashboardCardContainer(title: "System Health", icon: "heart.fill") {
            VStack(alignment: .leading, spacing: 12) {
                // Uptime
                if let uptimeSeconds {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Uptime: \(formatUptime(uptimeSeconds))")
                            .font(.subheadline)
                    }
                }

                // API Latency
                if let latencyMs {
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundStyle(.secondary)
                        Text("API: \(Int(latencyMs))ms")
                            .font(.subheadline)
                    }
                }

                Divider()

                // Service Status
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sortedServices, id: \.name) { service in
                        HStack {
                            Circle()
                                .fill(service.statusColor)
                                .frame(width: 8, height: 8)
                            Text(service.name)
                                .font(.subheadline)
                            Spacer()
                            if let latency = service.latencyMs {
                                Text("\(Int(latency))ms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(service.status)
                                .font(.caption)
                                .foregroundStyle(service.isHealthy ? .green : .orange)
                        }
                    }
                }

                if sortedServices.isEmpty {
                    Text("No service data available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sortedServices: [ServiceStatus] {
        services.map { key, value in
            ServiceStatus(
                name: key,
                status: value.status,
                latencyMs: value.latencyMs
            )
        }.sorted { $0.name < $1.name }
    }

    private func formatUptime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
