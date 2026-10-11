//
//  MetricModels.swift
//  Borno Pulse
//

import Foundation
import Metal

// MARK: - Availability State
public enum AvailabilityState: Equatable, Sendable {
    case available
    case unavailable(reason: String)
    case permissionRequired(reason: String)
    case measuring
    
    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
    
    public var displayText: String {
        switch self {
        case .available:
            return "Available"
        case .unavailable(let reason):
            return reason
        case .permissionRequired(let reason):
            return "Permission Required: \(reason)"
        case .measuring:
            return "Measuring..."
        }
    }
}

// MARK: - CPU Metrics
public struct CPUMetrics: Sendable {
    public var totalUsage: Double = 0.0 // 0-100%
    public var userUsage: Double = 0.0
    public var systemUsage: Double = 0.0
    public var idleUsage: Double = 100.0
    public var niceUsage: Double = 0.0
    public var perCoreUsage: [Double] = []
    public var physicalCoreCount: Int = 0
    public var logicalCoreCount: Int = 0
    public var modelName: String = "Apple Silicon"
    public var architecture: String = "arm64"
    public var historicalUsage: [Double] = []
    public var state: AvailabilityState = .measuring
    
    public init() {}
}

// MARK: - GPU Metrics
public struct GPUMetrics: Sendable {
    public var deviceName: String = "Apple GPU"
    public var deviceUtilization: Double? = nil // 0-100%
    public var rendererUtilization: Double? = nil
    public var tilerUtilization: Double? = nil
    public var inUseMemoryBytes: UInt64? = nil
    public var allocatedMemoryBytes: UInt64? = nil
    public var recommendedMaxWorkingSetSize: UInt64 = 0
    public var maxBufferLength: UInt64 = 0
    public var hasUnifiedMemory: Bool = true
    public var isLowPower: Bool = false
    public var registryID: UInt64 = 0
    public var neuralEngineAvailable: Bool = true
    public var neuralEngineDescription: String = "Apple Neural Engine (Integrated)"
    public var state: AvailabilityState = .measuring
    public var historicalUsage: [Double] = []
    
    public init() {}
}

// MARK: - Memory Metrics
public enum MemoryPressureLevel: String, Sendable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
}

public struct MemoryMetrics: Sendable {
    public var totalBytes: UInt64 = 0
    public var usedBytes: UInt64 = 0
    public var availableBytes: UInt64 = 0
    public var activeBytes: UInt64 = 0
    public var inactiveBytes: UInt64 = 0
    public var wiredBytes: UInt64 = 0
    public var compressedBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var swapTotalBytes: UInt64 = 0
    public var swapUsedBytes: UInt64 = 0
    public var pressureLevel: MemoryPressureLevel = .normal
    public var pressurePercentage: Double = 0.0
    public var historicalUsage: [Double] = []
    public var state: AvailabilityState = .measuring
    
    public var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }
    
    public init() {}
}

// MARK: - Fan Info
public struct FanInfo: Identifiable, Sendable, Equatable {
    public var id: Int
    public var name: String
    public var speedRPM: Double
    /// Hardware-reported limits; nil when the SMC does not expose them.
    public var minRPM: Double?
    public var maxRPM: Double?
    
    public init(id: Int, name: String, speedRPM: Double, minRPM: Double? = nil, maxRPM: Double? = nil) {
        self.id = id
        self.name = name
        self.speedRPM = speedRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
    }
}

// MARK: - Sensor Metrics
public struct SensorMetrics: Sendable {
    // OS thermal pressure (ProcessInfo.thermalState). This is a state, not a temperature.
    public var thermalState: ProcessInfo.ThermalState = .nominal
    public var thermalStateDescription: String = "Nominal"
    public var isThrottling: Bool = false

    /// Every plausible reading from the preferred source of each component, with sensor identity.
    public var readings: [TemperatureReading] = []

    /// Populated only from sensors attributed to that specific component; never shared.
    public var cpuTemperature: ComponentTemperature? = nil
    public var gpuTemperature: ComponentTemperature? = nil
    public var batteryTemperature: ComponentTemperature? = nil
    public var storageTemperature: ComponentTemperature? = nil

    /// Availability (with the reason when unavailable) for each headline component.
    public var componentStates: [ThermalComponent: AvailabilityState] = [:]
    /// Overall hardware temperature availability (any sensor at all).
    public var temperatureState: AvailabilityState = .measuring

    public var fanSpeeds: [FanInfo] = []
    public var reportedFanCount: Int? = nil
    public var fansState: AvailabilityState = .measuring

    public var sourceStatuses: [SensorSourceStatus] = []
    /// When the hardware sensors were last polled; nil before the first poll.
    public var sampledAt: Date? = nil
    /// Rolling per-component history maintained by SystemMonitor. Gaps are nil points.
    public var history: [ThermalComponent: [TemperatureHistoryPoint]] = [:]
    
    public init() {}

    public func temperature(for component: ThermalComponent) -> ComponentTemperature? {
        switch component {
        case .cpu: return cpuTemperature
        case .gpu: return gpuTemperature
        case .battery: return batteryTemperature
        case .storage: return storageTemperature
        case .soc, .powerManagement, .other: return ComponentTemperature.aggregate(readings, component: component)
        }
    }

    public mutating func setTemperature(_ value: ComponentTemperature?, for component: ThermalComponent) {
        switch component {
        case .cpu: cpuTemperature = value
        case .gpu: gpuTemperature = value
        case .battery: batteryTemperature = value
        case .storage: storageTemperature = value
        case .soc, .powerManagement, .other: break
        }
    }

    public func state(for component: ThermalComponent) -> AvailabilityState {
        if temperature(for: component) != nil { return .available }
        return componentStates[component] ?? temperatureState
    }

    public func readings(for component: ThermalComponent) -> [TemperatureReading] {
        readings.filter { $0.component == component }
    }
}

// MARK: - Storage Volume
public struct StorageVolume: Identifiable, Sendable {
    public var id: String { mountPoint }
    public var name: String
    public var mountPoint: String
    public var fileSystem: String
    public var totalBytes: UInt64
    public var usedBytes: UInt64
    public var freeBytes: UInt64
    public var purgeableBytes: UInt64
    public var isSystem: Bool
    
    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }
    
    public init(
        name: String,
        mountPoint: String,
        fileSystem: String = "APFS",
        totalBytes: UInt64,
        usedBytes: UInt64,
        freeBytes: UInt64,
        purgeableBytes: UInt64 = 0,
        isSystem: Bool = false
    ) {
        self.name = name
        self.mountPoint = mountPoint
        self.fileSystem = fileSystem
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.purgeableBytes = purgeableBytes
        self.isSystem = isSystem
    }
}

public struct StorageMetrics: Sendable {
    public var volumes: [StorageVolume] = []
    public var primaryVolume: StorageVolume? = nil
    public var totalCapacityBytes: UInt64 = 0
    public var usedCapacityBytes: UInt64 = 0
    public var availableCapacityBytes: UInt64 = 0
    public var purgeableBytes: UInt64 = 0
    public var state: AvailabilityState = .measuring
    
    public var usedPercentage: Double {
        guard totalCapacityBytes > 0 else { return 0 }
        return (Double(usedCapacityBytes) / Double(totalCapacityBytes)) * 100.0
    }
    
    public init() {}
}

// MARK: - Network Info
public struct NetworkInterfaceInfo: Identifiable, Sendable {
    public var id: String { name }
    public var name: String
    public var displayName: String
    public var ipAddress: String?
    public var isUp: Bool
    public var isWiFi: Bool
    
    public init(name: String, displayName: String, ipAddress: String? = nil, isUp: Bool = true, isWiFi: Bool = false) {
        self.name = name
        self.displayName = displayName
        self.ipAddress = ipAddress
        self.isUp = isUp
        self.isWiFi = isWiFi
    }
}

public struct NetworkMetrics: Sendable {
    public var downloadSpeedBytesPerSec: Double = 0.0
    public var uploadSpeedBytesPerSec: Double = 0.0
    public var totalReceivedBytes: UInt64 = 0
    public var totalSentBytes: UInt64 = 0
    public var activeInterfaces: [NetworkInterfaceInfo] = []
    public var primaryInterface: String = "en0"
    public var historicalDownload: [Double] = []
    public var historicalUpload: [Double] = []
    public var state: AvailabilityState = .measuring
    
    public init() {}
}

// MARK: - Battery Metrics
public enum BatteryEstimateConfidence: String, CaseIterable, Identifiable, Codable, Sendable {
    case high = "High Confidence"
    case medium = "Moderate Confidence"
    case low = "Low Confidence"
    case calculating = "Calculating..."
    case unavailable = "Unavailable"
    
    public var id: String { rawValue }
}

public enum BatteryStateOfCharge: String, CaseIterable, Identifiable, Codable, Sendable {
    case charging = "Charging"
    case discharging = "Discharging"
    case fullyCharged = "Fully Charged"
    case acDesktop = "AC Connected"
    case unknown = "Unknown"
    
    public var id: String { rawValue }
}

public struct BatteryMetrics: Sendable {
    public var hasBattery: Bool = false
    public var percentage: Int = 100
    public var isCharging: Bool = false
    public var isPluggedIn: Bool = true
    public var isFullyCharged: Bool = false
    public var timeToEmptyMinutes: Int? = nil
    public var timeToFullMinutes: Int? = nil
    public var estimatedMinutes: Int? = nil
    public var formattedTimeRemaining: String = "Calculating estimate..."
    public var estimateConfidence: BatteryEstimateConfidence = .calculating
    public var stateOfCharge: BatteryStateOfCharge = .unknown
    public var ratePercentagePerHour: Double? = nil
    public var wattage: Double? = nil
    public var chargingWatts: Double? = nil
    public var dischargingWatts: Double? = nil
    public var systemPowerWatts: Double? = nil
    public var adapterInputWatts: Double? = nil
    public var adapterRatedWatts: Int? = nil
    public var adapterName: String? = nil
    public var isMeasuredWattage: Bool = true
    public var voltageVolts: Double? = nil
    public var amperageAmps: Double? = nil
    /// Raw AppleSmartBattery "Temperature" registry value. UI must use
    /// `SensorMetrics.batteryTemperature`, which merges this with hardware sensors.
    public var registryTemperatureCelsius: Double? = nil
    public var cycleCount: Int? = nil
    public var healthPercentage: Int? = nil
    public var condition: String = "Normal"
    public var powerSource: String = "Power Adapter"
    public var lastUpdated: Date = Date()
    public var state: AvailabilityState = .measuring
    
    public init() {}
}

// MARK: - Overall Snapshot
public struct SystemMetricsSnapshot: Sendable {
    public var timestamp: Date = Date()
    public var cpu: CPUMetrics = CPUMetrics()
    public var gpu: GPUMetrics = GPUMetrics()
    public var memory: MemoryMetrics = MemoryMetrics()
    public var sensors: SensorMetrics = SensorMetrics()
    public var storage: StorageMetrics = StorageMetrics()
    public var network: NetworkMetrics = NetworkMetrics()
    public var battery: BatteryMetrics = BatteryMetrics()
    
    public var healthScore: Int {
        var score = 100
        if cpu.totalUsage > 85 { score -= 15 }
        else if cpu.totalUsage > 60 { score -= 5 }
        
        if memory.usagePercentage > 90 || memory.pressureLevel == .critical { score -= 25 }
        else if memory.usagePercentage > 75 || memory.pressureLevel == .warning { score -= 10 }
        
        if sensors.isThrottling { score -= 20 }
        else if sensors.thermalState == .serious { score -= 15 }
        else if sensors.thermalState == .fair { score -= 5 }
        
        if storage.usedPercentage > 95 { score -= 15 }
        else if storage.usedPercentage > 85 { score -= 5 }
        
        return max(score, 10)
    }
    
    public var healthStatusText: String {
        let score = healthScore
        if score >= 90 { return "Excellent" }
        if score >= 75 { return "Good" }
        if score >= 50 { return "Moderate Load" }
        return "Heavy Load"
    }
    
    public init() {}
}
