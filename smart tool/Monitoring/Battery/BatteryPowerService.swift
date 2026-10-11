//
//  BatteryPowerService.swift
//  Borno Pulse
//
//  Dedicated real-time battery power telemetry and electrical calculations service.
//

import Foundation
import IOKit
import IOKit.ps

// MARK: - Battery Power Telemetry Model
public struct BatteryPowerTelemetry: Sendable {
    public var voltageVolts: Double?
    public var amperageAmps: Double?
    public var chargingWatts: Double?
    public var dischargingWatts: Double?
    public var systemPowerWatts: Double?
    public var adapterInputWatts: Double?
    public var adapterRatedWatts: Int?
    public var adapterName: String?
    public var isMeasured: Bool
    public var cycleCount: Int?
    public var healthPercentage: Int?
    public var temperatureCelsius: Double?
    public var isFullyCharged: Bool?
    public var timestamp: Date

    public init(
        voltageVolts: Double? = nil,
        amperageAmps: Double? = nil,
        chargingWatts: Double? = nil,
        dischargingWatts: Double? = nil,
        systemPowerWatts: Double? = nil,
        adapterInputWatts: Double? = nil,
        adapterRatedWatts: Int? = nil,
        adapterName: String? = nil,
        isMeasured: Bool = true,
        cycleCount: Int? = nil,
        healthPercentage: Int? = nil,
        temperatureCelsius: Double? = nil,
        isFullyCharged: Bool? = nil,
        timestamp: Date = Date()
    ) {
        self.voltageVolts = voltageVolts
        self.amperageAmps = amperageAmps
        self.chargingWatts = chargingWatts
        self.dischargingWatts = dischargingWatts
        self.systemPowerWatts = systemPowerWatts
        self.adapterInputWatts = adapterInputWatts
        self.adapterRatedWatts = adapterRatedWatts
        self.adapterName = adapterName
        self.isMeasured = isMeasured
        self.cycleCount = cycleCount
        self.healthPercentage = healthPercentage
        self.temperatureCelsius = temperatureCelsius
        self.isFullyCharged = isFullyCharged
        self.timestamp = timestamp
    }
}

// MARK: - Historical Power Sample
public struct BatteryPowerHistoricalSample: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let chargingWatts: Double?
    public let dischargingWatts: Double?
    public let systemPowerWatts: Double?
    public let adapterInputWatts: Double?
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let isMeasured: Bool

    public var effectiveBatteryWatts: Double? {
        if let c = chargingWatts { return c }
        if let d = dischargingWatts { return -d }
        return nil
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        chargingWatts: Double? = nil,
        dischargingWatts: Double? = nil,
        systemPowerWatts: Double? = nil,
        adapterInputWatts: Double? = nil,
        isCharging: Bool,
        isPluggedIn: Bool,
        isMeasured: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.chargingWatts = chargingWatts
        self.dischargingWatts = dischargingWatts
        self.systemPowerWatts = systemPowerWatts
        self.adapterInputWatts = adapterInputWatts
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.isMeasured = isMeasured
    }
}

// MARK: - Battery Power Service
@MainActor
public final class BatteryPowerService: ObservableObject {
    public static let shared = BatteryPowerService()

    /// Rolling in-memory history of power samples (up to 15 minutes)
    @Published public private(set) var powerHistory: [BatteryPowerHistoricalSample] = []
    @Published public private(set) var latestTelemetry: BatteryPowerTelemetry? = nil

    private let maxHistoryWindowSeconds: TimeInterval = 900 // 15 minutes
    private var lastRecordedTimestamp: Date = .distantPast

    public init() {}

    // MARK: - Hardware Telemetry Acquisition
    public func queryHardwarePowerTelemetry(isPluggedIn: Bool, isCharging: Bool) -> BatteryPowerTelemetry {
        let matching = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return BatteryPowerTelemetry(timestamp: Date())
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            return BatteryPowerTelemetry(timestamp: Date())
        }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return BatteryPowerTelemetry(timestamp: Date())
        }

        let telemetry = Self.parseAppleSmartBatteryProperties(dict, isPluggedIn: isPluggedIn, isCharging: isCharging)
        self.latestTelemetry = telemetry
        recordSample(telemetry: telemetry, isCharging: isCharging, isPluggedIn: isPluggedIn)
        return telemetry
    }

    // MARK: - Pure Parsing & Calculation (Testable)

    /// Calculates electrical power in Watts: Power (W) = Voltage (V) × Current (A)
    /// Converts millivolts and milliamps to Volts and Amps.
    /// Handles invalid or non-positive voltages by returning nil.
    public static func calculateElectricalPower(voltageMilliVolts: Double?, amperageMilliAmps: Double?) -> Double? {
        guard let mv = voltageMilliVolts, let ma = amperageMilliAmps else { return nil }
        guard mv > 0.0 else { return nil } // Physical battery voltage must be positive

        let volts = mv / 1000.0
        let amps = abs(ma) / 1000.0
        return volts * amps
    }

    /// Resolves power flow direction based on connection state and current sign convention
    public static func resolvePowerFlow(
        isPluggedIn: Bool,
        isCharging: Bool,
        amperageMilliAmps: Double?,
        electricalWatts: Double?,
        systemPowerMilliWatts: Double? = nil,
        adapterInputMilliWatts: Double? = nil
    ) -> (chargingWatts: Double?, dischargingWatts: Double?, systemWatts: Double?, adapterWatts: Double?) {
        var chargingWatts: Double? = nil
        var dischargingWatts: Double? = nil

        if let watts = electricalWatts {
            if !isPluggedIn {
                // Running on battery: active discharge
                dischargingWatts = watts
                chargingWatts = nil
            } else if isCharging {
                // Connected and charging: active charge power flowing into battery
                chargingWatts = watts
                dischargingWatts = nil
            } else {
                // Connected to power adapter, but not actively charging (e.g. 100% full or 80% hold)
                // Battery power absorption is measured at 0.0 W
                chargingWatts = 0.0
                dischargingWatts = nil
            }
        }

        let systemWatts: Double?
        if let sysMW = systemPowerMilliWatts, sysMW > 0 {
            systemWatts = sysMW / 1000.0
        } else {
            systemWatts = nil
        }

        let adapterWatts: Double?
        if let adpMW = adapterInputMilliWatts, adpMW > 0 {
            adapterWatts = adpMW / 1000.0
        } else {
            adapterWatts = nil
        }

        return (chargingWatts, dischargingWatts, systemWatts, adapterWatts)
    }

    /// Estimates average power change (W) when only battery capacity and percentage change over elapsed time are available.
    /// Capacity is in mAh, nominal voltage defaults to 11.4V.
    public static func calculateEstimatedPowerFromEnergy(
        capacityMilliampHours: Double,
        percentageDelta: Double,
        elapsedSeconds: TimeInterval,
        nominalVoltageVolts: Double = 11.4
    ) -> Double? {
        guard elapsedSeconds >= 10.0, capacityMilliampHours > 0, percentageDelta != 0 else { return nil }
        let totalEnergyWh = (capacityMilliampHours / 1000.0) * nominalVoltageVolts
        let energyDeltaWh = totalEnergyWh * (abs(percentageDelta) / 100.0)
        let hours = elapsedSeconds / 3600.0
        guard hours > 0 else { return nil }
        return energyDeltaWh / hours
    }

    /// Parses hardware dictionary from AppleSmartBattery service
    public static func parseAppleSmartBatteryProperties(_ dict: [String: Any], isPluggedIn: Bool, isCharging: Bool) -> BatteryPowerTelemetry {
        var telemetry = BatteryPowerTelemetry(timestamp: Date())

        // 1. Voltage (mV)
        let rawVoltage: Double? = {
            if let v = dict["Voltage"] as? Int, v > 0 { return Double(v) }
            if let v = dict["AppleRawBatteryVoltage"] as? Int, v > 0 { return Double(v) }
            return nil
        }()
        if let v = rawVoltage {
            telemetry.voltageVolts = v / 1000.0
        }

        // 2. Amperage (mA)
        let rawAmperage: Double? = {
            if let a = dict["InstantAmperage"] as? Int { return Double(a) }
            if let a = dict["Amperage"] as? Int { return Double(a) }
            return nil
        }()
        if let a = rawAmperage {
            telemetry.amperageAmps = a / 1000.0
        }

        // 3. Electrical power calculation
        let calculatedWatts = calculateElectricalPower(voltageMilliVolts: rawVoltage, amperageMilliAmps: rawAmperage)

        // 4. Power Telemetry Data (System load, System power in)
        var sysMW: Double? = nil
        if let telemetryDict = dict["PowerTelemetryData"] as? [String: Any] {
            if let load = telemetryDict["SystemLoad"] as? Int, load > 0 {
                sysMW = Double(load)
            } else if let powerIn = telemetryDict["SystemPowerIn"] as? Int, powerIn > 0 {
                sysMW = Double(powerIn)
            }
        }

        // 5. Power Distribution (Input power from charger)
        var adpMW: Double? = nil
        if let distDict = dict["PowerDistribution"] as? [String: Any] {
            if let ipd = distDict["IPDInputPower"] as? Int, ipd > 0 {
                adpMW = Double(ipd)
            }
        }

        // 6. Adapter Details (Rated wattage and adapter name)
        if let adapterDict = dict["AdapterDetails"] as? [String: Any] {
            if let watts = adapterDict["Watts"] as? Int, watts > 0 {
                telemetry.adapterRatedWatts = watts
            }
            if let name = adapterDict["Name"] as? String, !name.isEmpty {
                telemetry.adapterName = name
            } else if let desc = adapterDict["Description"] as? String, !desc.isEmpty {
                telemetry.adapterName = desc
            }
        }

        // 7. Resolve Power Flow
        let flow = resolvePowerFlow(
            isPluggedIn: isPluggedIn,
            isCharging: isCharging,
            amperageMilliAmps: rawAmperage,
            electricalWatts: calculatedWatts,
            systemPowerMilliWatts: sysMW,
            adapterInputMilliWatts: adpMW
        )

        telemetry.chargingWatts = flow.chargingWatts
        telemetry.dischargingWatts = flow.dischargingWatts
        telemetry.systemPowerWatts = flow.systemWatts
        telemetry.adapterInputWatts = flow.adapterWatts
        telemetry.isMeasured = (calculatedWatts != nil)

        // 8. Health, cycles, temperature, fully charged
        if let cycles = dict["CycleCount"] as? Int {
            telemetry.cycleCount = cycles
        }
        if let maxCap = dict["MaxCapacity"] as? Int, maxCap > 0 {
            telemetry.healthPercentage = min(maxCap, 100)
        }
        if let temp = dict["Temperature"] as? Int, temp > 0 {
            telemetry.temperatureCelsius = Double(temp) / 100.0
        }
        if let full = dict["FullyCharged"] as? Bool {
            telemetry.isFullyCharged = full
        }

        return telemetry
    }

    // MARK: - Rolling History Buffer Management

    public func recordSample(telemetry: BatteryPowerTelemetry, isCharging: Bool, isPluggedIn: Bool) {
        let now = Date()
        // Throttle updates to at most once per second unless state changes
        guard now.timeIntervalSince(lastRecordedTimestamp) >= 0.8 else { return }
        lastRecordedTimestamp = now

        let sample = BatteryPowerHistoricalSample(
            timestamp: now,
            chargingWatts: telemetry.chargingWatts,
            dischargingWatts: telemetry.dischargingWatts,
            systemPowerWatts: telemetry.systemPowerWatts,
            adapterInputWatts: telemetry.adapterInputWatts,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            isMeasured: telemetry.isMeasured
        )

        powerHistory.append(sample)

        // Prune older than 15 minutes
        let cutoff = now.addingTimeInterval(-maxHistoryWindowSeconds)
        powerHistory.removeAll { $0.timestamp < cutoff }
    }

    /// Returns historical samples bounded by the requested time window (e.g. 300s = 5m, 900s = 15m)
    public func samples(for intervalSeconds: TimeInterval) -> [BatteryPowerHistoricalSample] {
        let cutoff = Date().addingTimeInterval(-intervalSeconds)
        return powerHistory.filter { $0.timestamp >= cutoff }
    }
}
