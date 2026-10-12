//
//  CPUProvider.swift
//  Borno Pulse
//

import Darwin
import Foundation

public final class CPUProvider: @unchecked Sendable {
    private var previousPerCoreTicks: [[natural_t]] = []
    private var previousHostTicks: [natural_t] = []
    private let lock = NSLock()
    
    public let modelName: String
    public let architecture: String
    public let physicalCores: Int
    public let logicalCores: Int
    
    public init() {
        self.logicalCores = ProcessInfo.processInfo.processorCount
        self.physicalCores = CPUProvider.queryPhysicalCores()
        self.modelName = CPUProvider.queryCPUBrand()
        #if arch(arm64)
        self.architecture = "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        self.architecture = "Intel (x86_64)"
        #else
        self.architecture = "Unknown"
        #endif
    }
    
    public func sample() -> CPUMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = CPUMetrics()
        metrics.physicalCoreCount = physicalCores
        metrics.logicalCoreCount = logicalCores
        metrics.modelName = modelName
        metrics.architecture = architecture
        
        // 1. Per-Core CPU load
        var numProcessors: natural_t = 0
        var processorInfo: processor_info_array_t?
        var numProcessorInfo: mach_msg_type_number_t = 0
        
        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numProcessors,
            &processorInfo,
            &numProcessorInfo
        )
        
        if kr == KERN_SUCCESS, let info = processorInfo {
            let cpuLoadInfo = info.withMemoryRebound(to: integer_t.self, capacity: Int(numProcessorInfo)) { $0 }
            var currentPerCoreTicks: [[natural_t]] = []
            var perCoreUsage: [Double] = []
            
            for i in 0..<Int(numProcessors) {
                let offset = i * Int(CPU_STATE_MAX)
                let user = natural_t(cpuLoadInfo[offset + Int(CPU_STATE_USER)])
                let system = natural_t(cpuLoadInfo[offset + Int(CPU_STATE_SYSTEM)])
                let idle = natural_t(cpuLoadInfo[offset + Int(CPU_STATE_IDLE)])
                let nice = natural_t(cpuLoadInfo[offset + Int(CPU_STATE_NICE)])
                
                let current = [user, system, idle, nice]
                currentPerCoreTicks.append(current)
                
                if i < previousPerCoreTicks.count {
                    let prev = previousPerCoreTicks[i]
                    let userDiff = Double(user - prev[0])
                    let sysDiff = Double(system - prev[1])
                    let idleDiff = Double(idle - prev[2])
                    let niceDiff = Double(nice - prev[3])
                    
                    let totalDiff = userDiff + sysDiff + idleDiff + niceDiff
                    if totalDiff > 0 {
                        let coreUsage = ((userDiff + sysDiff + niceDiff) / totalDiff) * 100.0
                        perCoreUsage.append(min(max(coreUsage, 0.0), 100.0))
                    } else {
                        perCoreUsage.append(0.0)
                    }
                } else {
                    perCoreUsage.append(0.0)
                }
            }
            
            self.previousPerCoreTicks = currentPerCoreTicks
            metrics.perCoreUsage = perCoreUsage
            
            // Deallocate mach memory
            let size = vm_size_t(numProcessorInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }
        
        // 2. Overall Host CPU load
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let hostKr = withUnsafeMutablePointer(to: &cpuLoad) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        
        if hostKr == KERN_SUCCESS {
            let user = cpuLoad.cpu_ticks.0
            let sys = cpuLoad.cpu_ticks.1
            let idle = cpuLoad.cpu_ticks.2
            let nice = cpuLoad.cpu_ticks.3
            let current = [user, sys, idle, nice]
            
            if !previousHostTicks.isEmpty {
                let userDiff = Double(user - previousHostTicks[0])
                let sysDiff = Double(sys - previousHostTicks[1])
                let idleDiff = Double(idle - previousHostTicks[2])
                let niceDiff = Double(nice - previousHostTicks[3])
                let totalDiff = userDiff + sysDiff + idleDiff + niceDiff
                
                if totalDiff > 0 {
                    metrics.userUsage = (userDiff / totalDiff) * 100.0
                    metrics.systemUsage = (sysDiff / totalDiff) * 100.0
                    metrics.idleUsage = (idleDiff / totalDiff) * 100.0
                    metrics.niceUsage = (niceDiff / totalDiff) * 100.0
                    metrics.totalUsage = min(max(metrics.userUsage + metrics.systemUsage + metrics.niceUsage, 0.0), 100.0)
                }
            }
            
            self.previousHostTicks = current
            metrics.state = .available
        } else {
            metrics.state = .unavailable(reason: "Mach host statistics error \(hostKr)")
        }
        
        return metrics
    }
    
    private static func queryPhysicalCores() -> Int {
        var ncpu: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.physicalcpu", &ncpu, &size, nil, 0) == 0 && ncpu > 0 {
            return Int(ncpu)
        }
        return ProcessInfo.processInfo.processorCount
    }
    
    private static func queryCPUBrand() -> String {
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var brand = [CChar](repeating: 0, count: size)
            if sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0) == 0 {
                let str = brand.withUnsafeBufferPointer { ptr -> String in
                    guard let base = ptr.baseAddress else { return "" }
                    return String(cString: base)
                }.trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty { return str }
            }
        }
        
        // Fallback to hw.model
        sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 {
            var model = [CChar](repeating: 0, count: size)
            if sysctlbyname("hw.model", &model, &size, nil, 0) == 0 {
                let str = model.withUnsafeBufferPointer { ptr -> String in
                    guard let base = ptr.baseAddress else { return "" }
                    return String(cString: base)
                }.trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty { return str }
            }
        }
        
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel Core Processor"
        #endif
    }
}
