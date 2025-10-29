#!/usr/bin/swift

import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#else
struct CGSize {
    var width: Double
    var height: Double
}
#endif

struct MockAsset: Codable {
    let id: UUID
    let capturedAt: Date
    let kind: String
    let filename: String
    let trigger: String
}

enum MockGeneratorError: Error {
    case unableToCreateOutput(URL)
}

let fileManager = FileManager.default
let outputRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
    .appendingPathComponent("mobile")
    .appendingPathComponent("ios-field-utility")
    .appendingPathComponent("MockMedia", isDirectory: true)

let thumbsDirectory = outputRoot.appendingPathComponent("thumbs", isDirectory: true)
let fullDirectory = outputRoot.appendingPathComponent("full", isDirectory: true)
let manifest = outputRoot.appendingPathComponent("manifest.json")

func ensureDirectory(_ url: URL) throws {
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
        if isDirectory.boolValue { return }
        throw MockGeneratorError.unableToCreateOutput(url)
    }
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
}

func writePlaceholderJPEG(to url: URL, size: CGSize, label: String) throws {
    #if canImport(AppKit)
    import AppKit
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.75, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.white,
        .font: NSFont.boldSystemFont(ofSize: 28),
        .paragraphStyle: paragraph
    ]
    let attributed = NSAttributedString(string: label, attributes: attributes)
    attributed.draw(in: NSRect(x: 0, y: size.height / 2 - 16, width: size.width, height: 32))

    image.unlockFocus()
    guard let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
        throw MockGeneratorError.unableToCreateOutput(url)
    }
    try jpeg.write(to: url)
    #else
    let banner = """
    SKYFEEDER
    \(label)
    """
    try banner.data(using: .utf8)?.write(to: url)
    #endif
}

func generateAssets(count: Int) throws {
    try ensureDirectory(outputRoot)
    try ensureDirectory(thumbsDirectory)
    try ensureDirectory(fullDirectory)

    var assets: [MockAsset] = []
    let startDate = Date()

    for index in 0..<count {
        let id = UUID()
        let capturedAt = startDate.addingTimeInterval(TimeInterval(-index * 90))
        let trigger = index.isMultiple(of: 2) ? "pir" : "scheduler"
        let kind = index.isMultiple(of: 5) ? "clip" : "photo"
        let namePrefix = capturedAt.ISO8601Format(.iso8601)
        let baseName = "\(namePrefix)-\(id.uuidString.prefix(6))"

        let thumbURL = thumbsDirectory.appendingPathComponent("\(baseName)-thumb.jpg")
        let fullURL = fullDirectory.appendingPathComponent("\(baseName)-full.jpg")

        try writePlaceholderJPEG(to: thumbURL, size: CGSize(width: 320, height: 240), label: "Thumb \(index + 1)")
        try writePlaceholderJPEG(to: fullURL, size: CGSize(width: 1920, height: 1080), label: "Full \(index + 1)")

        assets.append(MockAsset(
            id: id,
            capturedAt: capturedAt,
            kind: kind,
            filename: fullURL.lastPathComponent,
            trigger: trigger
        ))
    }

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(assets.sorted { $0.capturedAt > $1.capturedAt })
    try data.write(to: manifest, options: .atomic)

    print("✅ Generated \(assets.count) mock assets in \(outputRoot.path)")
    print("   thumbs: \(thumbsDirectory.path)")
    print("   full:   \(fullDirectory.path)")
    print("   manifest: \(manifest.path)")
}

do {
    let requestedCount = ProcessInfo.processInfo.environment["COUNT"].flatMap(Int.init) ?? 18
    try generateAssets(count: max(6, requestedCount))
} catch {
    fputs("❌ Failed to generate mock media: \(error)\n", stderr)
    exit(1)
}
