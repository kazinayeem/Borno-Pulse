//
//  StorageAnalyzerService.swift
//  Borno Pulse
//

import AppKit
import Combine
import Foundation

@MainActor
public final class StorageAnalyzerService: ObservableObject {
    public static let shared = StorageAnalyzerService()
    
    @Published public var selectedDirectory: URL
    @Published public var isScanning = false
    @Published public var scanProgressCount: Int = 0
    @Published public var statusMessage: String = "Ready to scan"
    
    // Results
    @Published public var categorySizes: [StorageCategory: UInt64] = [:]
    @Published public var largeFiles: [StorageItem] = []
    @Published public var totalScannedBytes: UInt64 = 0
    @Published public var totalScannedFiles: Int = 0
    
    // Filter & Sort
    @Published public var searchText: String = ""
    @Published public var selectedCategoryFilter: StorageCategory? = nil
    
    private var scanTask: Task<Void, Never>?
    
    public init() {
        self.selectedDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }
    
    public func selectCustomDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Choose Folder"
        openPanel.title = "Select Folder to Analyze"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.selectedDirectory = url
            startScan()
        }
    }
    
    public func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgressCount = 0
        totalScannedBytes = 0
        totalScannedFiles = 0
        categorySizes = [:]
        largeFiles = []
        statusMessage = "Scanning \(selectedDirectory.lastPathComponent)..."
        
        let targetURL = selectedDirectory
        
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            let resourceKeys: Set<URLResourceKey> = [
                .fileSizeKey,
                .isRegularFileKey,
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .contentModificationDateKey
            ]
            
            guard let enumerator = fileManager.enumerator(
                at: targetURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsPackageDescendants]
            ) else {
                await MainActor.run {
                    self.isScanning = false
                    self.statusMessage = "Unable to access folder."
                }
                return
            }
            
            var catSizes: [StorageCategory: UInt64] = [:]
            for cat in StorageCategory.allCases {
                catSizes[cat] = 0
            }
            var topFiles: [StorageItem] = []
            var totalBytes: UInt64 = 0
            var count = 0
            
            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                
                guard let vals = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                    continue
                }
                
                // Skip symlinks to avoid recursion loops
                if vals.isSymbolicLink == true { continue }
                
                let isRegular = vals.isRegularFile ?? false
                let size = UInt64(vals.fileSize ?? 0)
                let modDate = vals.contentModificationDate
                
                if isRegular && size > 0 {
                    let item = StorageItem(url: fileURL, sizeBytes: size, isDirectory: false, modificationDate: modDate)
                    let cat = item.category
                    catSizes[cat, default: 0] += size
                    totalBytes += size
                    count += 1
                    
                    // Collect large files (e.g. > 10MB)
                    if size > 10 * 1024 * 1024 {
                        topFiles.append(item)
                    }
                    
                    if count % 250 == 0 {
                        let currentCount = count
                        let currentBytes = totalBytes
                        await MainActor.run {
                            self.scanProgressCount = currentCount
                            self.totalScannedBytes = currentBytes
                        }
                    }
                }
            }
            
            // Sort top files descending
            topFiles.sort { $0.sizeBytes > $1.sizeBytes }
            let limitedTopFiles = Array(topFiles.prefix(100))
            
            await MainActor.run {
                self.categorySizes = catSizes
                self.largeFiles = limitedTopFiles
                self.totalScannedBytes = totalBytes
                self.totalScannedFiles = count
                self.isScanning = false
                self.statusMessage = "Found \(count) files (\(Formatters.bytes(totalBytes)))."
            }
        }
    }
    
    public func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        statusMessage = "Scan cancelled."
    }
    
    public func revealInFinder(item: StorageItem) {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }
}
