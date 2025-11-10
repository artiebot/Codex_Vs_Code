import SwiftUI

public struct StorageManagementView: View {
    @ObservedObject var viewModel: StorageManagementViewModel
    @State private var showDeletePhotosConfirmation = false
    @State private var showDeleteVideosConfirmation = false

    public init(viewModel: StorageManagementViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                Button(role: .destructive) {
                    showDeletePhotosConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete All Photos")
                    }
                }
                .disabled(viewModel.isDeleting)
                .confirmationDialog(
                    "Delete All Photos",
                    isPresented: $showDeletePhotosConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All Photos", role: .destructive) {
                        Task { await viewModel.deleteAllPhotos() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all photos from the device. This action cannot be undone.")
                }

                Button(role: .destructive) {
                    showDeleteVideosConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete All Videos")
                    }
                }
                .disabled(viewModel.isDeleting)
                .confirmationDialog(
                    "Delete All Videos",
                    isPresented: $showDeleteVideosConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All Videos", role: .destructive) {
                        Task { await viewModel.deleteAllVideos() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all videos from the device. This action cannot be undone.")
                }
            } header: {
                Text("Storage Actions")
            } footer: {
                Text("These actions will delete all media from the device storage. Use with caution.")
            }

            Section {
                Button {
                    Task { await viewModel.downloadLogs() }
                } label: {
                    if viewModel.isDownloading {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Downloading...")
                        }
                    } else {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                            Text("Download Logs")
                        }
                    }
                }
                .disabled(viewModel.isDownloading)

                if let logsURL = viewModel.downloadedLogsURL {
                    ShareLink(
                        item: logsURL,
                        preview: SharePreview("SkyFeeder Logs")
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Logs")
                        }
                    }
                }
            } header: {
                Text("Diagnostics")
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            if let success = viewModel.successMessage {
                Section {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Storage Management")
        .navigationBarTitleDisplayMode(.inline)
    }
}
