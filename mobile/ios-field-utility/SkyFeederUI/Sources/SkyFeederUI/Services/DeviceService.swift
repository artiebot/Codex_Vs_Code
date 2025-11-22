import Foundation

/// Protocol for fetching device information and status.
public protocol DeviceServiceProtocol {
    func getDevices() async throws -> [DeviceStatus]
    func getCurrentDevice() async throws -> DeviceStatus?
}

/// Mock implementation of DeviceService.
public class MockDeviceService: DeviceServiceProtocol {
    public init() {}
    
    public func getDevices() async throws -> [DeviceStatus] {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        return [DeviceStatus.mock]
    }
    
    public func getCurrentDevice() async throws -> DeviceStatus? {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return DeviceStatus.mock
    }
}
