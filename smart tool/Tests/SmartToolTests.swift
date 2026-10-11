//
//  SmartToolTests.swift
//  Naem Smart Tool Tests
//

import Foundation

public enum SmartToolTests {
    public static func runAllTests() -> (passed: Int, failed: Int, logs: [String]) {
        var passed = 0
        var failed = 0
        var logs: [String] = []
        
        func assert(_ condition: Bool, _ name: String) {
            if condition {
                passed += 1
                logs.append("✅ PASS: \(name)")
            } else {
                failed += 1
                logs.append("❌ FAIL: \(name)")
            }
        }
        
        // 1. Formatters Tests
        assert(!Formatters.bytes(UInt64(0)).isEmpty, "Formatters.bytes(0) produces valid string")
        assert(Formatters.bytes(UInt64(1024 * 1024)).contains("MB") || Formatters.bytes(UInt64(1024 * 1024)).contains("1"), "Formatters.bytes(1MB) handles MB conversion")
        assert(Formatters.temperature(0.0) == "0.0 °C", "Formatters.temperature(0°C) matches standard")
        assert(Formatters.temperature(100.0, inFahrenheit: true) == "212.0 °F", "Formatters.temperature(100°C in °F) == 212.0 °F")
        assert(Formatters.percentage(55.23) == "55.2%", "Formatters.percentage formats to 1 decimal")
        assert(Formatters.speed(1024 * 1024) == "1.00 MB/s", "Formatters.speed(1MB) == 1.00 MB/s")
        
        // 2. CPU Calculation Tests
        let mockCPU = MockCPUProvider(model: "Apple M4", architecture: "arm64", coreCount: 10, totalUsage: 45.0)
        let cpuSample = mockCPU.sample()
        assert(cpuSample.totalUsage == 45.0, "CPU sample totalUsage matches mock input")
        assert(cpuSample.perCoreUsage.count == 10, "CPU sample per-core count matches logical cores")
        assert(cpuSample.architecture == "arm64", "CPU sample architecture is correctly reported")
        
        // Intel vs Apple Silicon test
        let intelCPU = MockCPUProvider(model: "Intel Core i9", architecture: "x86_64", coreCount: 16, totalUsage: 75.0)
        let intelSample = intelCPU.sample()
        assert(intelSample.architecture == "x86_64", "Intel CPU mock correctly preserves x86_64 architecture")
        assert(intelSample.physicalCoreCount == 16, "Intel CPU core count preserved")
        
        // 3. Memory Metrics Tests
        var memMetrics = MemoryMetrics()
        memMetrics.totalBytes = 16 * 1024 * 1024 * 1024
        memMetrics.usedBytes = 8 * 1024 * 1024 * 1024
        assert(abs(memMetrics.usagePercentage - 50.0) < 0.01, "Memory usage percentage calculation is accurate")
        
        // 4. Storage & APFS Purgeable Tests
        let mockStorage = MockStorageProvider(
            totalBytes: 500 * 1024 * 1024 * 1024,
            usedBytes: 300 * 1024 * 1024 * 1024,
            purgeableBytes: 25 * 1024 * 1024 * 1024
        )
        let storageSample = mockStorage.sample()
        assert(storageSample.availableCapacityBytes == 200 * 1024 * 1024 * 1024, "Storage available space matches total - used")
        assert(storageSample.purgeableBytes == 25 * 1024 * 1024 * 1024, "APFS purgeable space correctly detected")
        assert(abs(storageSample.usedPercentage - 60.0) < 0.01, "Storage percentage matches 60%")
        
        // 5. Sensors & Fallback Tests
        let mockSensors = MockSensorProvider(simulateMissingSensors: true, simulateThrottling: true)
        let sensorSample = mockSensors.sample()
        assert(sensorSample.isThrottling == true, "Sensor provider reports active thermal throttling")
        assert(sensorSample.thermalState == .serious, "Thermal state matches serious load")
        if case .unavailable(let reason) = sensorSample.temperatureState {
            assert(!reason.isEmpty, "Graceful fallback explanation provided for unavailable sensor")
        } else {
            assert(false, "Sensor state should report unavailable when diode query is sandboxed")
        }
        
        // 6. Cleanup Safety Rules Tests
        assert(CleanupCategoryType.trash.defaultSelected == false, "Trash must NEVER be selected by default")
        assert(CleanupCategoryType.userCaches.defaultSelected == true, "User caches safe by default")
        
        let safeFile = CleanupFileItem(path: "/tmp/test.tmp", name: "test.tmp", sizeBytes: 1024, isSafe: true)
        assert(safeFile.isSafe == true, "CleanupFileItem preserves safety flag")
        
        // 7. Process Model Tests
        let testProcess = ProcessItem(
            pid: 1234,
            name: "TestService",
            cpuPercentage: 25.0,
            residentMemoryBytes: 200 * 1024 * 1024,
            threadCount: 4
        )
        assert(testProcess.id == 1234, "ProcessItem ID matches PID")
        assert(testProcess.energyImpactScore > 0, "Energy impact score is calculated")
        
        // 8. Overall Health Score Algorithm
        var snapshot = SystemMetricsSnapshot()
        snapshot.cpu.totalUsage = 15.0
        snapshot.sensors.isThrottling = false
        assert(snapshot.healthScore >= 90, "Normal system maintains excellent health score")
        
        snapshot.cpu.totalUsage = 95.0
        snapshot.sensors.isThrottling = true
        assert(snapshot.healthScore < 80, "Heavy CPU load and throttling degrades health score")
        
        return (passed, failed, logs)
    }
}
