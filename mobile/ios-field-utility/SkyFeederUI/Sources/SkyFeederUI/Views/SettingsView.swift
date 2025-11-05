import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModel
    private let onSave: (SettingsState) -> Void

    @MainActor
    public init(viewModel: SettingsViewModel, onSave: @escaping (SettingsState) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSave = onSave
    }

    public var body: some View {
        Form {
            providerSection
            filesystemSection
            presignedSection
            photosSection
            cacheSection
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.save()
                    onSave(viewModel.draft)
                    dismiss()
                }
                .accessibilityIdentifier("settings-save-button")
            }
        }
    }

    private var providerSection: some View {
        Section(header: Text("Provider")) {
            Picker("Source", selection: Binding(
                get: { viewModel.draft.provider },
                set: { provider in viewModel.updateDraft { $0.provider = provider } }
            )) {
                ForEach(CaptureProviderSelection.allCases) { selection in
                    Text(selection.displayName).tag(selection)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var filesystemSection: some View {
        Group {
            if viewModel.draft.provider == .filesystem {
                Section(
                    header: Text("Local Folder"),
                    footer: Text("Point to the directory that contains captures_index.json and the associated media files.")
                ) {
                    TextField("Root path", text: Binding(
                        get: { viewModel.draft.filesystemRootPath },
                        set: { newValue in viewModel.updateDraft { $0.filesystemRootPath = newValue } }
                    ))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("settings-filesystem-path")
                }
            }
        }
    }

    private var presignedSection: some View {
        Group {
            if viewModel.draft.provider == .presigned {
                Section(
                    header: Text("HTTP Endpoint"),
                    footer: Text("Base URL should point to the gallery index root (e.g. https://10.0.0.4:8080/gallery).")
                ) {
                    TextField(
                        "https://example.com/gallery",
                        text: Binding(
                            get: { viewModel.draft.baseURL?.absoluteString ?? "" },
                            set: { newValue in
                                viewModel.updateDraft { state in
                                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    state.baseURL = trimmed.isEmpty ? nil : URL(string: trimmed)
                                }
                            }
                        )
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("settings-base-url")

                    if viewModel.showsHttpWarning {
                        Text("Tip: HTTPS is required for this build. Update the URL to use https://.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("settings-http-warning")
                    }

                    TextField("Device ID", text: Binding(
                        get: { viewModel.draft.deviceID },
                        set: { value in viewModel.updateDraft { $0.deviceID = value } }
                    ))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("settings-device-id")
                }
            }
        }
    }

    private var photosSection: some View {
        Section(
            header: Text("Photos"),
            footer: Text("When enabled, the app saves the cached asset to Photos as soon as it is available.")
        ) {
            Toggle("Auto-save downloads to Photos", isOn: Binding(
                get: { viewModel.draft.autoSaveToPhotos },
                set: { value in viewModel.updateDraft { $0.autoSaveToPhotos = value } }
            ))
            .accessibilityIdentifier("settings-auto-save")
        }
    }

    private var cacheSection: some View {
        Section(
            header: Text("Caching"),
            footer: Text("Larger TTLs retain thumbnails and assets longer in the on-device cache.")
        ) {
            Stepper(
                value: Binding(
                    get: { Int(viewModel.draft.cacheTTL / 3600) },
                    set: { hours in viewModel.updateDraft { $0.cacheTTL = Double(hours) * 3600 } }
                ),
                in: 1...48
            ) {
                Text("Cache TTL: \(Int(viewModel.draft.cacheTTL / 3600)) hours")
            }
            .accessibilityIdentifier("settings-cache-ttl")
        }
    }
}
