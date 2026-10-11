//
//  StorageAnalyticsService.swift
//  Borno Pulse
//

import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
public final class StorageAnalyticsService: ObservableObject {
    public static let shared = StorageAnalyticsService()
    
    // MARK: - Volume Discovery
    @Published public var mountedVolumes: [StorageVolumeInfo] = []
    @Published public var selectedVolume: StorageVolumeInfo?
    @Published public var customDirectoryURL: URL?
    
    // MARK: - Scan State
    @Published public var scanMode: StorageScanMode = .quick
    @Published public var isScanning = false
    @Published public var scanProgressCount = 0
    @Published public var scannedFoldersCount = 0
    @Published public var totalScannedBytes: UInt64 = 0
    @Published public var lastScanTime: Date?
    @Published public var statusMessage: String = "Ready to scan"
    @Published public var inaccessibleLocations: [String] = []
    
    // MARK: - Results & Categorization
    @Published public var categorySizes: [StorageAnalyticsCategory: UInt64] = [:]
    @Published public var categoryFileCounts: [StorageAnalyticsCategory: Int] = [:]
    @Published public var largestFiles: [StorageAnalyticsItem] = []
    @Published public var largestFolders: [StorageAnalyticsItem] = []
    @Published public var allScannedItems: [StorageAnalyticsItem] = []
    
    // MARK: - Hierarchical Treemap State
    @Published public var rootNode: StorageAnalyticsNode?
    @Published public var currentDrillDownNode: StorageAnalyticsNode?
    @Published public var breadcrumbTrail: [StorageAnalyticsNode] = []
    @Published public var treemapTiles: [TreemapTile] = []
    @Published public var hoveredTile: TreemapTile?
    @Published public var isTreemapExpanded = false
    
    // MARK: - Filtering & Search
    @Published public var searchText: String = ""
    @Published public var selectedCategoryFilter: StorageAnalyticsCategory? = nil
    @Published public var minimumSizeFilter: MinimumSizeFilter = .all
    @Published public var itemTypeFilter: ItemTypeFilter = .all
    @Published public var displayLimit: DisplayLimit = .top25
    @Published public var sortColumn: StorageSortColumn = .size
    @Published public var sortAscending: Bool = false
    
    // MARK: - Cleanup Integration State
    @Published public var itemPendingCleanup: StorageAnalyticsItem?
    @Published public var cleanupSuccessMessage: String?
    
    private var scanTask: Task<Void, Never>?
    
    public enum MinimumSizeFilter: String, CaseIterable, Identifiable {
        case all = "All Sizes"
        case above100MB = "> 100 MB"
        case above500MB = "> 500 MB"
        case above1GB = "> 1 GB"
        
        public var id: String { rawValue }
        
        public var byteThreshold: UInt64 {
            switch self {
            case .all: return 0
            case .above100MB: return 100 * 1024 * 1024
            case .above500MB: return 500 * 1024 * 1024
            case .above1GB: return 1024 * 1024 * 1024
            }
        }
    }
    
    public enum ItemTypeFilter: String, CaseIterable, Identifiable {
        case all = "All Items"
        case files = "Files Only"
        case folders = "Folders Only"
        
        public var id: String { rawValue }
    }
    
    public enum DisplayLimit: String, CaseIterable, Identifiable {
        case top10 = "Top 10"
        case top25 = "Top 25"
        case top50 = "Top 50"
        case all = "All Items"
        
        public var id: String { rawValue }
        
        public var count: Int? {
            switch self {
            case .top10: return 10
            case .top25: return 25
            case .top50: return 50
            case .all: return nil
            }
        }
    }
    
    public enum StorageSortColumn: String, CaseIterable, Identifiable {
        case name = "Name"
        case type = "Type"
        case size = "Size"
        case percentage = "% of Total"
        case date = "Date Modified"
        
        public var id: String { rawValue }
    }
    
    public init() {
        refreshMountedVolumes()
    }
    
    // MARK: - Volume Discovery
    public func refreshMountedVolumes() {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsRemovableKey,
            .volumeIsRootFileSystemKey,
            .volumeTypeNameKey
        ]
        
        guard let volumeURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: resourceKeys,
            options: [.skipHiddenVolumes]
        ) else {
            return
        }
        
        var volumes: [StorageVolumeInfo] = []
        for url in volumeURLs {
            guard let vals = try? url.resourceValues(forKeys: Set(resourceKeys)) else { continue }
            let name = vals.volumeName ?? url.lastPathComponent
            let total = UInt64(vals.volumeTotalCapacity ?? 0)
            let available = UInt64(vals.volumeAvailableCapacityForImportantUsage ?? 0)
            let isRoot = vals.volumeIsRootFileSystem ?? false
            let isRemovable = vals.volumeIsRemovable ?? false
            let fsType = vals.volumeTypeName ?? "APFS"
            
            if total > 0 {
                let info = StorageVolumeInfo(
                    name: name,
                    mountURL: url,
                    totalCapacityBytes: total,
                    availableCapacityBytes: available,
                    isRootVolume: isRoot,
                    isRemovable: isRemovable,
                    fileSystemType: fsType
                )
                volumes.append(info)
            }
        }
        
        // Sort so root/boot volume is first
        volumes.sort { $0.isRootVolume && !$1.isRootVolume }
        self.mountedVolumes = volumes
        
        if self.selectedVolume == nil {
            self.selectedVolume = volumes.first
        }
    }
    
    public func selectCustomFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Analyze Folder"
        openPanel.title = "Select Folder to Analyze"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.customDirectoryURL = url
            startScan()
        }
    }
    
    public func resetToVolumeRoot() {
        self.customDirectoryURL = nil
        startScan()
    }
    
    // MARK: - Scanning Engine
    public func startScan() {
        guard !isScanning else { return }
        
        isScanning = true
        scanProgressCount = 0
        scannedFoldersCount = 0
        totalScannedBytes = 0
        inaccessibleLocations = []
        statusMessage = "Preparing scan..."
        
        let targetURL: URL
        if let custom = customDirectoryURL {
            targetURL = custom
        } else if let vol = selectedVolume {
            targetURL = vol.mountURL
        } else {
            targetURL = FileManager.default.homeDirectoryForCurrentUser
        }
        
        let mode = scanMode
        let isRootScan = (targetURL.path == "/")
        
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
            
            var scanLocations: [URL] = []
            
            if mode == .quick || isRootScan {
                // Focus on user-accessible heavy consumer locations
                let home = fileManager.homeDirectoryForCurrentUser
                scanLocations = [
                    home.appendingPathComponent("Downloads"),
                    home.appendingPathComponent("Documents"),
                    home.appendingPathComponent("Desktop"),
                    home.appendingPathComponent("Movies"),
                    home.appendingPathComponent("Pictures"),
                    home.appendingPathComponent("Music"),
                    home.appendingPathComponent("Library/Caches"),
                    home.appendingPathComponent("Library/Developer"),
                    home.appendingPathComponent("Applications")
                ].filter { fileManager.fileExists(atPath: $0.path) }
                
                // Also check /Applications if scanning main volume
                let sysApps = URL(fileURLWithPath: "/Applications")
                if fileManager.fileExists(atPath: sysApps.path) && !scanLocations.contains(sysApps) {
                    scanLocations.append(sysApps)
                }
            } else {
                scanLocations = [targetURL]
            }
            
            var catSizes: [StorageAnalyticsCategory: UInt64] = [:]
            var catCounts: [StorageAnalyticsCategory: Int] = [:]
            for cat in StorageAnalyticsCategory.allCases {
                catSizes[cat] = 0
                catCounts[cat] = 0
            }
            
            var topFiles: [StorageAnalyticsItem] = []
            var allItems: [StorageAnalyticsItem] = []
            var folderSizes: [String: (size: UInt64, url: URL, modDate: Date?)] = [:]
            var totalBytes: UInt64 = 0
            var fileCount = 0
            var folderCount = 0
            var warnings: [String] = []
            
            // Build root hierarchy node
            let root = StorageAnalyticsNode(
                url: targetURL,
                sizeBytes: 0,
                isDirectory: true,
                category: .other
            )
            
            for loc in scanLocations {
                if Task.isCancelled { break }
                
                guard let enumerator = fileManager.enumerator(
                    at: loc,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: [.skipsPackageDescendants, .skipsHiddenFiles],
                    errorHandler: { url, error in
                        warnings.append(url.lastPathComponent)
                        return true
                    }
                ) else {
                    warnings.append(loc.lastPathComponent)
                    continue
                }
                
                while let fileURL = enumerator.nextObject() as? URL {
                    if Task.isCancelled { break }
                    
                    guard let vals = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                        continue
                    }
                    
                    if vals.isSymbolicLink == true { continue }
                    
                    let isDir = vals.isDirectory ?? false
                    let isReg = vals.isRegularFile ?? false
                    let size = UInt64(vals.fileSize ?? 0)
                    let modDate = vals.contentModificationDate
                    
                    if isDir {
                        folderCount += 1
                        folderSizes[fileURL.path] = (size: 0, url: fileURL, modDate: modDate)
                    } else if isReg && size > 0 {
                        fileCount += 1
                        totalBytes += size
                        
                        let item = StorageAnalyticsItem(
                            url: fileURL,
                            sizeBytes: size,
                            isDirectory: false,
                            modificationDate: modDate
                        )
                        
                        let cat = item.category
                        catSizes[cat, default: 0] += size
                        catCounts[cat, default: 0] += 1
                        
                        // Accumulate folder parents
                        var parent = fileURL.deletingLastPathComponent().path
                        while parent.hasPrefix(loc.path) && parent != "/" {
                            if var fInfo = folderSizes[parent] {
                                fInfo.size += size
                                folderSizes[parent] = fInfo
                            } else {
                                folderSizes[parent] = (size: size, url: URL(fileURLWithPath: parent), modDate: nil)
                            }
                            parent = (parent as NSString).deletingLastPathComponent
                        }
                        
                        // Collect large files (> 50MB)
                        if size >= 50 * 1024 * 1024 {
                            topFiles.append(item)
                        }
                        
                        // Keep item in sample list (capped to avoid memory bloat)
                        if allItems.count < 1000 {
                            allItems.append(item)
                        }
                        
                        if fileCount % 400 == 0 {
                            let fc = fileCount
                            let dc = folderCount
                            let tb = totalBytes
                            await MainActor.run {
                                self.scanProgressCount = fc
                                self.scannedFoldersCount = dc
                                self.totalScannedBytes = tb
                                self.statusMessage = "Scanned \(fc) files (\(ByteCountFormatter.string(fromByteCount: Int64(tb), countStyle: .file)))..."
                            }
                        }
                    }
                }
            }
            
            // Format top folders
            let topFolders = folderSizes.values
                .filter { $0.size > 200 * 1024 * 1024 }
                .sorted { $0.size > $1.size }
                .prefix(20)
                .map {
                    StorageAnalyticsItem(
                        url: $0.url,
                        sizeBytes: $0.size,
                        isDirectory: true,
                        category: .other,
                        modificationDate: $0.modDate
                    )
                }
            
            // Sort top files descending
            topFiles.sort { $0.sizeBytes > $1.sizeBytes }
            let limitedTopFiles = Array(topFiles.prefix(50))
            
            // Add top folders to allItems for explorer
            allItems.append(contentsOf: topFolders)
            
            // Build visual treemap tree
            root.sizeBytes = totalBytes
            for (cat, sz) in catSizes where sz > 0 {
                let catNode = StorageAnalyticsNode(
                    url: targetURL.appendingPathComponent(cat.rawValue),
                    sizeBytes: sz,
                    isDirectory: true,
                    category: cat,
                    parent: root
                )
                root.children.append(catNode)
            }
            
            let finalWarnings = Array(warnings.prefix(15))
            
            await MainActor.run {
                self.categorySizes = catSizes
                self.categoryFileCounts = catCounts
                self.largestFiles = limitedTopFiles
                self.largestFolders = Array(topFolders)
                self.allScannedItems = allItems
                self.rootNode = root
                self.currentDrillDownNode = root
                self.breadcrumbTrail = [root]
                self.totalScannedBytes = totalBytes
                self.scanProgressCount = fileCount
                self.scannedFoldersCount = folderCount
                self.lastScanTime = Date()
                self.inaccessibleLocations = finalWarnings
                self.isScanning = false
                self.statusMessage = "Scan completed: \(fileCount) files (\(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)))."
                
                // Record snapshot if enabled
                if let vol = self.selectedVolume {
                    HistoricalStorageService.shared.recordSnapshot(
                        volumeName: vol.name,
                        totalCapacity: vol.totalCapacityBytes,
                        usedCapacity: vol.usedCapacityBytes,
                        scannedBytes: totalBytes,
                        scannedFileCount: fileCount
                    )
                }
                
                // Recompute treemap layout
                self.recomputeTreemap(bounds: CGRect(x: 0, y: 0, width: 800, height: 420))
            }
        }
    }
    
    public func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        statusMessage = "Scan cancelled."
    }
    
    // MARK: - Treemap Drill-Down & Navigation
    public func drillDown(to node: StorageAnalyticsNode) {
        currentDrillDownNode = node
        breadcrumbTrail.append(node)
        recomputeTreemap(bounds: CGRect(x: 0, y: 0, width: 800, height: 420))
    }
    
    public func navigateToBreadcrumb(at index: Int) {
        guard index >= 0 && index < breadcrumbTrail.count else { return }
        breadcrumbTrail = Array(breadcrumbTrail.prefix(index + 1))
        currentDrillDownNode = breadcrumbTrail.last
        recomputeTreemap(bounds: CGRect(x: 0, y: 0, width: 800, height: 420))
    }
    
    public func navigateUp() {
        if breadcrumbTrail.count > 1 {
            breadcrumbTrail.removeLast()
            currentDrillDownNode = breadcrumbTrail.last
            recomputeTreemap(bounds: CGRect(x: 0, y: 0, width: 800, height: 420))
        }
    }
    
    public func resetTreemapView() {
        if let root = rootNode {
            currentDrillDownNode = root
            breadcrumbTrail = [root]
            recomputeTreemap(bounds: CGRect(x: 0, y: 0, width: 800, height: 420))
        }
    }
    
    public func recomputeTreemap(bounds: CGRect) {
        guard let current = currentDrillDownNode else {
            self.treemapTiles = []
            return
        }
        
        let items: [TreemapLayoutEngine.LayoutItem]
        if current.children.isEmpty {
            // Leaf items
            items = [
                TreemapLayoutEngine.LayoutItem(
                    id: current.id.uuidString,
                    name: current.name,
                    size: current.sizeBytes,
                    category: current.category,
                    isDirectory: current.isDirectory,
                    nodeID: current.id
                )
            ]
        } else {
            items = current.children.map { child in
                TreemapLayoutEngine.LayoutItem(
                    id: child.id.uuidString,
                    name: child.name,
                    size: child.sizeBytes,
                    category: child.category,
                    isDirectory: child.isDirectory,
                    nodeID: child.id
                )
            }
        }
        
        self.treemapTiles = TreemapLayoutEngine.shared.layout(items: items, bounds: bounds)
    }
    
    // MARK: - Filtered Explorer Items
    public var filteredExplorerItems: [StorageAnalyticsItem] {
        var items = allScannedItems
        
        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter { $0.name.lowercased().contains(query) || $0.path.lowercased().contains(query) }
        }
        
        // Category filter
        if let cat = selectedCategoryFilter {
            items = items.filter { $0.category == cat }
        }
        
        // Minimum size filter
        let threshold = minimumSizeFilter.byteThreshold
        if threshold > 0 {
            items = items.filter { $0.sizeBytes >= threshold }
        }
        
        // Item type filter
        switch itemTypeFilter {
        case .all: break
        case .files: items = items.filter { !$0.isDirectory }
        case .folders: items = items.filter { $0.isDirectory }
        }
        
        // Sorting
        items.sort { a, b in
            let result: Bool
            switch sortColumn {
            case .name:
                result = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .type:
                result = a.category.rawValue < b.category.rawValue
            case .size, .percentage:
                result = a.sizeBytes < b.sizeBytes
            case .date:
                result = (a.modificationDate ?? .distantPast) < (b.modificationDate ?? .distantPast)
            }
            return sortAscending ? result : !result
        }
        
        // Display limit
        if let limit = displayLimit.count {
            return Array(items.prefix(limit))
        }
        return items
    }
    
    // MARK: - Actions
    public func revealInFinder(item: StorageAnalyticsItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    
    public func openFile(item: StorageAnalyticsItem) {
        NSWorkspace.shared.open(item.url)
    }
    
    public func copyPath(item: StorageAnalyticsItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
    }
    
    // MARK: - Cleanup Integration & Eligibility
    nonisolated public static func isEligibleForCleanup(item: StorageAnalyticsItem) -> Bool {
        let p = item.path
        if p.contains("/Library/Caches") ||
           p.contains("/Developer/Xcode/DerivedData") ||
           p.contains("/.build") ||
           p.contains("/tmp") {
            return true
        }
        return false
    }
    
    nonisolated public func isEligibleForCleanup(item: StorageAnalyticsItem) -> Bool {
        Self.isEligibleForCleanup(item: item)
    }
    
    nonisolated public static func cleanupExplanation(for item: StorageAnalyticsItem) -> String {
        let p = item.path
        if p.contains("/Library/Caches") {
            return "This item is an application cache. Deleting it will free disk space safely without affecting personal documents. The app will recreate any needed caches on its next launch."
        } else if p.contains("/Developer/Xcode/DerivedData") || p.contains("/.build") {
            return "This item contains Xcode intermediate build artifacts and indexed project files. Deleting it safely reclaims storage and forces Xcode to recompile on next build."
        } else if p.contains("/tmp") {
            return "This item is a temporary system workspace file eligible for removal."
        }
        return "This item is located in a standard user folder. Manual inspection is advised."
    }
    
    nonisolated public func cleanupExplanation(for item: StorageAnalyticsItem) -> String {
        Self.cleanupExplanation(for: item)
    }
    
    public func deleteEligibleItem(item: StorageAnalyticsItem) -> Bool {
        guard isEligibleForCleanup(item: item) else { return false }
        
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            
            // Recalculate local stats
            let removedBytes = item.sizeBytes
            if totalScannedBytes >= removedBytes {
                totalScannedBytes -= removedBytes
            }
            allScannedItems.removeAll { $0.path == item.path }
            largestFiles.removeAll { $0.path == item.path }
            largestFolders.removeAll { $0.path == item.path }
            
            cleanupSuccessMessage = "Moved \(item.name) to Trash. Reclaimed \(ByteCountFormatter.string(fromByteCount: Int64(removedBytes), countStyle: .file))."
            refreshMountedVolumes()
            return true
        } catch {
            cleanupSuccessMessage = "Failed removing item: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - CSV Export
    public func exportScanResultsCSV() {
        let items = filteredExplorerItems
        guard !items.isEmpty else { return }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Export Storage Analysis CSV"
        savePanel.nameFieldStringValue = "Storage_Analysis_\(Date().formatted(date: .numeric, time: .omitted)).csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        
        guard savePanel.runModal() == .OK, let outputURL = savePanel.url else { return }
        
        var csv = "Name,Type,Size (Bytes),Formatted Size,Path,Modification Date\n"
        for item in items {
            let cleanName = item.name.replacingOccurrences(of: "\"", with: "\"\"")
            let cleanPath = item.path.replacingOccurrences(of: "\"", with: "\"\"")
            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(item.sizeBytes), countStyle: .file)
            let dateStr = item.modificationDate?.description ?? ""
            
            csv += "\"\(cleanName)\",\"\(item.category.rawValue)\",\(item.sizeBytes),\"\(formattedSize)\",\"\(cleanPath)\",\"\(dateStr)\"\n"
        }
        
        try? csv.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}
