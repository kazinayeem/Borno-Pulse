//
//  BackupEngineService.swift
//  Borno Pulse
//

import AppKit
import Foundation

@MainActor
public final class BackupEngineService: ObservableObject {
    public static let shared = BackupEngineService()
    
    @Published public var profiles: [BackupProfile] = []
    @Published public var isRunning: Bool = false
    @Published public var currentProgress: Double = 0.0
    @Published public var currentStatusMessage: String = "Ready"
    @Published public var latestReport: BackupRunReport? = nil
    
    private var isCancelled: Bool = false
    
    private var profilesFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NaemSmartTool/Backup", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profiles.json")
    }
    
    private init() {
        loadProfiles()
        if profiles.isEmpty {
            // Seed a sample Documents profile
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
            if !docs.isEmpty && !downloads.isEmpty {
                profiles.append(BackupProfile(
                    name: "Personal Documents",
                    sourcePaths: [docs],
                    destinationPath: (downloads as NSString).appendingPathComponent("SmartTool_Backups"),
                    mode: .incremental,
                    verifyChecksums: true
                ))
            }
        }
    }
    
    // MARK: - Profile Management
    public func saveProfile(_ profile: BackupProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        persistProfiles()
    }
    
    public func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        persistProfiles()
    }
    
    private func persistProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: profilesFileURL, options: .atomic)
        }
    }
    
    private func loadProfiles() {
        guard let data = try? Data(contentsOf: profilesFileURL),
              let list = try? JSONDecoder().decode([BackupProfile].self, from: data) else { return }
        self.profiles = list
    }
    
    // MARK: - Execution Engine
    public func runBackup(profile: BackupProfile) async -> BackupRunReport {
        isRunning = true
        isCancelled = false
        currentProgress = 0.0
        currentStatusMessage = "Starting backup for '\(profile.name)'..."
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let fm = FileManager.default
        
        let destURL: URL
        let baseDest = URL(fileURLWithPath: profile.destinationPath)
        
        if profile.mode == .full {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let folderName = "\(profile.name)_\(df.string(from: Date()))"
            destURL = baseDest.appendingPathComponent(folderName, isDirectory: true)
        } else {
            destURL = baseDest
        }
        
        try? fm.createDirectory(at: destURL, withIntermediateDirectories: true)
        
        var considered = 0
        var copied = 0
        var skipped = 0
        var failed = 0
        var totalBytes: Int64 = 0
        var verificationPassed = true
        
        // Collect all source files
        var sourceFiles: [(src: URL, relativePath: String)] = []
        for srcPath in profile.sourcePaths {
            let srcURL = URL(fileURLWithPath: srcPath)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: srcURL.path, isDirectory: &isDir) else { continue }
            
            if isDir.boolValue {
                let enumerator = fm.enumerator(
                    at: srcURL,
                    includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey],
                    options: [.skipsPackageDescendants]
                )
                while let fileURL = enumerator?.nextObject() as? URL {
                    let rel = fileURL.path.replacingOccurrences(of: srcURL.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    if shouldExclude(filename: fileURL.lastPathComponent, exclusions: profile.exclusions) {
                        continue
                    }
                    sourceFiles.append((fileURL, "\(srcURL.lastPathComponent)/\(rel)"))
                }
            } else {
                sourceFiles.append((srcURL, srcURL.lastPathComponent))
            }
        }
        
        considered = sourceFiles.count
        
        for (idx, item) in sourceFiles.enumerated() {
            if isCancelled { break }
            currentProgress = Double(idx) / Double(max(1, considered))
            currentStatusMessage = "Copying (\(idx + 1)/\(considered)): \(item.relativePath)"
            
            let targetURL = destURL.appendingPathComponent(item.relativePath)
            let targetDir = targetURL.deletingLastPathComponent()
            try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
            
            do {
                let srcAttrs = try fm.attributesOfItem(atPath: item.src.path)
                let srcSize = srcAttrs[.size] as? Int64 ?? 0
                let srcMod = srcAttrs[.modificationDate] as? Date ?? Date()
                
                // Incremental check
                if profile.mode == .incremental && fm.fileExists(atPath: targetURL.path) {
                    if let targetAttrs = try? fm.attributesOfItem(atPath: targetURL.path),
                       let targetSize = targetAttrs[.size] as? Int64,
                       let targetMod = targetAttrs[.modificationDate] as? Date,
                       targetSize == srcSize && abs(targetMod.timeIntervalSince(srcMod)) < 2.0 {
                        skipped += 1
                        continue
                    }
                }
                
                // Replace or Copy
                if fm.fileExists(atPath: targetURL.path) {
                    try fm.removeItem(at: targetURL)
                }
                try fm.copyItem(at: item.src, to: targetURL)
                
                // Checksum verification
                if profile.verifyChecksums {
                    let srcHash = try FileHashCalculatorService.shared.computeHash(for: item.src, algorithm: .sha256)
                    let dstHash = try FileHashCalculatorService.shared.computeHash(for: targetURL, algorithm: .sha256)
                    if srcHash != dstHash {
                        verificationPassed = false
                    }
                }
                
                copied += 1
                totalBytes += srcSize
            } catch {
                failed += 1
            }
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        currentProgress = 1.0
        currentStatusMessage = "Backup completed for '\(profile.name)'."
        
        let report = BackupRunReport(
            profileName: profile.name,
            mode: profile.mode,
            filesConsidered: considered,
            filesCopied: copied,
            filesSkipped: skipped,
            filesFailed: failed,
            totalBytesCopied: totalBytes,
            durationSeconds: duration,
            verificationPassed: verificationPassed,
            destinationPath: destURL.path
        )
        
        // Update profile last run status
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx].lastRunDate = Date()
            profiles[idx].lastStatus = "Copied \(copied) files (\(Formatters.bytes(UInt64(totalBytes))))"
            persistProfiles()
        }
        
        self.latestReport = report
        self.isRunning = false
        return report
    }
    
    public func cancel() {
        isCancelled = true
        isRunning = false
        currentStatusMessage = "Backup cancelled by user."
    }
    
    private func shouldExclude(filename: String, exclusions: [String]) -> Bool {
        for pattern in exclusions {
            if filename == pattern || (pattern.hasPrefix("*") && filename.hasSuffix(String(pattern.dropFirst()))) {
                return true
            }
        }
        return false
    }
}
