
import Foundation

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var draft: SettingsState
    @Published public private(set) var showsHttpWarning: Bool = false

    public var allowLocalHttp: Bool { store.allowLocalHttp }

    private let store: SettingsStore

    public init(store: SettingsStore) {
        self.store = store
        self.draft = store.state
        refreshHttpWarning()
    }

    public func updateDraft(_ transform: (inout SettingsState) -> Void) {
        transform(&draft)
        refreshHttpWarning()
    }

    public func save() {
        store.update { state in
            state = draft
        }
        store.save()
        refreshHttpWarning()
    }

    public func reload() {
        draft = store.state
        refreshHttpWarning()
    }

    private func refreshHttpWarning() {
        if let scheme = draft.baseURL?.scheme?.lowercased() {
            showsHttpWarning = !store.allowLocalHttp && scheme == "http"
        } else {
            showsHttpWarning = false
        }
    }
}
