//
//  ArchiveUtilityService.swift
//  Naem Smart Tool
//

import AppKit
import Combine
import Foundation

@MainActor
public final class ArchiveUtilityService: ObservableObject {
    public static let shared = ArchiveUtilityService()
    
    @Published public var selectedURLs: [URL] = []
    @Published public var archiveOutputFilename: String = "Archive.zip"
    @Published public var extractionDestination: URL?
    @Published public var isProcessing = false
    @Published public var statusMessage: String = "Ready"
    
    public init() {
        self.extractionDestination = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    public func selectFilesForArchiving() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = true
        openPanel.prompt = "Choose Items"
        openPanel.title = "Select Files/Folders to Compress into ZIP"
        
        if openPanel.runModal() == .OK {
            self.selectedURLs = openPanel.urls
            statusMessage = "Selected \(openPanel.urls.count) item(s) to archive"
        }
    }
    
    public func createZipArchive() {
        guard !isProcessing, !selectedURLs.isEmpty else { return }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save ZIP Archive"
        let name = archiveOutputFilename.hasSuffix(".zip") ? archiveOutputFilename : "\(archiveOutputFilename).zip"
        savePanel.nameFieldStringValue = name
        
        guard savePanel.runModal() == .OK, let outURL = savePanel.url else { return }
        
        isProcessing = true
        statusMessage = "Creating ZIP archive..."
        let sources = selectedURLs
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // Use system ditto utility (native macOS zip creator supporting extended attributes & resource forks)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            
            var args = ["-c", "-k", "--sequesterRsrc"]
            for s in sources {
                args.append(s.path)
            }
            args.append(outURL.path)
            process.arguments = args
            
            do {
                try process.run()
                process.waitUntilExit()
                
                await MainActor.run {
                    self.isProcessing = false
                    if process.terminationStatus == 0 {
                        self.statusMessage = "Created \(outURL.lastPathComponent) successfully."
                    } else {
                        self.statusMessage = "Archiving process exited with error code \(process.terminationStatus)."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.statusMessage = "Archiving error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    public func extractZipArchive(zipURL: URL) {
        guard !isProcessing, let destDir = extractionDestination else { return }
        isProcessing = true
        statusMessage = "Extracting \(zipURL.lastPathComponent)..."
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // Path traversal safety check: create designated folder in destDir
            let folderName = zipURL.deletingPathExtension().lastPathComponent
            let targetExtractFolder = destDir.appendingPathComponent(folderName, isDirectory: true)
            
            try? FileManager.default.createDirectory(at: targetExtractFolder, withIntermediateDirectories: true)
            
            // Extract using /usr/bin/ditto -x -k (safe extraction)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", zipURL.path, targetExtractFolder.path]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                await MainActor.run {
                    self.isProcessing = false
                    if process.terminationStatus == 0 {
                        self.statusMessage = "Extracted to \(targetExtractFolder.lastPathComponent)"
                    } else {
                        self.statusMessage = "Extraction failed with code \(process.terminationStatus)."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.statusMessage = "Extraction error: \(error.localizedDescription)"
                }
            }
        }
    }
}
