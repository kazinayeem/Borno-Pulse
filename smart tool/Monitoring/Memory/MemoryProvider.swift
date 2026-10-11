//
//  MemoryProvider.swift
//  Borno Pulse
//

import Darwin
import Foundation

public final class MemoryProvider: @unchecked Sendable {
    private let totalPhysicalMemory: UInt64
    private let pageSize: UInt64
    private let lock = NSLock()
    
    public init() {
        self.totalPhysicalMemory = ProcessInfo.processInfo.physicalMemory
        self.pageSize = UInt64(getpagesize())
    }
    
    public func sample() -> MemoryMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = MemoryMetrics()
        metrics.totalBytes = totalPhysicalMemory
        
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let kr = withUnsafeMutablePointer(to: &vmStat) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        
        if kr == KERN_SUCCESS {
            let free = UInt64(vmStat.free_count) * pageSize
            let active = UInt64(vmStat.active_count) * pageSize
            let inactive = UInt64(vmStat.inactive_count) * pageSize
            let wired = UInt64(vmStat.wire_count) * pageSize
            let compressed = UInt64(vmStat.compressor_page_count) * pageSize
            
            // On macOS: Used memory = App Memory (active + inactive) + Wired + Compressed
            // Free + Inactive often acts as available, but purely available = free + inactive
            let used = active + wired + compressed
            let available = totalPhysicalMemory > used ? (totalPhysicalMemory - used) : free
            
            metrics.freeBytes = free
            metrics.activeBytes = active
            metrics.inactiveBytes = inactive
            metrics.wiredBytes = wired
            metrics.compressedBytes = compressed
            metrics.usedBytes = used
            metrics.availableBytes = available
            
            // Calculate memory pressure level
            // Based on ratio of (free + inactive) to total, or compressed ratio
            let availableRatio = Double(free + inactive) / Double(totalPhysicalMemory)
            if availableRatio < 0.08 || Double(compressed) / Double(totalPhysicalMemory) > 0.45 {
                metrics.pressureLevel = .critical
                metrics.pressurePercentage = 95.0
            } else if availableRatio < 0.20 || Double(compressed) / Double(totalPhysicalMemory) > 0.25 {
                metrics.pressureLevel = .warning
                metrics.pressurePercentage = 70.0
            } else {
                metrics.pressureLevel = .normal
                metrics.pressurePercentage = max(15.0, (1.0 - availableRatio) * 60.0)
            }
            
            metrics.state = .available
        } else {
            metrics.state = .unavailable(reason: "Failed to read host_statistics64 (\(kr))")
        }
        
        // Query swap usage
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0) == 0 {
            metrics.swapTotalBytes = UInt64(swapUsage.xsu_total)
            metrics.swapUsedBytes = UInt64(swapUsage.xsu_used)
        }
        
        return metrics
    }
}
