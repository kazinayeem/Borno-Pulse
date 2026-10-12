//
//  NodeModulesScannerService.swift
//  Borno Pulse
//
//  Production-quality Node.js project discovery and safe node_modules cleanup engine.
//

import Foundation
import Combine

@MainActor
public final class NodeModulesScannerService: ObservableObject {
    public static let shared = NodeModulesScannerService()
    
    @Published public var discoveredProjects: [NodeProjectItem] = []
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var scanProgress: Double = 0.0
    @Published public var cleanProgress: Double = 0.0
    @Published public var currentStatusText: String = ""
    @Published public var lastReport: CleanerExecutionReport? = nil
    @Published public var selectedScanRoots: [URL] = []
    
    private var scanTask: Task<Void, Never>?
    private var cleanTask: Task<Void, Never>?
    
    private init() {
        setDefaultScanRoots()
    }
    
    public func setDefaultScanRoots() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var roots: [URL] = []
        
        let candidates = ["Projects", "Developer", "Workspace", "Documents", "Desktop"]
        for folder in candidates {
            let u = home.appendingPathComponent(folder, isDirectory: true)
            if FileManager.default.fileExists(atPath: u.path) {
                roots.append(u)
            }
        }
        
        if roots.isEmpty {
            roots.append(home)
        }
        self.selectedScanRoots = roots
    }
    
    public func addCustomScanRoot(_ url: URL) {
        if !selectedScanRoots.contains(where: { $0.path == url.path }) {
            selectedScanRoots.append(url)
        }
    }
    
    public func removeScanRoot(_ url: URL) {
        selectedScanRoots.removeAll(where: { $0.path == url.path })
    }
    
    // MARK: - Scan
    public func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0
        currentStatusText = "Initializing Node.js project scanner..."
        
        let rootsToScan = selectedScanRoots
        
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            var foundProjects: [NodeProjectItem] = []
            let totalRoots = max(1, Double(rootsToScan.count))
            
            for (index, rootURL) in rootsToScan.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.currentStatusText = "Scanning \(rootURL.lastPathComponent)..."
                    self.scanProgress = Double(index) / totalRoots
                }
                
                let results = Self.scanDirectoryForNodeModules(rootURL: rootURL)
                foundProjects.append(contentsOf: results)
            }
            
            // Deduplicate by path
            var uniqueMap: [String: NodeProjectItem] = [:]
            for p in foundProjects {
                uniqueMap[p.nodeModulesPath] = p
            }
            let sorted = Array(uniqueMap.values).sorted(by: { $0.sizeBytes > $1.sizeBytes })
            
            await MainActor.run {
                self.discoveredProjects = sorted
                self.isScanning = false
                self.scanProgress = 1.0
                let totalSize = sorted.reduce(0) { $0 + $1.sizeBytes }
                self.currentStatusText = "Found \(sorted.count) Node.js projects (\(Formatters.bytes(totalSize)))."
            }
        }
    }
    
    public func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentStatusText = "Scanning cancelled."
    }
    
    // MARK: - Directory Traversal (Nonisolated Worker)
    public nonisolated static func scanDirectoryForNodeModules(rootURL: URL) -> [NodeProjectItem] {
        var results: [NodeProjectItem] = []
        let fileManager = FileManager.default
        
        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey,
            .nameKey
        ]
        
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        
        var visitedPaths = Set<String>()
        
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                continue
            }
            
            // Never follow symlink loops
            if values.isSymbolicLink ?? false {
                enumerator.skipDescendants()
                continue
            }
            
            guard values.isDirectory ?? false else { continue }
            
            let name = fileURL.lastPathComponent
            
            // Avoid deep scanning into standard non-dev system directories
            if name == "Library" || name == ".Trash" || name == "Applications" {
                enumerator.skipDescendants()
                continue
            }
            
            // Check if this is a node_modules directory
            if name == "node_modules" {
                // CRITICAL: Do NOT recurse into nested node_modules (avoids double-counting and loops)
                enumerator.skipDescendants()
                
                let nodeModulesPath = fileURL.path
                if visitedPaths.contains(nodeModulesPath) { continue }
                visitedPaths.insert(nodeModulesPath)
                
                let projectURL = fileURL.deletingLastPathComponent()
                let projectPath = projectURL.path
                let projectName = projectURL.lastPathComponent
                
                // Inspect parent project
                let hasPackageJson = fileManager.fileExists(atPath: projectURL.appendingPathComponent("package.json").path)
                let isGit = fileManager.fileExists(atPath: projectURL.appendingPathComponent(".git").path)
                
                // Lockfile detection
                var lockfile: String? = nil
                var pkgMgr: NodePackageManager = .npm
                
                if fileManager.fileExists(atPath: projectURL.appendingPathComponent("pnpm-lock.yaml").path) {
                    lockfile = "pnpm-lock.yaml"
                    pkgMgr = .pnpm
                } else if fileManager.fileExists(atPath: projectURL.appendingPathComponent("yarn.lock").path) {
                    lockfile = "yarn.lock"
                    pkgMgr = .yarn
                } else if fileManager.fileExists(atPath: projectURL.appendingPathComponent("bun.lockb").path) {
                    lockfile = "bun.lockb"
                    pkgMgr = .bun
                } else if fileManager.fileExists(atPath: projectURL.appendingPathComponent("bun.lock").path) {
                    lockfile = "bun.lock"
                    pkgMgr = .bun
                } else if fileManager.fileExists(atPath: projectURL.appendingPathComponent("package-lock.json").path) {
                    lockfile = "package-lock.json"
                    pkgMgr = .npm
                }
                
                // Monorepo detection
                let isMonorepo = fileManager.fileExists(atPath: projectURL.appendingPathComponent("pnpm-workspace.yaml").path)
                    || fileManager.fileExists(atPath: projectURL.appendingPathComponent("lerna.json").path)
                    || hasWorkspacesField(packageJsonURL: projectURL.appendingPathComponent("package.json"))
                
                // Measure size
                let (size, count, modDate) = calculateDirectoryMetrics(url: fileURL)
                
                // Active check: modified within past 7 days
                let isRecent: Bool
                if let mod = modDate {
                    isRecent = Date().timeIntervalSince(mod) < (7 * 86400)
                } else {
                    isRecent = false
                }
                
                results.append(NodeProjectItem(
                    projectPath: projectPath,
                    projectName: projectName,
                    nodeModulesPath: nodeModulesPath,
                    sizeBytes: size,
                    fileCount: count,
                    lastModified: modDate,
                    isGitRepo: isGit,
                    hasPackageJson: hasPackageJson,
                    packageManager: pkgMgr,
                    lockfileName: lockfile,
                    isMonorepo: isMonorepo,
                    isActivelyUsed: isRecent,
                    isSelected: false
                ))
            }
        }
        
        return results
    }
    
    private nonisolated static func hasWorkspacesField(packageJsonURL: URL) -> Bool {
        guard let data = try? Data(contentsOf: packageJsonURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return json["workspaces"] != nil
    }
    
    public nonisolated static func calculateDirectoryMetrics(url: URL) -> (sizeBytes: UInt64, fileCount: Int, lastModified: Date?) {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0
        var totalCount = 0
        var latestMod: Date? = nil
        
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) else {
            return (0, 0, nil)
        }
        
        while let itemURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            guard let vals = try? itemURL.resourceValues(forKeys: keys) else { continue }
            
            if vals.isRegularFile ?? false {
                let s = UInt64(vals.fileSize ?? 0)
                totalSize += s
                totalCount += 1
            }
            
            if let d = vals.contentModificationDate {
                if latestMod == nil || d > latestMod! {
                    latestMod = d
                }
            }
        }
        
        return (totalSize, totalCount, latestMod)
    }
    
    // MARK: - Selection Controls
    public func selectAll() {
        for i in 0..<discoveredProjects.count {
            discoveredProjects[i].isSelected = true
        }
    }
    
    public func deselectAll() {
        for i in 0..<discoveredProjects.count {
            discoveredProjects[i].isSelected = false
        }
    }
    
    public func toggleSelection(nodeModulesPath: String) {
        if let idx = discoveredProjects.firstIndex(where: { $0.nodeModulesPath == nodeModulesPath }) {
            discoveredProjects[idx].isSelected.toggle()
        }
    }
    
    // MARK: - Safe Deletion
    public func deleteSelectedNodeModules() {
        guard !isCleaning else { return }
        isCleaning = true
        cleanProgress = 0.0
        currentStatusText = "Removing selected node_modules directories..."
        
        let startTime = Date()
        let itemsToDelete = discoveredProjects.filter { $0.isSelected }
        
        cleanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            var freed: UInt64 = 0
            var deletedCount = 0
            var failCount = 0
            var errors: [String] = []
            
            let total = Double(max(1, itemsToDelete.count))
            
            for (idx, project) in itemsToDelete.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.currentStatusText = "Cleaning \(project.projectName)/node_modules..."
                    self.cleanProgress = Double(idx) / total
                }
                
                // SAFETY INVARIANTS:
                // 1. Must end with "node_modules"
                // 2. Must not be root "/" or user home
                let path = project.nodeModulesPath
                guard path.hasSuffix("node_modules"), path.count > 15 else {
                    failCount += 1
                    errors.append("Safety check rejected path: \(path)")
                    continue
                }
                
                do {
                    if fileManager.fileExists(atPath: path) {
                        try fileManager.removeItem(atPath: path)
                        freed += project.sizeBytes
                        deletedCount += 1
                    }
                } catch {
                    failCount += 1
                    errors.append("Failed removing \(project.projectName): \(error.localizedDescription)")
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let report = CleanerExecutionReport(
                bytesFreed: freed,
                itemsRemoved: deletedCount,
                failuresCount: failCount,
                errors: errors,
                durationSeconds: duration
            )
            
            await MainActor.run {
                self.lastReport = report
                self.isCleaning = false
                self.cleanProgress = 1.0
                self.currentStatusText = "Cleaned \(deletedCount) node_modules directories (\(Formatters.bytes(freed)) recovered)."
                
                // Remove deleted items from discovered list
                self.discoveredProjects.removeAll(where: { p in
                    itemsToDelete.contains(where: { $0.nodeModulesPath == p.nodeModulesPath })
                })
            }
        }
    }
}
