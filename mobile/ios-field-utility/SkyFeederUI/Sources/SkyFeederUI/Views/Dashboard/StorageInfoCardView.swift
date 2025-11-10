import SwiftUI

struct StorageInfoCardView: View {
    let photoCount: Int
    let videoCount: Int
    let freeSpaceBytes: Int?
    let photoBytes: Int?
    let videoBytes: Int?
    let logBytes: Int?

    var body: some View {
        DashboardCardContainer(title: "Storage", icon: "internaldrive") {
            VStack(alignment: .leading, spacing: 12) {
                // Free Space
                if let freeSpaceBytes {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Free Space")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatBytes(freeSpaceBytes))
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }

                Divider()

                // Photos
                HStack {
                    Image(systemName: "photo")
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text("\(photoCount)")
                                .font(.subheadline.weight(.medium))
                            if let photoBytes {
                                Text("(\(formatBytes(photoBytes)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Videos
                HStack {
                    Image(systemName: "film")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Videos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text("\(videoCount)")
                                .font(.subheadline.weight(.medium))
                            if let videoBytes {
                                Text("(\(formatBytes(videoBytes)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Logs
                if let logBytes {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Logs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatBytes(logBytes))
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
