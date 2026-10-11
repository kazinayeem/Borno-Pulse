//
//  ClipboardStorage.swift
//  Borno Pulse
//
//  Local-only store for clipboard history. Directories are created owner-only (0700),
//  files owner-only (0600), and the store is excluded from Time Machine backups.
//  Data is not separately encrypted; it relies on FileVault for encryption at rest.
//

import AppKit
import Foundation
import ImageIO

@MainActor
public final class ClipboardStorage {
    public let rootDirectory: URL
    private let thumbnailCache = NSCache<NSString, NSImage>()

    public var historyFileURL: URL { rootDirectory.appendingPathComponent("clipboard_history.json") }
    public var imagesDirectory: URL { rootDirectory.appendingPathComponent("Images", isDirectory: true) }

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        thumbnailCache.countLimit = 200
        prepareDirectories()
    }

    public static var defaultRoot: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("NaemSmartTool/Clipboard", isDirectory: true)
    }

    private func prepareDirectories() {
        let fm = FileManager.default
        for dir in [rootDirectory, imagesDirectory] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        }
        // Files written by earlier versions used default (world-readable) permissions.
        for name in ["clipboard_history.json"] + storedImageNames().map({ "Images/\($0)" }) {
            let path = rootDirectory.appendingPathComponent(name).path
            if fm.fileExists(atPath: path) {
                try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            }
        }
        var root = rootDirectory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? root.setResourceValues(values)
    }

    // MARK: - History

    public func loadHistory() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: historyFileURL) else { return [] }
        return (try? JSONDecoder().decode([ClipboardItem].self, from: data)) ?? []
    }

    public func saveHistory(_ items: [ClipboardItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            try writeProtected(data, to: historyFileURL)
        } catch {
            NSLog("Borno Pulse: failed saving clipboard history: \(error.localizedDescription)")
        }
    }

    // MARK: - Images

    public func writeImage(_ pngData: Data, id: UUID) -> String? {
        let name = "\(id.uuidString).png"
        do {
            try writeProtected(pngData, to: imagesDirectory.appendingPathComponent(name))
            return name
        } catch {
            NSLog("Borno Pulse: failed storing clipboard image: \(error.localizedDescription)")
            return nil
        }
    }

    public func imageData(named name: String) -> Data? {
        try? Data(contentsOf: imagesDirectory.appendingPathComponent(name))
    }

    public func imageURL(named name: String) -> URL {
        imagesDirectory.appendingPathComponent(name)
    }

    public func deleteImage(named name: String) {
        thumbnailCache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(name))
    }

    public func thumbnail(named name: String, maxPixelSize: Int = 96) -> NSImage? {
        let key = "\(name)#\(maxPixelSize)" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        let url = imagesDirectory.appendingPathComponent(name)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    public func storedImageNames() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path)) ?? []
    }

    public func imageStorageBytes() -> Int64 {
        storedImageNames().reduce(Int64(0)) { total, name in
            let path = imagesDirectory.appendingPathComponent(name).path
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value ?? 0
            return total + size
        }
    }

    /// Removes image files that no history item references (e.g. after a crash mid-save).
    public func removeOrphanedImages(keeping referenced: Set<String>) {
        for name in storedImageNames() where !referenced.contains(name) {
            deleteImage(named: name)
        }
    }

    public func eraseEverything() {
        thumbnailCache.removeAllObjects()
        try? FileManager.default.removeItem(at: rootDirectory)
        prepareDirectories()
    }

    // MARK: - Helpers

    private func writeProtected(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
