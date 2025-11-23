import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var baseURLString: String = ""
    @State private var deviceId: String = ""
    @State private var provider: CaptureProviderSelection = .presigned
    @State private var filesystemRoot: String = ""
    @State private var autoSave: Bool = false
    @State private var cacheTTLHours: Double = 6
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Connection")) {
                    TextField("API Base URL", text: $baseURLString)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("Device ID", text: $deviceId)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Capture Provider")) {
                    Picker("Provider", selection: $provider) {
                        ForEach(CaptureProviderSelection.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    if provider == .filesystem {
                        TextField("Filesystem Root", text: $filesystemRoot)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section(header: Text("Caching")) {
                    Toggle("Auto-save to Photos", isOn: $autoSave)
                    HStack {
                        Text("Cache TTL (hours)")
                        Spacer()
                        Text("\(Int(cacheTTLHours))h")
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                    Slider(value: $cacheTTLHours, in: 1...24, step: 1)
                        .tint(DesignSystem.primaryTeal)
                }
                
                Section {
                    Button("Save Settings") {
                        save()
                    }
                    .foregroundColor(DesignSystem.primaryTeal)
                }
            }
            .navigationTitle("Settings")
            .onAppear(perform: load)
        }
    }
    
    private func load() {
        let state = settingsStore.state
        baseURLString = state.baseURL?.absoluteString ?? ""
        deviceId = state.deviceID
        provider = state.provider
        filesystemRoot = state.filesystemRootPath
        autoSave = state.autoSaveToPhotos
        cacheTTLHours = state.cacheTTL / 3600
    }
    
    private func save() {
        settingsStore.update { state in
            state.deviceID = deviceId
            state.provider = provider
            state.filesystemRootPath = filesystemRoot
            state.autoSaveToPhotos = autoSave
            state.cacheTTL = cacheTTLHours * 3600
            state.baseURL = URL(string: baseURLString)
        }
        settingsStore.save()
    }
}
