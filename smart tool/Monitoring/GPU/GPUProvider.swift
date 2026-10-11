//
//  GPUProvider.swift
//  Borno Pulse
//

import Foundation
import Metal
import IOKit

public final class GPUProvider: @unchecked Sendable {
    private let primaryDevice: MTLDevice?
    private let lock = NSLock()
    
    public init() {
        self.primaryDevice = MTLCreateSystemDefaultDevice()
    }
    
    public func sample() -> GPUMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = GPUMetrics()
        
        if let device = primaryDevice {
            metrics.deviceName = device.name
            metrics.hasUnifiedMemory = device.hasUnifiedMemory
            metrics.isLowPower = device.isLowPower
            metrics.recommendedMaxWorkingSetSize = device.recommendedMaxWorkingSetSize
            metrics.maxBufferLength = UInt64(device.maxBufferLength)
            metrics.registryID = device.registryID
            metrics.state = .available
        } else {
            metrics.state = .unavailable(reason: "No Metal-compatible GPU found")
        }
        
        // Check Apple Neural Engine
        #if arch(arm64)
        metrics.neuralEngineAvailable = true
        metrics.neuralEngineDescription = "Apple Neural Engine (16-core NPU, Unified Memory)"
        #else
        metrics.neuralEngineAvailable = false
        metrics.neuralEngineDescription = "Not present on Intel architecture"
        #endif
        
        // Query IOKit IOAccelerator for hardware utilization
        queryIOAcceleratorStats(&metrics)
        
        return metrics
    }
    
    private func queryIOAcceleratorStats(_ metrics: inout GPUMetrics) {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return
        }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let p = props?.takeRetainedValue() as? [String: Any] {
                
                if let stats = p["PerformanceStatistics"] as? [String: Any] {
                    if let devUtil = stats["Device Utilization %"] as? NSNumber {
                        metrics.deviceUtilization = devUtil.doubleValue
                    }
                    if let rendUtil = stats["Renderer Utilization %"] as? NSNumber {
                        metrics.rendererUtilization = rendUtil.doubleValue
                    }
                    if let tilerUtil = stats["Tiler Utilization %"] as? NSNumber {
                        metrics.tilerUtilization = tilerUtil.doubleValue
                    }
                    if let inUse = stats["In use system memory"] as? NSNumber {
                        metrics.inUseMemoryBytes = inUse.uint64Value
                    }
                    if let alloc = stats["Alloc system memory"] as? NSNumber {
                        metrics.allocatedMemoryBytes = alloc.uint64Value
                    }
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
    }
}
