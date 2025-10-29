import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModel
    private let onSave: (GallerySettings) -> Void

    init(viewModel: SettingsViewModel = SettingsViewModel(), onSave: @escaping (GallerySettings) -> Void) {
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
                Section(header: Text("Filesystem"), footer: Text("Point to the directory that contains captures_index.json and the associated media files.")) {
                    TextField("Root path", text: $viewModel.settings.filesystemRootPath)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }

            if viewModel.settings.provider == .presigned {
                Section(header: Text("Presigned Endpoint"), footer: Text("Provide the HTTPS URL returning the capture manifest JSON.")) {
                    TextField("https://…", text: Binding(
                        get: { viewModel.settings.presignedEndpoint?.absoluteString ?? "" },
                        set: { viewModel.settings.presignedEndpoint = URL(string: $0) }
                    ))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                }

                Section(header: Text("Caching")) {
                    Stepper(value: Binding(
                        get: { Int(viewModel.settings.cacheTTL / 3600) },
                        set: { viewModel.settings.cacheTTL = Double($0) * 3600 }
                    ), in: 1...48) {
                        Text("Cache TTL: \(Int(viewModel.settings.cacheTTL / 3600)) hours")
                    }
                }
            }

            Section(header: Text("Badging")) {
                Toggle("Badge unseen captures", isOn: $viewModel.settings.enableFavoritesBadge)
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
