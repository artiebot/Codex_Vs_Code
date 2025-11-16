import Foundation

public final class SettingsStore: ObservableObject {
    @Published public private(set) var state: SettingsState

    public let allowLocalHttp: Bool
    public let defaultProvider: CaptureProviderSelection
    public let showDevTools: Bool

    private let userDefaults: UserDefaults

    public init(
        userDefaults: UserDefaults = .standard,
        defaultProvider: CaptureProviderSelection = .presigned,
        allowLocalHttp: Bool = true,
        showDevTools: Bool = true
    ) {
        self.userDefaults = userDefaults
        self.defaultProvider = defaultProvider
        self.allowLocalHttp = allowLocalHttp
        self.showDevTools = showDevTools

        var loaded = SettingsState(userDefaults: userDefaults)
        if userDefaults.object(forKey: SettingsState.Keys.provider) == nil {
            loaded.provider = defaultProvider
            loaded.persist(userDefaults: userDefaults)
        }
        state = loaded
    }

    public func reload() {
        state = SettingsState(userDefaults: userDefaults)
    }

    public func update(_ transform: (inout SettingsState) -> Void) {
        var copy = state
        transform(&copy)
        state = copy
    }

    public func save() {
        state.persist(userDefaults: userDefaults)
    }
}
