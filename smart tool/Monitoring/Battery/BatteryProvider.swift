//
//  BatteryProvider.swift
//  Naem Smart Tool
//

import Foundation
import IOKit.ps

public final class BatteryProvider: @unchecked Sendable {
    private let lock = NSLock()
    
    public init() {}
    
    public func sample() -> BatteryMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = BatteryMetrics()
        
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            metrics.hasBattery = false
            metrics.isPluggedIn = true
            metrics.powerSource = "AC Power Adapter"
            metrics.state = .unavailable(reason: "Desktop Mac without internal battery")
            return metrics
        }
        
        var foundBattery = false
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            let isPresent = desc[kIOPSIsPresentKey] as? Bool ?? true
            guard isPresent else { continue }
            
            foundBattery = true
            metrics.hasBattery = true
            
            if let cap = desc[kIOPSCurrentCapacityKey] as? Int {
                metrics.percentage = cap
            }
            if let isCharging = desc[kIOPSIsChargingKey] as? Bool {
                metrics.isCharging = isCharging
            }
            if let powerState = desc[kIOPSPowerSourceStateKey] as? String {
                metrics.isPluggedIn = (powerState == kIOPSACPowerValue)
                metrics.powerSource = metrics.isPluggedIn ? "Power Adapter" : "Battery"
            }
            if let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int, timeToEmpty > 0 {
                metrics.timeToEmptyMinutes = timeToEmpty
            }
            if let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int, timeToFull > 0 {
                metrics.timeToFullMinutes = timeToFull
            }
        }
        
        if foundBattery {
            // Read hardware cycle count via AppleSmartBattery
            queryAppleSmartBattery(&metrics)
            metrics.state = .available
        } else {
            metrics.hasBattery = false
            metrics.isPluggedIn = true
            metrics.powerSource = "AC Power Adapter"
            metrics.state = .unavailable(reason: "Desktop Mac (AC Powered)")
        }
        
        return metrics
    }
    
    private func queryAppleSmartBattery(_ metrics: inout BatteryMetrics) {
        let matching = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess {
            let service = IOIteratorNext(iterator)
            if service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any] {
                    if let cycles = dict["CycleCount"] as? Int {
                        metrics.cycleCount = cycles
                    }
                    if let maxCap = dict["MaxCapacity"] as? Int, maxCap > 0 {
                        metrics.healthPercentage = min(maxCap, 100)
                    }
                }
                IOObjectRelease(service)
            }
            IOObjectRelease(iterator)
        }
    }
}
