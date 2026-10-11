//
//  SensorProvider.swift
//  Borno Pulse
//
//  Samples macOS hardware thermal and fan data using only publicly accessible APIs.
//
//  ──── macOS API Limitation Notes ────────────────────────────────────────────────────
//  • Direct CPU / GPU die temperature sensors (SMC T-keys) are not accessible from
//    sandboxed processes on macOS. They require a signed kernel extension or a
//    privileged XPC helper that is NOT bundled with this application.
//
//  • `ProcessInfo.thermalState` IS publicly available and correctly represents the
//    operating system's thermal management state. It is NOT a raw temperature in °C.
//
//  • Fan count and fan speed (RPM) may be readable from IORegistry on some Intel Macs
//    via public SMC properties; on Apple Silicon the SMC coprocessor manages the fan
//    curve internally and does not always expose RPM to user-space processes.
//
//  • Battery temperature is sourced from `AppleSmartBattery` IORegistry (BatteryProvider
//    → BatteryPowerService), NOT from this class. SensorMetrics.cpuTemperature and
//    SensorMetrics.gpuTemperature are separate fields that are left nil when unavailable.
//
//  • GPU temperature is not exposed by IOAccelerator in the public dictionary on any
//    Apple Silicon Mac. SensorMetrics.gpuTemperature is therefore always nil unless
//    an optional compatible third-party sensor library is present.
//  ────────────────────────────────────────────────────────────────────────────────────

import Foundation
import IOKit

public final class SensorProvider: @unchecked Sendable {
    private let lock = NSLock()

    public init() {}

    public func sample() -> SensorMetrics {
        lock.lock()
        defer { lock.unlock() }

        var metrics = SensorMetrics()

        // ── 1. Official macOS Thermal Pressure State (always available, zero sandbox restriction) ──
        let thermalState = ProcessInfo.processInfo.thermalState
        metrics.thermalState = thermalState
        metrics.isThrottling = (thermalState == .serious || thermalState == .critical)

        switch thermalState {
        case .nominal:
            metrics.thermalStateDescription = "Nominal (Normal Operating Temperatures)"
        case .fair:
            metrics.thermalStateDescription = "Fair (Elevated Thermal Load)"
        case .serious:
            metrics.thermalStateDescription = "Serious (Thermal Throttling Active)"
        case .critical:
            metrics.thermalStateDescription = "Critical (Maximum Thermal Throttling)"
        @unknown default:
            metrics.thermalStateDescription = "Unknown"
        }

        // ── 2. Optional hardware sensor query (fan RPM only; temperature gated by availability) ──
        readIORegistrySensors(&metrics)

        return metrics
    }

    // MARK: - IORegistry Sensor Query

    private func readIORegistrySensors(_ metrics: inout SensorMetrics) {
        // Attempt to open the AppleSMC service.
        let matching = IOServiceMatching("AppleSMC")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            markSensorsUnavailable(&metrics)
            return
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            markSensorsUnavailable(&metrics)
            return
        }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            markSensorsUnavailable(&metrics)
            return
        }

        // ── Fan speed ─────────────────────────────────────────────────────────────────────────
        // The public AppleSMC dictionary may expose FNum (fan count) and F0Ac/F1Ac (actual RPM).
        // These keys are model-dependent and are NOT guaranteed on Apple Silicon models.
        // If they are present, they are real hardware readings; otherwise fans state is unavailable.
        var fansRead: [FanInfo] = []

        if let fanCount = dict["FNum"] as? Int, fanCount > 0 {
            for i in 0..<fanCount {
                // Keys: F0Ac (Fan 0 actual speed), F1Ac, etc.
                let rpmKey = "F\(i)Ac"
                if let rawRPM = dict[rpmKey] as? Double, rawRPM > 0 {
                    // RPM values from SMC are stored as fp2e14 fixed-point;
                    // already decoded to Double by IOKit on most macOS versions.
                    let minKey = "F\(i)Mn"
                    let maxKey = "F\(i)Mx"
                    let minRPM = dict[minKey] as? Double ?? 0.0
                    let maxRPM = dict[maxKey] as? Double ?? 6000.0
                    fansRead.append(FanInfo(
                        id: i,
                        name: "Fan \(i + 1)",
                        speedRPM: rawRPM,
                        minRPM: minRPM,
                        maxRPM: maxRPM
                    ))
                } else if let rawRPM = dict[rpmKey] as? Int, rawRPM > 0 {
                    fansRead.append(FanInfo(id: i, name: "Fan \(i + 1)", speedRPM: Double(rawRPM)))
                }
            }
        } else if let fanCount = dict["FanCount"] as? Int, fanCount > 0 {
            // Alternate key used on some Intel models
            for i in 0..<fanCount {
                let rpmKey = "Fan\(i)Speed"
                if let rawRPM = dict[rpmKey] as? Double, rawRPM > 0 {
                    fansRead.append(FanInfo(id: i, name: "Fan \(i + 1)", speedRPM: rawRPM))
                } else if let rawRPM = dict[rpmKey] as? Int, rawRPM > 0 {
                    fansRead.append(FanInfo(id: i, name: "Fan \(i + 1)", speedRPM: Double(rawRPM)))
                }
            }
        }

        if !fansRead.isEmpty {
            metrics.fanSpeeds = fansRead
            metrics.fansState = .available
        } else {
            // No fan data was readable — this is normal for passively cooled models and Apple Silicon
            #if arch(arm64)
            metrics.fansState = .unavailable(reason: "Fan telemetry managed exclusively by Apple Silicon SMC coprocessor. Passively cooled models have no fans.")
            #else
            metrics.fansState = .unavailable(reason: "Fan speed sensor not accessible from this process. A privileged helper is required.")
            #endif
        }

        // ── CPU temperature ──────────────────────────────────────────────────────────────────
        // Temperature SMC keys (TC0P, TC0E, TCXC, etc.) require a signed kext / XPC helper
        // in a sandboxed Mac app. These keys are NOT present in the public IORegistry dict
        // returned by IORegistryEntryCreateCFProperties for AppleSMC.
        //
        // We explicitly set cpuTemperature = nil to represent "not available from public API."
        // This prevents the app from ever displaying a fabricated or wrong temperature value.
        metrics.cpuTemperature = nil

        // ── GPU temperature ──────────────────────────────────────────────────────────────────
        // IOAccelerator / IORegistry does not expose GPU die temperature in the public API
        // for Apple Silicon. This field is intentionally left nil.
        metrics.gpuTemperature = nil

        // Set availability states
        #if arch(arm64)
        metrics.temperatureState = .unavailable(
            reason: "CPU and GPU die temperature sensors are sandboxed on Apple Silicon. The OS Thermal State above reflects system health."
        )
        #else
        metrics.temperatureState = .unavailable(
            reason: "SMC temperature key access requires a privileged helper process."
        )
        #endif
    }

    private func markSensorsUnavailable(_ metrics: inout SensorMetrics) {
        metrics.cpuTemperature = nil
        metrics.gpuTemperature = nil
        metrics.fanSpeeds = []
        #if arch(arm64)
        metrics.temperatureState = .unavailable(reason: "Apple Silicon SMC service could not be opened by this sandboxed process.")
        metrics.fansState = .unavailable(reason: "Apple Silicon SMC coprocessor manages fan control; RPM not exposed to user-space.")
        #else
        metrics.temperatureState = .unavailable(reason: "SMC service inaccessible — privileged helper required.")
        metrics.fansState = .unavailable(reason: "SMC service inaccessible — privileged helper required.")
        #endif
    }
}
