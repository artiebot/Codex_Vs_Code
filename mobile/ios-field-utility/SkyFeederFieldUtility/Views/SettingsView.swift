import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModel
    private let onSave: (GallerySettings) -> Void

    @MainActor
    init(viewModel: SettingsViewModel, onSave: @escaping (GallerySettings) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section(header: Text("Provider")) {
                Picker("Source", selection: $viewModel.settings.provider) {
                    ForEach(CaptureProviderSelection.allCases) { selection in
                        Text(selection.displayName).tag(selection)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.settings.provider == .filesystem {
                Section(header: Text("Local Folder"), footer: Text("Point to the directory that contains captures_index.json and the associated media files.")) {
                    TextField("Root path", text: $viewModel.settings.filesystemRootPath)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }

            if viewModel.settings.provider == .presigned {
                Section(header: Text("HTTP Endpoint"), footer: Text("Base URL should point to the gallery index root (e.g. http://10.0.0.4:8080/gallery).")) {
                    TextField("http://10.0.0.4:8080/gallery", text: Binding(
                        get: { viewModel.settings.baseURL?.absoluteString ?? "" },
                        set: { viewModel.settings.baseURL = URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    ))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                    TextField("Device ID", text: $viewModel.settings.deviceID)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }

            Section(header: Text("Photos"), footer: Text("When enabled, the app saves the cached asset to Photos as soon as it is available.")) {
                Toggle("Auto-save downloads to Photos", isOn: $viewModel.settings.autoSaveToPhotos)
            }

            Section(header: Text("Caching"), footer: Text("Larger TTLs retain thumbnails and assets longer in the on-device cache.")) {
                Stepper(value: Binding(
                    get: { Int(viewModel.settings.cacheTTL / 3600) },
                    set: { viewModel.settings.cacheTTL = Double($0) * 3600 }
                ), in: 1...48) {
                    Text("Cache TTL: \(Int(viewModel.settings.cacheTTL / 3600)) hours")
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.save()
                    onSave(viewModel.settings)
                    dismiss()
                }
            }
        }
    }
}
