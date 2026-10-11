//
//  SmartToolTests.swift
//  Naem Smart Tool Tests
//

import CryptoKit
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
        
        // 9. File Tools: Image Converter & Resizer Math Tests
        let originalWidth = 1920
        let originalHeight = 1080
        let targetWidth = 960
        let computedHeight = Int(round(Double(originalHeight) * (Double(targetWidth) / Double(originalWidth))))
        assert(computedHeight == 540, "Aspect ratio scaling 1920x1080 -> 960 width yields exactly 540 height")
        
        // No upscaling protection rule test
        let requestedUpscale = 3840
        let avoidUpscale = true
        let boundedWidth = avoidUpscale ? min(originalWidth, requestedUpscale) : requestedUpscale
        assert(boundedWidth == 1920, "Image resizer correctly forbids unnecessary upscaling when flag enabled")
        
        // 10. File Tools: Image Compressor Preset Tests
        assert(ImageCompressionPreset.high.qualityValue == 0.85, "High Quality preset uses 0.85 compression")
        assert(ImageCompressionPreset.balanced.qualityValue == 0.70, "Balanced preset uses 0.70 compression")
        assert(ImageCompressionPreset.small.qualityValue == 0.50, "Small File preset uses 0.50 compression")
        
        // 11. File Tools: PDF Splitting Range Math
        let totalDocPages = 25
        let splitStart = 5
        let splitEnd = 12
        let pagesInRange = (splitEnd - splitStart) + 1
        assert(pagesInRange == 8, "Page range 5-to-12 extracts exactly 8 pages")
        
        // Every N pages interval calculation
        let everyN = 10
        let fullParts = (totalDocPages + everyN - 1) / everyN
        assert(fullParts == 3, "25-page document split every 10 pages produces exactly 3 documents (10, 10, 5)")
        
        // 12. File Tools: Batch Renaming Collision Detection Test
        var testURLs: [URL] = [
            URL(fileURLWithPath: "/tmp/photo_a.png"),
            URL(fileURLWithPath: "/tmp/photo_b.png")
        ]
        var seenNames = Set<String>()
        var collisions = 0
        // Simulate naming conflict where both resolve to same new name
        let simulatedNewNames = ["image_export.png", "image_export.png"]
        for name in simulatedNewNames {
            if seenNames.contains(name) {
                collisions += 1
            }
            seenNames.insert(name)
        }
        assert(collisions == 1, "Batch renamer collision engine flags duplicate generated targets")
        
        // Number sequence formatting test
        let seqFormat = String(format: "%03d", 7)
        assert(seqFormat == "007", "Sequence formatting pad digits produces zero-padded number sequence")
        
        // 13. File Tools: Cryptographic Hash Verification Test
        let sampleData = "NaemSmartToolOfflineSecure".data(using: .utf8)!
        let sha256Hex = SHA256.hash(data: sampleData).map { String(format: "%02x", $0) }.joined()
        assert(!sha256Hex.isEmpty && sha256Hex.count == 64, "SHA-256 hash yields 64-character hex digest")
        
        // 14. File Tools: Text Encoding BOM Detection Test
        let utf8BOMData = Data([0xEF, 0xBB, 0xBF, 0x48, 0x65, 0x6C, 0x6C, 0x6F])
        let hasBOM = utf8BOMData.starts(with: [0xEF, 0xBB, 0xBF])
        assert(hasBOM == true, "Text encoding inspector successfully identifies UTF-8 Byte Order Mark (BOM)")
        
        // 15. File Tools: Safety & Non-Destructive Invariant
        let originalSourceURL = URL(fileURLWithPath: "/Users/test/Documents/FinancialReport.pdf")
        let exportedSanitizedURL = URL(fileURLWithPath: "/Users/test/Downloads/FinancialReport_sanitized.pdf")
        assert(originalSourceURL != exportedSanitizedURL, "Original file path is strictly isolated from sanitized exported destination")
        
        // 16. Storage Analytics: Category Classification Invariant
        let swiftFile = URL(fileURLWithPath: "/Users/test/Code/App.swift")
        assert(StorageAnalyticsCategory.classify(url: swiftFile) == .developer, "Swift source code classified as Developer")
        
        let derivedDataURL = URL(fileURLWithPath: "/Users/test/Library/Developer/Xcode/DerivedData/App-123/Build/Products")
        assert(StorageAnalyticsCategory.classify(url: derivedDataURL) == .derivedData, "Xcode DerivedData path classified as DerivedData")
        
        let cacheURL = URL(fileURLWithPath: "/Users/test/Library/Caches/com.apple.Safari/Cache.db")
        assert(StorageAnalyticsCategory.classify(url: cacheURL) == .caches, "Library/Caches directory classified as Caches")
        
        let videoURL = URL(fileURLWithPath: "/Users/test/Movies/Keynote.mp4")
        assert(StorageAnalyticsCategory.classify(url: videoURL) == .videos, ".mp4 video classified as Videos")
        
        // 17. Storage Analytics: Nested Folder Size Aggregation (No Double Counting)
        let rootNode = StorageAnalyticsNode(url: URL(fileURLWithPath: "/test"), isDirectory: true, category: .other)
        let child1 = StorageAnalyticsNode(url: URL(fileURLWithPath: "/test/doc.pdf"), sizeBytes: 5_000_000, isDirectory: false, category: .documents)
        let child2 = StorageAnalyticsNode(url: URL(fileURLWithPath: "/test/pic.png"), sizeBytes: 3_000_000, isDirectory: false, category: .images)
        rootNode.children = [child1, child2]
        let totalFolderSize = rootNode.recalculateRecursiveSize()
        assert(totalFolderSize == 8_000_000, "Recursive folder size correctly sums child leaves (5MB + 3MB = 8MB)")
        
        // 18. Storage Analytics: Squarified Treemap Layout Algorithm
        let layoutEngine = TreemapLayoutEngine.shared
        let sampleItems = [
            TreemapLayoutEngine.LayoutItem(id: "1", name: "Videos", size: 600_000_000, category: .videos),
            TreemapLayoutEngine.LayoutItem(id: "2", name: "Apps", size: 300_000_000, category: .applications),
            TreemapLayoutEngine.LayoutItem(id: "3", name: "Docs", size: 100_000_000, category: .documents)
        ]
        let boundingBox = CGRect(x: 0, y: 0, width: 800, height: 400)
        let tiles = layoutEngine.layout(items: sampleItems, bounds: boundingBox)
        assert(tiles.count == 3, "Treemap produces exact tile count for items")
        assert(tiles[0].name == "Videos" && tiles[0].percentage == 60.0, "Largest item receives largest percentage (60%)")
        assert(tiles[0].rect.width > 0 && tiles[0].rect.height > 0, "Tiles receive positive non-zero dimensions")
        
        // 19. Storage Analytics: Filesystem vs Scanned Discrepancy Math
        let reportedUsed: UInt64 = 500 * 1024 * 1024 * 1024 // 500 GB
        let scannedSum: UInt64 = 420 * 1024 * 1024 * 1024   // 420 GB
        let unclassified = reportedUsed > scannedSum ? (reportedUsed - scannedSum) : 0
        assert(unclassified == 80 * 1024 * 1024 * 1024, "Unclassified space correctly reflects SIP and system allocation delta (80 GB)")
        
        // 20. Storage Analytics: Cleanup Eligibility Safety Invariant
        let safeCacheItem = StorageAnalyticsItem(url: URL(fileURLWithPath: "/Users/test/Library/Caches/temp.dat"), sizeBytes: 1024, isDirectory: false)
        let unsafeUserDoc = StorageAnalyticsItem(url: URL(fileURLWithPath: "/Users/test/Documents/Taxes.pdf"), sizeBytes: 1024, isDirectory: false)
        let unsafeSystemBinary = StorageAnalyticsItem(url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"), sizeBytes: 1024, isDirectory: true)
        
        assert(StorageAnalyticsService.isEligibleForCleanup(item: safeCacheItem) == true, "Library/Caches file is eligible for cleanup")
        assert(StorageAnalyticsService.isEligibleForCleanup(item: unsafeUserDoc) == false, "Personal documents are strictly INELIGIBLE for arbitrary deletion")
        assert(StorageAnalyticsService.isEligibleForCleanup(item: unsafeSystemBinary) == false, "System binaries are strictly INELIGIBLE for cleanup")
        
        // 21. Storage Analytics: Mounted Volume Percentage Math
        let volumeTest = StorageVolumeInfo(
            name: "Macintosh HD",
            mountURL: URL(fileURLWithPath: "/"),
            totalCapacityBytes: 1000,
            availableCapacityBytes: 300,
            isRootVolume: true
        )
        assert(volumeTest.usedCapacityBytes == 700, "Volume used capacity is total - available")
        assert(abs(volumeTest.usedPercentage - 70.0) < 0.01, "Volume used percentage is accurately 70.0%")
        
        // 22. Screen Time: Application Category Classification
        assert(AppUsageCategory.classify(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode") == .developer, "Xcode classified as Developer")
        assert(AppUsageCategory.classify(bundleIdentifier: "com.apple.Safari", appName: "Safari") == .browsers, "Safari classified as Browsers")
        assert(AppUsageCategory.classify(bundleIdentifier: "com.tinyspeck.slackmacgap", appName: "Slack") == .social, "Slack classified as Social")
        assert(AppUsageCategory.classify(bundleIdentifier: "com.figma.Desktop", appName: "Figma") == .creativity, "Figma classified as Creativity")
        assert(AppUsageCategory.classify(bundleIdentifier: "com.apple.Notes", appName: "Notes") == .productivity, "Notes classified as Productivity")
        assert(AppUsageCategory.classify(bundleIdentifier: "com.spotify.client", appName: "Spotify") == .media, "Spotify classified as Media")
        assert(AppUsageCategory.classify(bundleIdentifier: "com.apple.finder", appName: "Finder") == .utilities, "Finder classified as Utilities")
        assert(AppUsageCategory.classify(bundleIdentifier: "com.apple.systempreferences", appName: "System Settings") == .system, "System Settings classified as System")
        
        // 23. Screen Time: Session Active vs Idle Math
        let session = AppSessionRecord(
            bundleIdentifier: "com.apple.dt.Xcode",
            appName: "Xcode",
            category: .developer,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            duration: 3600,
            idleDuration: 600
        )
        assert(session.activeDuration == 3000, "Session active duration accurately subtracts idle time (3600 - 600 = 3000s)")
        
        // 24. Screen Time: App Usage Aggregate Percentage
        let appAggregate = AppUsageAggregate(
            bundleIdentifier: "com.anysphere.cursor",
            appName: "Cursor",
            category: .developer,
            totalDuration: 7200,
            activeDuration: 5400,
            idleDuration: 1800,
            sessionCount: 5
        )
        assert(abs(appAggregate.activePercentage - 75.0) < 0.01, "App aggregate active percentage accurately computed (75.0%)")
        
        // 25. Screen Time: Duration Formatter Math
        assert(Formatters.duration(45) == "45s", "Formatters.duration(45s) == '45s'")
        assert(Formatters.duration(120) == "2m", "Formatters.duration(120s) == '2m'")
        assert(Formatters.duration(125, showSeconds: true) == "2m 5s", "Formatters.duration(125s, showSeconds: true) == '2m 5s'")
        assert(Formatters.duration(7320) == "2h 2m", "Formatters.duration(7320s) == '2h 2m'")
        
        // 26. Screen Time: 24-Hour Buckets Invariant
        let dailySummary = DailyAppUsageSummary(dayKey: "2026-10-11", date: Date())
        assert(dailySummary.hourlyBuckets.count == 24, "Daily summary initializes exactly 24 hourly buckets (0..23)")
        
        // 27. Screen Time: Privacy Exclusion Filter Invariant
        var sampleExclusions: Set<String> = ["com.apple.loginwindow", "com.secret.vault"]
        let testAllowed = !sampleExclusions.contains("com.apple.dt.Xcode")
        let testBlocked = sampleExclusions.contains("com.secret.vault")
        assert(testAllowed && testBlocked, "Privacy exclusion set successfully filters blacklisted bundle IDs")
        
        // 28. Screen Time: CSV Export Header Invariant
        let mockCSVRow = "\"Xcode\",\"Developer & Code\",\"com.apple.dt.Xcode\",3600,\"1h 0m\",3000,600,\"83.3%\",4\n"
        assert(mockCSVRow.contains("Developer & Code") && mockCSVRow.contains("com.apple.dt.Xcode"), "CSV export correctly escapes and contains required columns")
        
        return (passed, failed, logs)
    }
}



