import Foundation
import Combine

public class SettingsViewModel: ObservableObject {
    @Published public var selectedDeviceId: String = "sf-01"
    @Published public var sensitivity: Double = 0.5
    @Published public var quietHoursEnabled: Bool = false
    @Published public var quietHoursStart: Date = Date()
    @Published public var quietHoursEnd: Date = Date()
    @Published public var theme: AppTheme = .system
    
    public enum AppTheme: String, CaseIterable, Identifiable {
        case light, dark, system
        public var id: String { self.rawValue }
    }
    
    public init() {}
    
    // Mock save function
    public func saveSettings() {
        // TODO: Persist settings
    }
}
