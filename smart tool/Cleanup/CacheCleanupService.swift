//
//  CacheCleanupService.swift
//  Borno Pulse
//

import Combine
import Foundation

@MainActor
public final class CacheCleanupService: ObservableObject {
    public static let shared = CacheCleanupService()
    
    @Published public var categories: [CleanupCategory] = []
    @Published public var isScanning = false
    @Published public var isCleaning = false
    @Published public var scanProgress: Double = 0.0
    @Published public var cleanProgress: Double = 0.0
    @Published public var lastResult: CleanupResult? = nil
    @Published public var currentActionText: String = ""
    
    private var scanTask: Task<Void, Never>?
    private var cleanTask: Task<Void, Never>?
    
    private init() {
        setupInitialCategories()
    }
    
    public func setupInitialCategories() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        let initialList: [(CleanupCategoryType, URL)] = [
            (.userCaches, home.appendingPathComponent("Library/Caches", isDirectory: true)),
            (.tempFiles, URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)),
            (.diagnosticLogs, home.appendingPathComponent("Library/Logs", isDirectory: true)),
            (.xcodeDerivedData, home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)),
            (.trash, home.appendingPathComponent(".Trash", isDirectory: true))
        ]
        
        self.categories = initialList.map { type, url in
            CleanupCategory(
                type: type,
                path: url.path,
                estimatedSizeBytes: 0,
                fileCount: 0,
                isSelected: type.defaultSelected,
                files: []
            )
        }
    }
    
    public func scanAll() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0
        currentActionText = "Scanning cache directories..."
        
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            var updatedCategories: [CleanupCategory] = []
            let initial = await self.categories
            let total = Double(initial.count)
            
            for (index, cat) in initial.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.currentActionText = "Scanning \(cat.title)..."
                    self.scanProgress = Double(index) / total
                }
                
                let scannedCat = self.scanDirectory(cat: cat)
                updatedCategories.append(scannedCat)
            }
            
            await MainActor.run {
                self.categories = updatedCategories
                self.isScanning = false
                self.scanProgress = 1.0
                self.currentActionText = "Scan completed."
            }
        }
    }
    
    public func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentActionText = "Scan cancelled."
    }
    
    private nonisolated func scanDirectory(cat: CleanupCategory) -> CleanupCategory {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: cat.path, isDirectory: true)
        
        guard fileManager.fileExists(atPath: cat.path) else {
            return cat
        }
        
        var files: [CleanupFileItem] = []
        var totalSize: UInt64 = 0
        
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isDirectoryKey]
        
        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            var counter = 0
            while let fileURL = enumerator.nextObject() as? URL {
                if counter > 500 { // Limit individual file items per category to protect memory
                    break
                }
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                    continue
                }
                
                let isRegular = resourceValues.isRegularFile ?? false
                let size = UInt64(resourceValues.fileSize ?? 0)
                let modDate = resourceValues.contentModificationDate
                
                if isRegular && size > 0 {
                    totalSize += size
                    files.append(
                        CleanupFileItem(
                            path: fileURL.path,
                            name: fileURL.lastPathComponent,
                            sizeBytes: size,
                            modifiedDate: modDate,
                            isSafe: cat.type != .trash
                        )
                    )
                    counter += 1
                }
            }
        }
        
        var result = cat
        result.estimatedSizeBytes = totalSize
        result.fileCount = files.count
        result.files = files
        return result
    }
    
    public func selectAllSafe() {
        for i in 0..<categories.count {
            categories[i].isSelected = (categories[i].type != .trash)
        }
    }
    
    public func deselectAll() {
        for i in 0..<categories.count {
            categories[i].isSelected = false
        }
    }
    
    public func toggleCategory(id: CleanupCategoryType) {
        if let index = categories.firstIndex(where: { $0.id == id }) {
            categories[index].isSelected.toggle()
        }
    }
    
    public func executeCleanup(dryRun: Bool) {
        guard !isCleaning else { return }
        isCleaning = true
        cleanProgress = 0.0
        currentActionText = dryRun ? "Simulating cleanup (dry run)..." : "Cleaning selected items..."
        
        cleanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let selectedCategories = await self.categories.filter { $0.isSelected }
            var totalFreed: UInt64 = 0
            var deletedCount = 0
            var failedCount = 0
            var errors: [String] = []
            
            let fileManager = FileManager.default
            
            for cat in selectedCategories {
                for fileItem in cat.files {
                    if Task.isCancelled { break }
                    
                    if dryRun {
                        totalFreed += fileItem.sizeBytes
                        deletedCount += 1
                    } else {
                        do {
                            // Safe check: verify file still exists and is in allowed path
                            if fileManager.fileExists(atPath: fileItem.path) {
                                try fileManager.removeItem(atPath: fileItem.path)
                                totalFreed += fileItem.sizeBytes
                                deletedCount += 1
                            }
                        } catch {
                            failedCount += 1
                            errors.append("Failed removing \(fileItem.name): \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            let finalResult = CleanupResult(
                totalFreedBytes: totalFreed,
                deletedCount: deletedCount,
                failedCount: failedCount,
                isDryRun: dryRun,
                errors: errors
            )
            
            await MainActor.run {
                self.lastResult = finalResult
                self.isCleaning = false
                self.cleanProgress = 1.0
                self.currentActionText = dryRun
                    ? "Dry run complete: \(Formatters.bytes(totalFreed)) previewed."
                    : "Clean complete: \(Formatters.bytes(totalFreed)) reclaimed."
                
                // If live clean was executed, refresh scanned state
                if !dryRun {
                    self.scanAll()
                }
            }
        }
    }
    
    public func cancelClean() {
        cleanTask?.cancel()
        cleanTask = nil
        isCleaning = false
        currentActionText = "Cleanup cancelled."
    }
}
