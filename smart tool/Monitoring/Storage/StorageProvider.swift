//
//  StorageProvider.swift
//  Naem Smart Tool
//

import Foundation

public final class StorageProvider: @unchecked Sendable {
    private let lock = NSLock()
    
    public init() {}
    
    public func sample() -> StorageMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = StorageMetrics()
        var volumes: [StorageVolume] = []
        
        let resourceKeys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsInternalKey,
            .volumeIsRootFileSystemKey,
            .volumeLocalizedFormatDescriptionKey
        ]
        
        let fileManager = FileManager.default
        let mountedURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: resourceKeys,
            options: [.skipHiddenVolumes]
        ) ?? [URL(fileURLWithPath: "/")]
        
        for url in mountedURLs {
            guard let vals = try? url.resourceValues(forKeys: Set(resourceKeys)) else {
                continue
            }
            
            let name = vals.volumeName ?? (url.path == "/" ? "Macintosh HD" : url.lastPathComponent)
            let total = UInt64(vals.volumeTotalCapacity ?? 0)
            guard total > 0 else { continue }
            
            let available = UInt64(vals.volumeAvailableCapacity ?? 0)
            let importantAvail = UInt64(vals.volumeAvailableCapacityForImportantUsage ?? Int64(available))
            let purgeable = importantAvail > available ? (importantAvail - available) : 0
            let used = total > available ? (total - available) : 0
            let format = vals.volumeLocalizedFormatDescription ?? "APFS"
            let isSystem = vals.volumeIsRootFileSystem ?? (url.path == "/")
            
            let vol = StorageVolume(
                name: name,
                mountPoint: url.path,
                fileSystem: format,
                totalBytes: total,
                usedBytes: used,
                freeBytes: available,
                purgeableBytes: purgeable,
                isSystem: isSystem
            )
            volumes.append(vol)
        }
        
        if volumes.isEmpty {
            // Fallback for root
            let root = URL(fileURLWithPath: "/")
            if let vals = try? root.resourceValues(forKeys: Set(resourceKeys)) {
                let total = UInt64(vals.volumeTotalCapacity ?? 0)
                let available = UInt64(vals.volumeAvailableCapacity ?? 0)
                let used = total > available ? (total - available) : 0
                let rootVol = StorageVolume(
                    name: "Macintosh HD",
                    mountPoint: "/",
                    fileSystem: "APFS",
                    totalBytes: total,
                    usedBytes: used,
                    freeBytes: available,
                    purgeableBytes: 0,
                    isSystem: true
                )
                volumes.append(rootVol)
            }
        }
        
        metrics.volumes = volumes
        if let primary = volumes.first(where: { $0.isSystem }) ?? volumes.first {
            metrics.primaryVolume = primary
            metrics.totalCapacityBytes = primary.totalBytes
            metrics.usedCapacityBytes = primary.usedBytes
            metrics.availableCapacityBytes = primary.freeBytes
            metrics.purgeableBytes = primary.purgeableBytes
        }
        
        metrics.state = .available
        return metrics
    }
}
