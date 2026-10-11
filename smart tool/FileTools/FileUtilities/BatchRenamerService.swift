//
//  BatchRenamerService.swift
//  Borno Pulse
//

import AppKit
import Combine
import Foundation

public enum RenamerMode: String, CaseIterable, Identifiable, Sendable {
    case replace = "Find & Replace"
    case prefixSuffix = "Add Prefix / Suffix"
    case sequence = "Number Sequence"
    case casing = "Change Casing"
    
    public var id: String { rawValue }
}

public enum CasingMode: String, CaseIterable, Identifiable, Sendable {
    case lowercase = "lowercase"
    case uppercase = "UPPERCASE"
    case capitalized = "Title / Capitalized"
    
    public var id: String { rawValue }
}

public struct RenamePreviewItem: Identifiable, Sendable {
    public var id: UUID = UUID()
    public var originalURL: URL
    public var originalName: String { originalURL.lastPathComponent }
    public var newName: String
    public var hasCollision: Bool
    
    public init(originalURL: URL, newName: String, hasCollision: Bool = false) {
        self.originalURL = originalURL
        self.newName = newName
        self.hasCollision = hasCollision
    }
}

@MainActor
public final class BatchRenamerService: ObservableObject {
    public static let shared = BatchRenamerService()
    
    @Published public var files: [URL] = []
    @Published public var previewItems: [RenamePreviewItem] = []
    
    @Published public var mode: RenamerMode = .replace
    @Published public var findText: String = ""
    @Published public var replaceText: String = ""
    @Published public var prefixText: String = ""
    @Published public var suffixText: String = ""
    @Published public var sequencePrefix: String = "Item_"
    @Published public var sequenceStart: Int = 1
    @Published public var sequenceDigits: Int = 3
    @Published public var selectedCasing: CasingMode = .lowercase
    
    @Published public var isRenaming = false
    @Published public var statusMessage: String = "No files selected"
    
    public init() {}
    
    public func addFiles(urls: [URL]) {
        self.files.append(contentsOf: urls)
        updatePreview()
        statusMessage = "Added \(files.count) files to renamer"
    }
    
    public func clearFiles() {
        self.files.removeAll()
        self.previewItems.removeAll()
        statusMessage = "Cleared files"
    }
    
    public func updatePreview() {
        var items: [RenamePreviewItem] = []
        var seenNames = Set<String>()
        
        for (index, url) in files.enumerated() {
            let baseName = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            var updatedBase = baseName
            
            switch mode {
            case .replace:
                if !findText.isEmpty {
                    updatedBase = baseName.replacingOccurrences(of: findText, with: replaceText)
                }
            case .prefixSuffix:
                updatedBase = "\(prefixText)\(baseName)\(suffixText)"
            case .sequence:
                let num = sequenceStart + index
                let format = String(format: "%%0%dd", sequenceDigits)
                let numStr = String(format: format, num)
                updatedBase = "\(sequencePrefix)\(numStr)"
            case .casing:
                switch selectedCasing {
                case .lowercase: updatedBase = baseName.lowercased()
                case .uppercase: updatedBase = baseName.uppercased()
                case .capitalized: updatedBase = baseName.capitalized
                }
            }
            
            let finalName = ext.isEmpty ? updatedBase : "\(updatedBase).\(ext)"
            let collision = seenNames.contains(finalName)
            seenNames.insert(finalName)
            
            items.append(RenamePreviewItem(originalURL: url, newName: finalName, hasCollision: collision))
        }
        
        self.previewItems = items
    }
    
    public func executeRename() -> (success: Int, failed: Int) {
        guard !isRenaming, !previewItems.isEmpty else { return (0, 0) }
        isRenaming = true
        var success = 0
        var failed = 0
        
        let fileManager = FileManager.default
        
        for item in previewItems {
            let parentDir = item.originalURL.deletingLastPathComponent()
            let targetURL = parentDir.appendingPathComponent(item.newName)
            
            if targetURL == item.originalURL {
                success += 1
                continue
            }
            
            do {
                if fileManager.fileExists(atPath: targetURL.path) {
                    failed += 1
                } else {
                    try fileManager.moveItem(at: item.originalURL, to: targetURL)
                    success += 1
                }
            } catch {
                failed += 1
            }
        }
        
        isRenaming = false
        statusMessage = "Renamed \(success) file(s) successfully (\(failed) failed)."
        clearFiles()
        return (success, failed)
    }
}
