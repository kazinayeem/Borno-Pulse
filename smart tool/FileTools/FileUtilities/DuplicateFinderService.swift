//
//  DuplicateFinderService.swift
//  Borno Pulse
//

import AppKit
import Combine
import CryptoKit
import Foundation

public struct DuplicateGroup: Identifiable, Sendable {
    public var id: String { hash }
    public var hash: String
    public var fileSize: UInt64
    public var files: [URL]
    
    public init(hash: String, fileSize: UInt64, files: [URL]) {
        self.hash = hash
        self.fileSize = fileSize
        self.files = files
    }
}

@MainActor
public final class DuplicateFinderService: ObservableObject {
    public static let shared = DuplicateFinderService()
    
    @Published public var targetDirectory: URL?
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var isScanning = false
    @Published public var currentProgress: Double = 0.0
    @Published public var scannedFileCount = 0
    @Published public var statusMessage: String = "Select a folder to scan for duplicates"
    
    private var scanTask: Task<Void, Never>?
    
    public init() {
        self.targetDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    public func selectTargetDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Choose Folder"
        openPanel.title = "Select Folder to Scan for Duplicates"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.targetDirectory = url
        }
    }
    
    public func startScan() {
        guard !isScanning, let dir = targetDirectory else { return }
        isScanning = true
        duplicateGroups.removeAll()
        scannedFileCount = 0
        currentProgress = 0.0
        statusMessage = "Enumerating files in \(dir.lastPathComponent)..."
        
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
            
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else {
                await MainActor.run {
                    self.isScanning = false
                    self.statusMessage = "Failed opening directory."
                }
                return
            }
            
            // Step 1: Bucket by exact size
            var sizeBuckets: [UInt64: [URL]] = [:]
            var count = 0
            
            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                guard let vals = try? fileURL.resourceValues(forKeys: resourceKeys),
                      vals.isRegularFile == true,
                      vals.isSymbolicLink != true,
                      let size = vals.fileSize, size > 1024 else { // Ignore 0-byte or tiny files
                    continue
                }
                
                sizeBuckets[UInt64(size), default: []].append(fileURL)
                count += 1
                if count % 200 == 0 {
                    let cur = count
                    await MainActor.run {
                        self.scannedFileCount = cur
                        self.statusMessage = "Discovered \(cur) files..."
                    }
                }
            }
            
            // Step 2: For candidates sharing the same size, compute SHA-256
            let candidateBuckets = sizeBuckets.filter { $0.value.count > 1 }
            var groups: [DuplicateGroup] = []
            let totalCandidates = Double(candidateBuckets.count)
            var processed = 0
            
            for (size, urls) in candidateBuckets {
                if Task.isCancelled { break }
                processed += 1
                let prog = Double(processed) / max(totalCandidates, 1)
                
                await MainActor.run {
                    self.currentProgress = prog
                    self.statusMessage = "Hashing matching files (\(processed)/\(candidateBuckets.count))..."
                }
                
                var hashBuckets: [String: [URL]] = [:]
                for url in urls {
                    if let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
                        let hashStr = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                        hashBuckets[hashStr, default: []].append(url)
                    }
                }
                
                for (h, matchingURLs) in hashBuckets where matchingURLs.count > 1 {
                    groups.append(DuplicateGroup(hash: h, fileSize: size, files: matchingURLs))
                }
            }
            
            await MainActor.run {
                self.duplicateGroups = groups
                self.isScanning = false
                self.currentProgress = 1.0
                self.statusMessage = "Found \(groups.count) duplicate group(s) across \(count) files."
            }
        }
    }
    
    public func cancel() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        statusMessage = "Duplicate scan cancelled"
    }
    
    public func deleteDuplicateFile(url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            // Update in-memory groups
            for i in 0..<duplicateGroups.count {
                duplicateGroups[i].files.removeAll { $0 == url }
            }
            duplicateGroups.removeAll { $0.files.count <= 1 }
            return true
        } catch {
            return false
        }
    }
}
