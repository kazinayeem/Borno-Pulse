//
//  MockProviders.swift
//  Borno Pulse Tests
//

import Foundation

public final class MockCPUProvider: @unchecked Sendable {
    public var simulatedModel: String
    public var simulatedArchitecture: String
    public var simulatedCoreCount: Int
    public var simulatedTotalUsage: Double
    
    public init(
        model: String = "Apple M4 Pro",
        architecture: String = "arm64",
        coreCount: Int = 12,
        totalUsage: Double = 18.5
    ) {
        self.simulatedModel = model
        self.simulatedArchitecture = architecture
        self.simulatedCoreCount = coreCount
        self.simulatedTotalUsage = totalUsage
    }
    
    public func sample() -> CPUMetrics {
        var metrics = CPUMetrics()
        metrics.modelName = simulatedModel
        metrics.architecture = simulatedArchitecture
        metrics.physicalCoreCount = simulatedCoreCount
        metrics.logicalCoreCount = simulatedCoreCount
        metrics.totalUsage = min(max(simulatedTotalUsage, 0.0), 100.0)
        metrics.userUsage = simulatedTotalUsage * 0.7
        metrics.systemUsage = simulatedTotalUsage * 0.3
        metrics.idleUsage = 100.0 - simulatedTotalUsage
        metrics.perCoreUsage = Array(repeating: simulatedTotalUsage, count: simulatedCoreCount)
        metrics.state = .available
        return metrics
    }
}

/// Test-only sensor provider. Feeds mocked reader responses through the production
/// `SensorMetricsBuilder`, so tests exercise the real classification logic.
public final class MockSensorProvider: @unchecked Sendable {
    public var simulateMissingSensors: Bool
    public var simulateThrottling: Bool
    public var hidResult: SensorReadResult
    public var smcResult: SensorReadResult
    public var fanResult: FanReadResult
    
    public init(simulateMissingSensors: Bool = true, simulateThrottling: Bool = false) {
        self.simulateMissingSensors = simulateMissingSensors
        self.simulateThrottling = simulateThrottling
        self.hidResult = .values(Self.appleSiliconHIDFixture)
        self.smcResult = .values(Self.appleSiliconSMCFixture)
        self.fanResult = .fans(reportedCount: 1, readings: [RawFanValue(index: 0, rpm: 2150, minRPM: 1200, maxRPM: 5800)])
    }
    
    public func sample(now: Date = Date()) -> SensorMetrics {
        let thermalState: ProcessInfo.ThermalState = simulateThrottling ? .serious : .nominal
        if simulateMissingSensors {
            return SensorMetricsBuilder.build(
                thermalState: thermalState,
                hid: .unavailable(reason: "HID temperature services returned no events."),
                smc: .unavailable(reason: "macOS denied access to the SMC."),
                fans: .unavailable(reason: "macOS denied access to the SMC."),
                isAppleSilicon: true,
                now: now
            )
        }
        return SensorMetricsBuilder.build(
            thermalState: thermalState,
            hid: hidResult,
            smc: smcResult,
            fans: fanResult,
            isAppleSilicon: true,
            now: now
        )
    }

    // MARK: - Fixtures (shapes match what an M4 MacBook Air returns; values are test data)

    /// SMC response: CPU P/E-cluster keys, GPU keys, battery keys, and keys that must stay unclassified.
    public static let appleSiliconSMCFixture: [RawTemperatureValue] = [
        RawTemperatureValue(key: "Tp01", name: "CPU performance cluster (Tp01)", celsius: 64.0, source: .smc),
        RawTemperatureValue(key: "Tp05", name: "CPU performance cluster (Tp05)", celsius: 68.0, source: .smc),
        RawTemperatureValue(key: "Te05", name: "CPU efficiency cluster (Te05)", celsius: 54.0, source: .smc),
        RawTemperatureValue(key: "Tg0G", name: "GPU (Tg0G)", celsius: 47.0, source: .smc),
        RawTemperatureValue(key: "Tg0H", name: "GPU (Tg0H)", celsius: 51.0, source: .smc),
        RawTemperatureValue(key: "TB0T", name: "Battery pack (TB0T)", celsius: 31.0, source: .smc),
        RawTemperatureValue(key: "TG0B", name: "TG0B", celsius: 33.0, source: .smc),
        RawTemperatureValue(key: "Ts00", name: "Ts00", celsius: 47.7, source: .smc)
    ]

    /// HID response: unattributed PMU sensors, a disconnected thermistor, a calibration
    /// reference, battery gas-gauge sensors and the SSD NAND sensor. No CPU/GPU-named sensors.
    public static let appleSiliconHIDFixture: [RawTemperatureValue] = [
        RawTemperatureValue(key: "PMU tdie1#0x54503162", name: "PMU tdie1", celsius: 46.5, source: .hidEventSystem),
        RawTemperatureValue(key: "PMU2 tdie1#0x54523162", name: "PMU2 tdie1", celsius: 43.3, source: .hidEventSystem),
        RawTemperatureValue(key: "PMU tdev1#0x54503164", name: "PMU tdev1", celsius: -21.99, source: .hidEventSystem),
        RawTemperatureValue(key: "PMU tcal#0x5450305a", name: "PMU tcal", celsius: 51.8, source: .hidEventSystem),
        RawTemperatureValue(key: "gas gauge battery#0x54473042", name: "gas gauge battery", celsius: 33.3, source: .hidEventSystem),
        RawTemperatureValue(key: "gas gauge battery#0x54473043", name: "gas gauge battery", celsius: 33.0, source: .hidEventSystem),
        RawTemperatureValue(key: "NAND CH0 temp#0x544e306e", name: "NAND CH0 temp", celsius: 41.0, source: .hidEventSystem)
    ]
}

public final class MockStorageProvider: @unchecked Sendable {
    public var totalBytes: UInt64
    public var usedBytes: UInt64
    public var purgeableBytes: UInt64
    
    public init(
        totalBytes: UInt64 = 512 * 1024 * 1024 * 1024,
        usedBytes: UInt64 = 400 * 1024 * 1024 * 1024,
        purgeableBytes: UInt64 = 30 * 1024 * 1024 * 1024
    ) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.purgeableBytes = purgeableBytes
    }
    
    public func sample() -> StorageMetrics {
        var metrics = StorageMetrics()
        let free = totalBytes > usedBytes ? (totalBytes - usedBytes) : 0
        let vol = StorageVolume(
            name: "Macintosh HD",
            mountPoint: "/",
            fileSystem: "APFS",
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            freeBytes: free,
            purgeableBytes: purgeableBytes,
            isSystem: true
        )
        metrics.volumes = [vol]
        metrics.primaryVolume = vol
        metrics.totalCapacityBytes = totalBytes
        metrics.usedCapacityBytes = usedBytes
        metrics.availableCapacityBytes = free
        metrics.purgeableBytes = purgeableBytes
        metrics.state = .available
        return metrics
    }
}
