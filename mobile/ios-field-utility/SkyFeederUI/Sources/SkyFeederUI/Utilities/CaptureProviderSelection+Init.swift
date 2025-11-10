public extension CaptureProviderSelection {
    init(from configurationValue: String) {
        switch configurationValue.lowercased() {
        case "filesystem", "localfilesystem":
            self = .filesystem
        default:
            self = .presigned
        }
    }
}
