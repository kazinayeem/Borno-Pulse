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

public final class MockSensorProvider: @unchecked Sendable {
    public var simulateMissingSensors: Bool
    public var simulateThrottling: Bool
    
    public init(simulateMissingSensors: Bool = true, simulateThrottling: Bool = false) {
        self.simulateMissingSensors = simulateMissingSensors
        self.simulateThrottling = simulateThrottling
    }
    
    public func sample() -> SensorMetrics {
        var metrics = SensorMetrics()
        metrics.thermalState = simulateThrottling ? .serious : .nominal
        metrics.thermalStateDescription = simulateThrottling ? "Serious (Throttling Active)" : "Nominal"
        metrics.isThrottling = simulateThrottling
        
        if simulateMissingSensors {
            metrics.temperatureState = .unavailable(reason: "Direct diode query sandboxed on Apple Silicon")
            metrics.fansState = .unavailable(reason: "SMC fan telemetry managed by coprocessor")
        } else {
            metrics.cpuTemperature = 48.5
            metrics.gpuTemperature = 45.0
            metrics.fanSpeeds = [FanInfo(id: 0, name: "Fan #1", speedRPM: 1250)]
            metrics.temperatureState = .available
            metrics.fansState = .available
        }
        return metrics
    }
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
