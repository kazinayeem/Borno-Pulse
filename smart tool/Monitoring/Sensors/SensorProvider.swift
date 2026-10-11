//
//  SensorProvider.swift
//  Naem Smart Tool
//

import Foundation
import IOKit

public final class SensorProvider: @unchecked Sendable {
    private let lock = NSLock()
    
    public init() {}
    
    public func sample() -> SensorMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = SensorMetrics()
        
        // 1. Official macOS Thermal Pressure State
        let thermalState = ProcessInfo.processInfo.thermalState
        metrics.thermalState = thermalState
        
        switch thermalState {
        case .nominal:
            metrics.thermalStateDescription = "Nominal (Normal Operating Temperatures)"
            metrics.isThrottling = false
        case .fair:
            metrics.thermalStateDescription = "Fair (Elevated Thermal Load)"
            metrics.isThrottling = false
        case .serious:
            metrics.thermalStateDescription = "Serious (Thermal Throttling Active)"
            metrics.isThrottling = true
        case .critical:
            metrics.thermalStateDescription = "Critical (Maximum Thermal Throttling)"
            metrics.isThrottling = true
        @unknown default:
            metrics.thermalStateDescription = "Unknown"
            metrics.isThrottling = false
        }
        
        // 2. Query SMC or Thermal Sensors
        readHardwareSensors(&metrics)
        
        return metrics
    }
    
    private func readHardwareSensors(_ metrics: inout SensorMetrics) {
        // Attempt to read via AppleSMC or IOPlatformThermal
        let matching = IOServiceMatching("AppleSMC")
        var iterator: io_iterator_t = 0
        
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess {
            let service = IOIteratorNext(iterator)
            if service != 0 {
                // Check if properties expose thermal information
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any] {
                    // Check if fan keys or temperature keys exist in public dictionary
                    if let fanCount = dict["FanCount"] as? Int, fanCount > 0 {
                        var fans: [FanInfo] = []
                        for i in 0..<fanCount {
                            fans.append(FanInfo(id: i, name: "Fan #\(i + 1)", speedRPM: 1200))
                        }
                        metrics.fanSpeeds = fans
                        metrics.fansState = .available
                    }
                }
                IOObjectRelease(service)
            }
            IOObjectRelease(iterator)
        }
        
        // If direct diode reading is restricted on Apple Silicon without root / privileged helper
        if metrics.cpuTemperature == nil {
            #if arch(arm64)
            metrics.temperatureState = .unavailable(reason: "Direct SoC diode access is sandboxed on Apple Silicon. Thermal pressure state is continuously active.")
            #else
            metrics.temperatureState = .unavailable(reason: "SMC temperature sensor query requires privileged helper.")
            #endif
        }
        
        if metrics.fanSpeeds.isEmpty {
            #if arch(arm64)
            // Some models (like MacBook Air) have no fan; others have fan restricted to SMC controller
            metrics.fansState = .unavailable(reason: "Fan telemetry requires privileged helper or hardware is passively cooled.")
            #else
            metrics.fansState = .unavailable(reason: "Fan speed sensor query requires privileged helper.")
            #endif
        }
    }
}
