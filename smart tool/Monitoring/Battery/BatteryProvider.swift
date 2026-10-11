//
//  BatteryProvider.swift
//  Borno Pulse
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
            metrics.stateOfCharge = .acDesktop
            metrics.formattedTimeRemaining = "AC Connected (Desktop Mac)"
            metrics.estimateConfidence = .unavailable
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
            if let isCharged = desc[kIOPSIsChargedKey] as? Bool {
                metrics.isFullyCharged = isCharged
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
            if let voltage = desc[kIOPSVoltageKey] as? Int, voltage > 0 {
                metrics.voltageVolts = Double(voltage) / 1000.0
            }
            if let current = desc[kIOPSCurrentKey] as? Int {
                metrics.amperageAmps = Double(current) / 1000.0
            }
        }
        
        if foundBattery {
            // Read hardware telemetry and power calculations via BatteryPowerService
            let telemetry = BatteryPowerService.shared.queryHardwarePowerTelemetry(
                isPluggedIn: metrics.isPluggedIn,
                isCharging: metrics.isCharging
            )
            
            if let v = telemetry.voltageVolts { metrics.voltageVolts = v }
            if let a = telemetry.amperageAmps { metrics.amperageAmps = a }
            metrics.chargingWatts = telemetry.chargingWatts
            metrics.dischargingWatts = telemetry.dischargingWatts
            metrics.systemPowerWatts = telemetry.systemPowerWatts
            metrics.adapterInputWatts = telemetry.adapterInputWatts
            metrics.adapterRatedWatts = telemetry.adapterRatedWatts
            metrics.adapterName = telemetry.adapterName
            metrics.isMeasuredWattage = telemetry.isMeasured
            if let cycles = telemetry.cycleCount { metrics.cycleCount = cycles }
            if let health = telemetry.healthPercentage { metrics.healthPercentage = health }
            if let temp = telemetry.temperatureCelsius { metrics.registryTemperatureCelsius = temp }
            if let full = telemetry.isFullyCharged { metrics.isFullyCharged = full }
            
            // Effective battery wattage
            if let c = telemetry.chargingWatts {
                metrics.wattage = c
            } else if let d = telemetry.dischargingWatts {
                metrics.wattage = -d
            } else if let v = metrics.voltageVolts, let a = metrics.amperageAmps {
                metrics.wattage = v * a
            }
            
            // Enrich through dedicated estimation service
            let estimation = BatteryEstimationService.shared.processSample(
                hasBattery: true,
                percentage: metrics.percentage,
                isCharging: metrics.isCharging,
                isPluggedIn: metrics.isPluggedIn,
                timeToEmptyMinutes: metrics.timeToEmptyMinutes,
                timeToFullMinutes: metrics.timeToFullMinutes,
                voltageVolts: metrics.voltageVolts,
                amperageAmps: metrics.amperageAmps,
                wattage: metrics.wattage,
                temperatureCelsius: metrics.registryTemperatureCelsius
            )
            
            metrics.estimatedMinutes = estimation.estimatedMinutes
            metrics.estimateConfidence = estimation.confidence
            metrics.stateOfCharge = estimation.state
            metrics.ratePercentagePerHour = estimation.ratePerHour
            metrics.formattedTimeRemaining = estimation.formatted
            metrics.lastUpdated = Date()
            metrics.state = .available
        } else {
            metrics.hasBattery = false
            metrics.isPluggedIn = true
            metrics.powerSource = "AC Power Adapter"
            metrics.stateOfCharge = .acDesktop
            metrics.formattedTimeRemaining = "AC Connected (Desktop Mac)"
            metrics.estimateConfidence = .unavailable
            metrics.state = .unavailable(reason: "Desktop Mac (AC Powered)")
        }
        
        return metrics
    }
}
