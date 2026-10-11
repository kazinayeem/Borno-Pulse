//
//  SensorProvider.swift
//  Borno Pulse
//
//  Single entry point for thermal telemetry. Polls the hardware readers, classifies every
//  value by the component it belongs to, and produces a `SensorMetrics` snapshot.
//
//  Sources, in order of preference per component:
//  1. IOHID event system services whose system-provided name identifies the component
//     (e.g. "gas gauge battery", "NAND CH0 temp", "pACC MTR Temp Sensor").
//  2. SMC keys identified by the naming convention (Tp/Te → CPU, Tg → GPU, TB?T → battery).
//  3. AppleSmartBattery "Temperature" registry property (battery only, merged by SystemMonitor).
//
//  `ProcessInfo.thermalState` is reported separately as thermal pressure; it is never
//  converted into a temperature. Unattributed sensors (PMU die/device sensors) are listed
//  under their own names and never promoted to CPU or GPU temperature.
//

import Foundation

public final class SensorProvider: @unchecked Sendable {
    /// How long a component's last good reading is retained (and shown as stale) when a poll fails.
    public static let retainLastGoodReadingFor: TimeInterval = 60

    private let lock = NSLock()
    private lazy var smcReader = SMCSensorReader()
    private lazy var hidReader = HIDThermalSensorReader()
    private var previous: SensorMetrics?

    public init() {}

    /// Polls hardware sensors. Blocking; call off the main thread.
    public func sample(hardwareAccessEnabled: Bool = true, now: Date = Date()) -> SensorMetrics {
        lock.lock()
        defer { lock.unlock() }

        let thermalState = ProcessInfo.processInfo.thermalState
        let metrics: SensorMetrics
        if hardwareAccessEnabled {
            metrics = SensorMetricsBuilder.build(
                thermalState: thermalState,
                hid: hidReader.readTemperatures(now: now),
                smc: smcReader.readTemperatures(),
                fans: smcReader.readFans(),
                now: now
            )
        } else {
            metrics = SensorMetricsBuilder.build(thermalState: thermalState, hid: nil, smc: nil, fans: nil, now: now)
        }

        let result = SensorMetricsBuilder.retainingRecentReadings(
            current: metrics,
            previous: previous,
            now: now,
            maxAge: Self.retainLastGoodReadingFor
        )
        previous = result
        return result
    }
}

// MARK: - Builder (pure; used by the provider and by unit tests with mocked reader output)

public enum SensorMetricsBuilder {
    public static let disabledReason = "Hardware temperature sensors are turned off in Settings › General."

    /// - Parameters:
    ///   - hid, smc, fans: reader results, or nil when hardware sensor access is disabled.
    public static func build(
        thermalState: ProcessInfo.ThermalState,
        hid: SensorReadResult?,
        smc: SensorReadResult?,
        fans: FanReadResult?,
        isAppleSilicon: Bool = Self.isAppleSilicon,
        now: Date = Date()
    ) -> SensorMetrics {
        var metrics = SensorMetrics()
        metrics.sampledAt = now
        applyThermalState(thermalState, to: &metrics)

        let accessEnabled = hid != nil || smc != nil

        // 1. Classify every plausible value with its identity and source.
        var classified: [TemperatureReading] = []
        var statuses: [SensorSourceStatus] = []
        for (source, result) in [(SensorSource.hidEventSystem, hid), (SensorSource.smc, smc)] {
            guard let result else { continue }
            switch result {
            case .unavailable(let reason):
                statuses.append(SensorSourceStatus(source: source, state: .unavailable(reason: reason), sensorCount: 0))
            case .values(let raws):
                let readings = raws.compactMap { classify($0, isAppleSilicon: isAppleSilicon, now: now) }
                classified.append(contentsOf: readings)
                statuses.append(SensorSourceStatus(
                    source: source,
                    state: readings.isEmpty ? .unavailable(reason: "No plausible temperature values were returned.") : .available,
                    sensorCount: readings.count
                ))
            }
        }
        metrics.sourceStatuses = statuses

        // 2. Per component keep only the most reliably identified source, so one physical
        //    component is never averaged across two different sensor families.
        var chosen: [TemperatureReading] = []
        for component in ThermalComponent.allCases {
            let candidates = classified.filter { $0.component == component }
            guard let best = candidates.min(by: { sourceRank($0) < sourceRank($1) }) else { continue }
            chosen.append(contentsOf: candidates.filter { $0.source == best.source })
        }
        metrics.readings = chosen.sorted { lhs, rhs in
            if lhs.component != rhs.component {
                return ThermalComponent.allCases.firstIndex(of: lhs.component)! < ThermalComponent.allCases.firstIndex(of: rhs.component)!
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        // 3. Headline components, each from its own sensors only.
        for component in ThermalComponent.headline {
            let value = ComponentTemperature.aggregate(metrics.readings, component: component)
            metrics.setTemperature(value, for: component)
            metrics.componentStates[component] = value != nil
                ? .available
                : .unavailable(reason: unavailableReason(for: component, accessEnabled: accessEnabled, statuses: statuses, totalReadings: metrics.readings.count))
        }

        if !accessEnabled {
            metrics.temperatureState = .unavailable(reason: disabledReason)
        } else if metrics.readings.isEmpty {
            let reasons = statuses.compactMap { status -> String? in
                if case .unavailable(let reason) = status.state { return "\(status.source.displayName): \(reason)" }
                return nil
            }
            metrics.temperatureState = .unavailable(reason: reasons.isEmpty ? "No temperature sensors were found." : reasons.joined(separator: " "))
        } else {
            metrics.temperatureState = .available
        }

        applyFans(fans, to: &metrics)
        return metrics
    }

    /// Fills the battery temperature from the AppleSmartBattery registry only when no hardware
    /// battery sensor was found. The registry timestamp is preserved so staleness stays honest.
    public static func mergeBatteryRegistry(
        into metrics: inout SensorMetrics,
        hasBattery: Bool,
        registryCelsius: Double?,
        registryTimestamp: Date
    ) {
        guard hasBattery else {
            metrics.batteryTemperature = nil
            metrics.readings.removeAll { $0.component == .battery }
            metrics.componentStates[.battery] = .unavailable(reason: "This Mac has no internal battery.")
            return
        }
        guard metrics.batteryTemperature == nil,
              let celsius = registryCelsius,
              SensorClassifier.isPlausible(celsius) else { return }

        let reading = TemperatureReading(
            id: "\(SensorSource.appleSmartBattery.rawValue).Temperature",
            name: "Battery (AppleSmartBattery)",
            key: "Temperature",
            component: .battery,
            celsius: celsius,
            timestamp: registryTimestamp,
            source: .appleSmartBattery,
            identification: .vendorLabeled
        )
        metrics.readings.append(reading)
        metrics.batteryTemperature = ComponentTemperature.aggregate([reading], component: .battery)
        metrics.componentStates[.battery] = .available
    }

    /// Keeps a headline component's previous value (with its original timestamp) when the
    /// current poll lost it, so a transient read failure shows as stale rather than flickering.
    public static func retainingRecentReadings(
        current: SensorMetrics,
        previous: SensorMetrics?,
        now: Date,
        maxAge: TimeInterval
    ) -> SensorMetrics {
        guard let previous, current.temperatureState != .unavailable(reason: disabledReason) else { return current }
        var result = current
        for component in ThermalComponent.headline where result.temperature(for: component) == nil {
            guard let old = previous.temperature(for: component), !old.isStale(at: now, maxAge: maxAge) else { continue }
            result.setTemperature(old, for: component)
            result.readings.append(contentsOf: previous.readings(for: component))
            result.componentStates[component] = .available
        }
        return result
    }

    // MARK: - Helpers

    public static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    static func classify(_ raw: RawTemperatureValue, isAppleSilicon: Bool, now: Date) -> TemperatureReading? {
        guard SensorClassifier.isPlausible(raw.celsius) else { return nil }
        let component: ThermalComponent?
        let identification: SensorIdentification
        switch raw.source {
        case .hidEventSystem:
            component = SensorClassifier.component(forHIDProduct: raw.name)
            identification = .vendorLabeled
        case .smc:
            component = SensorClassifier.component(forSMCKey: raw.key, isAppleSilicon: isAppleSilicon)
            identification = .keyConvention
        case .appleSmartBattery:
            component = .battery
            identification = .vendorLabeled
        }
        guard let component else { return nil }
        return TemperatureReading(
            id: "\(raw.source.rawValue).\(raw.key)",
            name: raw.name,
            key: raw.key,
            component: component,
            celsius: raw.celsius,
            timestamp: now,
            source: raw.source,
            identification: identification
        )
    }

    private static func sourceRank(_ reading: TemperatureReading) -> Int {
        reading.identification.priority * 10 + (SensorSource.allCases.firstIndex(of: reading.source) ?? 9)
    }

    private static func unavailableReason(
        for component: ThermalComponent,
        accessEnabled: Bool,
        statuses: [SensorSourceStatus],
        totalReadings: Int
    ) -> String {
        guard accessEnabled else { return disabledReason }
        if totalReadings == 0 {
            let reasons = statuses.compactMap { status -> String? in
                if case .unavailable(let reason) = status.state { return reason }
                return nil
            }
            return reasons.first ?? "No temperature sensors are accessible on this Mac."
        }
        return "This Mac exposes \(totalReadings) temperature sensor\(totalReadings == 1 ? "" : "s"), but none is identified as a \(component.displayName) sensor."
    }

    private static func applyThermalState(_ state: ProcessInfo.ThermalState, to metrics: inout SensorMetrics) {
        metrics.thermalState = state
        metrics.isThrottling = state == .serious || state == .critical
        switch state {
        case .nominal: metrics.thermalStateDescription = "Nominal (No Thermal Pressure)"
        case .fair: metrics.thermalStateDescription = "Fair (Elevated Thermal Pressure)"
        case .serious: metrics.thermalStateDescription = "Serious (Performance Being Reduced)"
        case .critical: metrics.thermalStateDescription = "Critical (Maximum Performance Reduction)"
        @unknown default: metrics.thermalStateDescription = "Unknown"
        }
    }

    private static func applyFans(_ fans: FanReadResult?, to metrics: inout SensorMetrics) {
        guard let fans else {
            metrics.fansState = .unavailable(reason: disabledReason)
            return
        }
        switch fans {
        case .unavailable(let reason):
            metrics.fansState = .unavailable(reason: reason)
        case .fans(let count, let readings):
            metrics.reportedFanCount = count
            metrics.fanSpeeds = readings.map { raw in
                FanInfo(
                    id: raw.index,
                    name: "Fan \(raw.index + 1)",
                    speedRPM: raw.rpm,
                    minRPM: raw.minRPM.flatMap { $0 >= 0 ? $0 : nil },
                    maxRPM: raw.maxRPM.flatMap { $0 > 0 ? $0 : nil }
                )
            }
            if count == 0 {
                metrics.fansState = .unavailable(reason: "The SMC reports no fans. This Mac is passively cooled.")
            } else if metrics.fanSpeeds.isEmpty {
                metrics.fansState = .unavailable(reason: "The SMC reports \(count) fan\(count == 1 ? "" : "s") but returned no speed reading.")
            } else {
                metrics.fansState = .available
            }
        }
    }
}
