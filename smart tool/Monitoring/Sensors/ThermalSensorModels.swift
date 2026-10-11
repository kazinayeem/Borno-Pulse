//
//  ThermalSensorModels.swift
//  Borno Pulse
//
//  Shared, component-aware temperature model. Every reading carries the identity of the
//  physical sensor it came from so CPU, GPU, battery and other sensors can never be
//  confused with one another or with the OS thermal-pressure state.
//

import Foundation

// MARK: - Component

public enum ThermalComponent: String, CaseIterable, Identifiable, Codable, Sendable {
    case cpu
    case gpu
    case battery
    case storage
    case soc
    case powerManagement
    case other

    public var id: String { rawValue }

    /// Components that have a dedicated headline value in the UI, menu bar and alerts.
    public static let headline: [ThermalComponent] = [.cpu, .gpu, .battery, .storage]

    public var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .battery: return "Battery"
        case .storage: return "SSD (NAND)"
        case .soc: return "SoC Blocks"
        case .powerManagement: return "Power-Management Unit"
        case .other: return "Other Sensors"
        }
    }

    public var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "circle.grid.cross"
        case .battery: return "battery.75"
        case .storage: return "internaldrive"
        case .soc: return "square.stack.3d.up"
        case .powerManagement: return "bolt.horizontal.circle"
        case .other: return "thermometer.variable.and.figure"
        }
    }

    /// Explains what the group represents and why it is (or isn't) attributed to a component.
    public var groupDescription: String {
        switch self {
        case .cpu: return "Sensors attributed to the CPU performance and efficiency clusters."
        case .gpu: return "Sensors attributed to the GPU."
        case .battery: return "Sensors inside the battery pack (gas gauge)."
        case .storage: return "Sensors on the internal SSD's NAND flash."
        case .soc: return "Other on-die SoC blocks (e.g. Neural Engine, ISP, fabric)."
        case .powerManagement: return "Die and device sensors reported by the power-management unit(s). Apple does not document which silicon block each sensor monitors, so these are never reported as CPU or GPU temperature."
        case .other: return "Sensors the system exposes with a name that does not identify a component."
        }
    }
}

// MARK: - Source

public enum SensorSource: String, Codable, Sendable, CaseIterable {
    case hidEventSystem
    case smc
    case appleSmartBattery

    public var displayName: String {
        switch self {
        case .hidEventSystem: return "IOHID Event System"
        case .smc: return "Apple SMC"
        case .appleSmartBattery: return "AppleSmartBattery Registry"
        }
    }

    public var interfaceDescription: String {
        switch self {
        case .hidEventSystem:
            return "IOHIDEventSystemClient temperature services. Service enumeration is public API; reading the event value uses private IOKit symbols resolved at runtime."
        case .smc:
            return "AppleSMC user client (undocumented). Keys are read-only; component mapping follows the community-documented SMC key naming convention."
        case .appleSmartBattery:
            return "IORegistry properties of the AppleSmartBattery service (public IOKit API, undocumented property names)."
        }
    }
}

/// How confidently a sensor was attributed to a component.
public enum SensorIdentification: String, Codable, Sendable {
    /// The system itself names the sensor (e.g. HID product "gas gauge battery").
    case vendorLabeled
    /// Attributed through the reverse-engineered SMC key naming convention (e.g. `Tp01`).
    case keyConvention

    public var displayName: String {
        switch self {
        case .vendorLabeled: return "Named by macOS"
        case .keyConvention: return "SMC key convention"
        }
    }

    /// Lower is preferred when several sources report the same component.
    var priority: Int {
        switch self {
        case .vendorLabeled: return 0
        case .keyConvention: return 1
        }
    }
}

// MARK: - Raw Provider Output

/// One unprocessed value as returned by a hardware reader, before classification.
public struct RawTemperatureValue: Sendable, Equatable {
    public var key: String
    public var name: String
    public var celsius: Double
    public var source: SensorSource

    public init(key: String, name: String, celsius: Double, source: SensorSource) {
        self.key = key
        self.name = name
        self.celsius = celsius
        self.source = source
    }
}

/// Result of polling one hardware reader.
public enum SensorReadResult: Sendable, Equatable {
    case values([RawTemperatureValue])
    case unavailable(reason: String)
}

public struct RawFanValue: Sendable, Equatable {
    public var index: Int
    public var rpm: Double
    public var minRPM: Double?
    public var maxRPM: Double?

    public init(index: Int, rpm: Double, minRPM: Double? = nil, maxRPM: Double? = nil) {
        self.index = index
        self.rpm = rpm
        self.minRPM = minRPM
        self.maxRPM = maxRPM
    }
}

public enum FanReadResult: Sendable, Equatable {
    /// The SMC reported its fan count (possibly zero) and the fans that returned a valid speed.
    case fans(reportedCount: Int, readings: [RawFanValue])
    case unavailable(reason: String)
}

// MARK: - Classified Readings

public struct TemperatureReading: Identifiable, Sendable, Equatable {
    /// Stable identity, e.g. `smc.Tp01` or `hid.PMU tdie1.0x54503162`.
    public let id: String
    public let name: String
    public let key: String
    public let component: ThermalComponent
    public let celsius: Double
    public let timestamp: Date
    public let source: SensorSource
    public let identification: SensorIdentification

    public init(
        id: String,
        name: String,
        key: String,
        component: ThermalComponent,
        celsius: Double,
        timestamp: Date,
        source: SensorSource,
        identification: SensorIdentification
    ) {
        self.id = id
        self.name = name
        self.key = key
        self.component = component
        self.celsius = celsius
        self.timestamp = timestamp
        self.source = source
        self.identification = identification
    }
}

/// Aggregated temperature for a single component, derived only from sensors attributed to it.
public struct ComponentTemperature: Sendable, Equatable {
    public let component: ThermalComponent
    public let averageCelsius: Double
    public let maximumCelsius: Double
    public let sensorCount: Int
    public let source: SensorSource
    public let identification: SensorIdentification
    public let timestamp: Date

    /// Headline value shown throughout the app (mean of the component's sensors).
    public var celsius: Double { averageCelsius }

    public init(
        component: ThermalComponent,
        averageCelsius: Double,
        maximumCelsius: Double,
        sensorCount: Int,
        source: SensorSource,
        identification: SensorIdentification,
        timestamp: Date
    ) {
        self.component = component
        self.averageCelsius = averageCelsius
        self.maximumCelsius = maximumCelsius
        self.sensorCount = sensorCount
        self.source = source
        self.identification = identification
        self.timestamp = timestamp
    }

    public func age(at now: Date = Date()) -> TimeInterval {
        max(0, now.timeIntervalSince(timestamp))
    }

    public func isStale(at now: Date = Date(), maxAge: TimeInterval) -> Bool {
        age(at: now) > maxAge
    }

    /// Aggregates readings that all belong to `component` and come from one source.
    public static func aggregate(_ readings: [TemperatureReading], component: ThermalComponent) -> ComponentTemperature? {
        let matching = readings.filter { $0.component == component }
        guard let first = matching.first else { return nil }
        let values = matching.map(\.celsius)
        return ComponentTemperature(
            component: component,
            averageCelsius: values.reduce(0, +) / Double(values.count),
            maximumCelsius: values.max() ?? first.celsius,
            sensorCount: matching.count,
            source: first.source,
            identification: first.identification,
            timestamp: matching.map(\.timestamp).min() ?? first.timestamp
        )
    }
}

/// One point in a component's temperature history. `celsius == nil` marks a gap.
public struct TemperatureHistoryPoint: Sendable, Equatable, Identifiable {
    public var id: Date { timestamp }
    public let timestamp: Date
    public let celsius: Double?
    public let source: SensorSource?
    public let sensorCount: Int

    public init(timestamp: Date, celsius: Double?, source: SensorSource?, sensorCount: Int) {
        self.timestamp = timestamp
        self.celsius = celsius
        self.source = source
        self.sensorCount = sensorCount
    }
}

/// Per-source diagnostic status shown on the Temperature and Diagnostics pages.
public struct SensorSourceStatus: Sendable, Equatable, Identifiable {
    public var id: String { source.rawValue }
    public let source: SensorSource
    public let state: AvailabilityState
    public let sensorCount: Int

    public init(source: SensorSource, state: AvailabilityState, sensorCount: Int) {
        self.source = source
        self.state = state
        self.sensorCount = sensorCount
    }
}

// MARK: - Freshness

public enum SensorFreshness {
    /// Hardware sensors are polled every other monitoring tick.
    public static let ticksPerSensorPoll: Double = 2
    public static let defaultStaleAfter: TimeInterval = 10

    /// A reading is stale once three sensor polls have been missed (minimum 10 s).
    public static func staleAfter(refreshInterval: TimeInterval) -> TimeInterval {
        max(defaultStaleAfter, refreshInterval * ticksPerSensorPoll * 3)
    }
}

// MARK: - Classification

public enum SensorClassifier {
    /// Physically plausible range for an operating Mac. Disconnected thermistors report values such as -22 °C or 0 °C.
    public static let plausibleRange: ClosedRange<Double> = 1.0...130.0

    public static func isPlausible(_ celsius: Double) -> Bool {
        celsius.isFinite && plausibleRange.contains(celsius)
    }

    /// Maps an HID temperature service's product name to a component. Returns nil for
    /// services that are not real temperature readings (e.g. calibration references).
    public static func component(forHIDProduct product: String) -> ThermalComponent? {
        let name = product.lowercased()
        if name.contains("tcal") { return nil }
        if name.contains("pacc mtr") || name.contains("eacc mtr") { return .cpu }
        if name.contains("gpu mtr") { return .gpu }
        if name.contains("gas gauge battery") { return .battery }
        if name.contains("nand") { return .storage }
        if name.contains("soc mtr") || name.contains("ane mtr") || name.contains("isp mtr") || name.contains("pmgr soc") {
            return .soc
        }
        if name.hasPrefix("pmu") { return .powerManagement }
        return .other
    }

    /// Maps an SMC key to a component using the naming convention for the given architecture.
    /// Only keys whose meaning is well established are classified; everything else returns nil
    /// and is never displayed as a component temperature.
    public static func component(forSMCKey key: String, isAppleSilicon: Bool) -> ThermalComponent? {
        let chars = Array(key)
        guard chars.count == 4, chars[0] == "T" else { return nil }

        // TB0T, TB1T, TB2T: battery pack sensors on both Intel and Apple Silicon.
        if chars[1] == "B", chars[2].isNumber, chars[3] == "T" { return .battery }

        if isAppleSilicon {
            switch chars[1] {
            case "p", "e": return .cpu   // Tp**: performance cluster, Te**: efficiency cluster
            case "g": return .gpu        // Tg**: GPU
            default: return nil          // Note: uppercase TG** are battery gas-gauge keys on Apple Silicon.
            }
        } else {
            if chars[1] == "C", chars[2].isNumber, "CDEFHP".contains(chars[3]) { return .cpu }
            if key == "TCXC" { return .cpu }
            if chars[1] == "G", chars[2].isNumber, "DHP".contains(chars[3]) { return .gpu }
            return nil
        }
    }

    public static func smcDisplayName(forKey key: String, component: ThermalComponent) -> String {
        let chars = Array(key)
        switch component {
        case .cpu where chars.count == 4 && chars[1] == "p": return "CPU performance cluster (\(key))"
        case .cpu where chars.count == 4 && chars[1] == "e": return "CPU efficiency cluster (\(key))"
        case .cpu: return "CPU (\(key))"
        case .gpu: return "GPU (\(key))"
        case .battery: return "Battery pack (\(key))"
        default: return key
        }
    }
}

public extension ProcessInfo.ThermalState {
    var shortLabel: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
