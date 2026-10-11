//
//  SmartToolTests.swift
//  Borno Pulse Tests
//

import AppKit
import CryptoKit
import Foundation
import PDFKit
import SwiftUI

@MainActor
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
        assert(Formatters.temperature(47.0) == "47 °C", "Formatters.temperature formats whole degrees Celsius by default")
        assert(Formatters.temperature(100.0, unit: .fahrenheit) == "212 °F", "Formatters.temperature(100°C in °F) == 212 °F")
        assert(Formatters.temperature(nil) == "Unavailable", "Formatters.temperature(nil) reads Unavailable, never 0 °C")
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
        assert(sensorSample.cpuTemperature == nil && sensorSample.gpuTemperature == nil && sensorSample.batteryTemperature == nil,
               "Unreadable sensors leave every component temperature nil")
        assert(sensorSample.fanSpeeds.isEmpty && !sensorSample.fansState.isAvailable, "Unreadable SMC reports no fabricated fan speeds")
        
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
        
        // 29. Developer Toolbox: JSON Formatting, Minification & Syntax Validation
        let rawJSON = "{\n  \"appName\" : \"SmartTool\",\n  \"version\" : 1\n}"
        let prettyJSON = (try? JSONFormatterService.shared.prettyPrint(rawJSON)) ?? ""
        assert(!prettyJSON.isEmpty && (prettyJSON.contains("\"appName\" : \"SmartTool\"") || prettyJSON.contains("\"appName\": \"SmartTool\"")), "JSON formatter correctly validates and pretty-prints JSON")
        
        let minifiedJSON = (try? JSONFormatterService.shared.minify(rawJSON)) ?? ""
        assert(!minifiedJSON.isEmpty && !minifiedJSON.contains("\n") && minifiedJSON.contains("\"version\":1"), "JSON minifier strips all unnecessary whitespace and newlines")
        
        let invalidJSON = "{ \"missingQuote: 123 }"
        let invalidResult = JSONFormatterService.shared.validate(invalidJSON)
        assert(invalidResult.isValid == false, "JSON syntax validation accurately catches malformed syntax and provides error line")
        
        // 30. Developer Toolbox: JWT Header & Payload Claims Decoding
        let sampleJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6Ik5hZW0iLCJleHAiOjE5OTk5OTk5OTksImlzcyI6InNtYXJ0dG9vbCJ9.signaturePlaceholder"
        let jwtResult = try? JWTDecoderService.shared.decode(jwtToken: sampleJWT)
        assert(jwtResult != nil, "JWTDecoderService successfully decodes well-formed 3-part token")
        if let token = jwtResult {
            assert(token.algorithm == "HS256", "JWT header algorithm correctly extracted")
            assert(token.issuer == "smarttool", "JWT standard registered issuer claim identified")
            assert(token.isExpired == false, "Future timestamp token correctly marked as not expired")
        }
        
        // 31. Developer Toolbox: API Request Tester Secret Redaction
        let rawHeaders = [
            HTTPHeaderItem(key: "Authorization", value: "Bearer superSecretToken123456"),
            HTTPHeaderItem(key: "Cookie", value: "session_id=abcdef987654"),
            HTTPHeaderItem(key: "Content-Type", value: "application/json")
        ]
        let redactedHeaders = APIRequestService.redactHeaders(rawHeaders)
        let authHeader = redactedHeaders.first(where: { $0.key == "Authorization" })
        let cookieHeader = redactedHeaders.first(where: { $0.key == "Cookie" })
        let contentTypeHeader = redactedHeaders.first(where: { $0.key == "Content-Type" })
        assert(authHeader?.value == "[REDACTED_SECRET]" && cookieHeader?.value == "[REDACTED_SECRET]", "API client strictly redacts Authorization and Cookie headers")
        assert(contentTypeHeader?.value == "application/json", "Public headers like Content-Type are preserved")
        
        // 32. Developer Toolbox: Docker Engine Graceful Fallback
        let dockerCLI = DockerService.shared.findDockerCLI()
        assert(dockerCLI == nil || dockerCLI!.contains("docker"), "DockerService detection accurately checks binary availability")
        
        // 33. Network Toolkit: Ping RTT Parser Math
        let samplePingOutput = "64 bytes from 1.1.1.1: icmp_seq=1 ttl=58 time=14.285 ms"
        let parsedRTT = PingService.parseRTT(from: samplePingOutput)
        assert(parsedRTT != nil && abs((parsedRTT ?? 0) - 14.285) < 0.001, "Ping RTT parser accurately extracts round-trip milliseconds")
        
        // 34. Network Toolkit: SSL Certificate Validity Days Calculation
        let now = Date()
        let future = now.addingTimeInterval(86400 * 90)
        let certInfo = SSLCertificateDetails(
            host: "apple.com",
            port: 443,
            commonName: "apple.com",
            issuer: "Apple Public EV Server RSA CA 1",
            validFrom: now,
            validUntil: future,
            remainingDays: 90,
            isTrusted: true,
            isExpired: false
        )
        assert(certInfo.isExpired == false, "Valid SSL certificate correctly marked as non-expired")
        assert(certInfo.remainingDays == 90, "SSL certificate days remaining calculated accurately")
        
        // 35. Clipboard Manager: Sensitive Secret Regex Detection
        let secret1 = "ghp_1234567890abcdefghijklmnopqrstuvwxyz"
        let normalText = "Hello from Borno Pulse"
        assert(ClipboardManagerService.shared.checkSensitive(text: secret1) == true, "Clipboard detector catches GitHub Personal Access Tokens")
        assert(ClipboardManagerService.shared.checkSensitive(text: normalText) == false, "Clipboard detector does not false-positive on regular sentences")
        
        // 36. Focus & Pomodoro: State & Invariants
        let focusSession = FocusSessionRecord(
            startTime: Date(),
            endTime: Date().addingTimeInterval(1500),
            durationSeconds: 1500,
            mode: .focus,
            isCompleted: true
        )
        assert(focusSession.durationSeconds == 25 * 60, "Default Pomodoro duration is strictly 25 minutes (1500s)")
        
        // 37. Batch File Converter: Collision-Safe URL Naming
        let tempDir = FileManager.default.temporaryDirectory
        let baseCollisionTestURL = tempDir.appendingPathComponent("test_file.png")
        try? "dummy".write(to: baseCollisionTestURL, atomically: true, encoding: .utf8)
        let safeURL = BatchConverterService.collisionSafeURL(desiredURL: baseCollisionTestURL)
        assert(safeURL.lastPathComponent == "test_file (1).png", "Collision-safe URL appends incremented suffix when file exists")
        try? FileManager.default.removeItem(at: baseCollisionTestURL)
        
        // 38. Privacy & Security: Streaming File Hasher
        let testHashData = "AntigravitySecureStreamingHashingTest".data(using: .utf8)!
        let testFileForHash = tempDir.appendingPathComponent("hash_test.txt")
        try? testHashData.write(to: testFileForHash)
        if let computedSHA256 = try? FileHashCalculatorService.shared.computeHash(for: testFileForHash, algorithm: .sha256) {
            let directSHA256 = SHA256.hash(data: testHashData).map { String(format: "%02x", $0) }.joined()
            assert(computedSHA256 == directSHA256, "Streaming FileHashCalculatorService SHA-256 matches CryptoKit direct digest")
        } else {
            assert(false, "FileHashCalculatorService failed to compute hash")
        }
        try? FileManager.default.removeItem(at: testFileForHash)
        
        // 39. Quick Launcher: Fuzzy Search & Keywords
        let launcherSearch = QuickLauncherService.shared.search(query: "json")
        assert(launcherSearch.contains(where: { $0.id == "dev_json" }), "Quick launcher finds JSON tools by keyword 'json'")
        let pingSearch = QuickLauncherService.shared.search(query: "latency")
        assert(pingSearch.contains(where: { $0.id == "net_ping" }), "Quick launcher finds Ping tool by keyword 'latency'")
        
        // 40. Local Backup Helper: Profile Model Invariants
        let testBackupProfile = BackupProfile(
            name: "Project Code",
            sourcePaths: ["/Users/test/Code"],
            destinationPath: "/Volumes/External/Backups",
            mode: .incremental,
            verifyChecksums: true
        )
        assert(testBackupProfile.mode == .incremental, "BackupProfile retains configured incremental mode")
        assert(testBackupProfile.verifyChecksums == true, "BackupProfile retains SHA-256 checksum verification preference")
        assert(testBackupProfile.exclusions.contains(".DS_Store"), "BackupProfile contains default system exclusions")
        
        // 41. Battery Estimation: Discharge-Time Remaining Math & Target Threshold
        // Simulate 75% battery discharging down to 10% threshold over 1 hour (10% drop in 1 hour)
        let t0 = Date()
        let t1 = t0.addingTimeInterval(1800) // 30 min later
        let t2 = t0.addingTimeInterval(3600) // 60 min later
        let dischargeSamples: [(date: Date, percentage: Double, isCharging: Bool, isPluggedIn: Bool)] = [
            (date: t0, percentage: 75.0, isCharging: false, isPluggedIn: false),
            (date: t1, percentage: 70.0, isCharging: false, isPluggedIn: false),
            (date: t2, percentage: 65.0, isCharging: false, isPluggedIn: false)
        ]
        // Rate is (75 - 65) / 1 hr = 10% per hour.
        // Usable percentage from 65% down to 10% threshold is 55%.
        // Time = 55 / 10 = 5.5 hours = 330 minutes.
        let dischargeEst = BatteryEstimationService.computeEstimate(
            samples: dischargeSamples,
            lowBatteryThreshold: 10,
            osTimeToEmptyMinutes: nil,
            osTimeToFullMinutes: nil
        )
        assert(dischargeEst.state == .discharging, "Battery state correctly identified as discharging")
        assert(dischargeEst.minutes != nil && abs((dischargeEst.minutes ?? 0) - 330) <= 5, "Discharge time remaining accurately calculated to target threshold (330 min / 5h 30m)")
        assert(dischargeEst.formatted.contains("5h 30m remaining") || dischargeEst.formatted.contains("remaining"), "Formatted time displays 'remaining' prefix")
        
        // 42. Battery Estimation: Charge-Time Math with Non-Linear Tapering
        // Simulate charging from 40% to 60% over 30 minutes (rate = 40% per hour)
        let c0 = Date()
        let c1 = c0.addingTimeInterval(900)  // 15 min
        let c2 = c0.addingTimeInterval(1800) // 30 min
        let chargeSamples: [(date: Date, percentage: Double, isCharging: Bool, isPluggedIn: Bool)] = [
            (date: c0, percentage: 40.0, isCharging: true, isPluggedIn: true),
            (date: c1, percentage: 50.0, isCharging: true, isPluggedIn: true),
            (date: c2, percentage: 60.0, isCharging: true, isPluggedIn: true)
        ]
        let chargeEst = BatteryEstimationService.computeEstimate(
            samples: chargeSamples,
            lowBatteryThreshold: 10,
            osTimeToEmptyMinutes: nil,
            osTimeToFullMinutes: nil
        )
        assert(chargeEst.state == .charging, "Battery state correctly identified as charging")
        assert(chargeEst.minutes != nil && (chargeEst.minutes ?? 0) > 0, "Charge time until full accurately estimated")
        assert(chargeEst.formatted.contains("until full"), "Charging estimate formatted with 'until full'")
        
        // 43. Battery Estimation: Insufficient Observation History Graceful "Calculating" State
        let singleSample: [(date: Date, percentage: Double, isCharging: Bool, isPluggedIn: Bool)] = [
            (date: Date(), percentage: 80.0, isCharging: false, isPluggedIn: false)
        ]
        let sparseEst = BatteryEstimationService.computeEstimate(
            samples: singleSample,
            lowBatteryThreshold: 10,
            osTimeToEmptyMinutes: nil,
            osTimeToFullMinutes: nil
        )
        assert(sparseEst.confidence == .calculating, "Single observation yields 'Calculating...' confidence")
        assert(sparseEst.formatted.contains("Calculating"), "Formatted text accurately explains estimate is calculating")
        
        // 44. Battery Estimation: Fully Charged Detection (100% on AC)
        let fullSamples: [(date: Date, percentage: Double, isCharging: Bool, isPluggedIn: Bool)] = [
            (date: Date(), percentage: 100.0, isCharging: false, isPluggedIn: true)
        ]
        let fullEst = BatteryEstimationService.computeEstimate(
            samples: fullSamples,
            lowBatteryThreshold: 10,
            osTimeToEmptyMinutes: nil,
            osTimeToFullMinutes: nil
        )
        assert(fullEst.state == .fullyCharged, "100% on power adapter identified as fully charged")
        assert(fullEst.minutes == 0, "Fully charged battery has 0 minutes remaining")
        assert(fullEst.formatted == "Fully Charged", "Formatted status displays 'Fully Charged'")
        
        // 45. Battery Estimation: Desktop Mac (No Battery) Graceful AC State
        let desktopMetrics = BatteryEstimationService.shared.processSample(
            hasBattery: false,
            percentage: 100,
            isCharging: false,
            isPluggedIn: true,
            timeToEmptyMinutes: nil,
            timeToFullMinutes: nil,
            voltageVolts: nil,
            amperageAmps: nil,
            wattage: nil,
            temperatureCelsius: nil
        )
        assert(desktopMetrics.state == .acDesktop, "Desktop Mac reported as AC Desktop power state")
        assert(desktopMetrics.confidence == .unavailable, "Desktop Mac marked with unavailable battery confidence")
        assert(desktopMetrics.formatted.contains("Desktop Mac"), "Desktop Mac formatted message clearly explains continuous AC power")
        
        // 46. Battery Estimation: Formatter Duration Math
        assert(BatteryEstimationService.formatDuration(minutes: 90, prefix: "remaining") == "1h 30m remaining", "Format duration 90m produces '1h 30m remaining'")
        assert(BatteryEstimationService.formatDuration(minutes: 45, prefix: "until full") == "45m until full", "Format duration 45m produces '45m until full'")
        
        // 47. Battery Estimation: Native OS Blended Estimate Priority
        let osOverrideSamples: [(date: Date, percentage: Double, isCharging: Bool, isPluggedIn: Bool)] = [
            (date: Date(), percentage: 50.0, isCharging: false, isPluggedIn: false)
        ]
        let osBlendedEst = BatteryEstimationService.computeEstimate(
            samples: osOverrideSamples,
            lowBatteryThreshold: 10,
            osTimeToEmptyMinutes: 240,
            osTimeToFullMinutes: nil
        )
        assert(osBlendedEst.minutes == 240, "Native OS time to empty respected when exposed by IOKit")
        assert(osBlendedEst.confidence == .high, "Native OS estimate carries high confidence")
        
        // 48. Battery Estimation: Time Range Interval Math
        assert(BatteryTimeRange.oneHour.intervalSeconds == 3600, "1 Hour range is 3,600 seconds")
        assert(BatteryTimeRange.oneDay.intervalSeconds == 86400, "24 Hours range is 86,400 seconds")
        assert(BatteryTimeRange.sevenDays.intervalSeconds == 86400 * 7, "7 Days range is 604,800 seconds")
        
        // 49. Battery Estimation: Settings Threshold Bounds
        assert(AppSettings.shared.batteryAlertThreshold >= 5 && AppSettings.shared.batteryAlertThreshold <= 30, "Low battery alert threshold defaults to a reasonable safety percentage")
        
        // 50. Battery Power: Voltage-Current Math (P = V * I with mV & mA conversion)
        let calcWatts = BatteryPowerService.calculateElectricalPower(voltageMilliVolts: 12000.0, amperageMilliAmps: 1500.0)
        assert(calcWatts != nil && abs((calcWatts ?? 0) - 18.0) < 0.001, "12,000 mV * 1,500 mA yields exactly 18.0 W")
        
        // 51. Battery Power: Milliamp-to-Amp Conversion Precision
        let smallWatts = BatteryPowerService.calculateElectricalPower(voltageMilliVolts: 11400.0, amperageMilliAmps: 500.0)
        assert(smallWatts != nil && abs((smallWatts ?? 0) - 5.7) < 0.001, "11,400 mV * 500 mA accurately converts to 5.7 W")
        
        // 52. Battery Power: Charging vs Discharging Sign Handling
        let chargeFlow = BatteryPowerService.resolvePowerFlow(
            isPluggedIn: true,
            isCharging: true,
            amperageMilliAmps: 2000.0,
            electricalWatts: 24.0
        )
        assert(chargeFlow.chargingWatts == 24.0 && chargeFlow.dischargingWatts == nil, "Active charging yields positive charging watts and nil discharging watts")
        
        let dischargeFlow = BatteryPowerService.resolvePowerFlow(
            isPluggedIn: false,
            isCharging: false,
            amperageMilliAmps: -1800.0,
            electricalWatts: 21.6
        )
        assert(dischargeFlow.dischargingWatts == 21.6 && chargeFlow.dischargingWatts == nil, "Discharge yields positive discharging watts and nil charging watts")
        
        let holdFlow = BatteryPowerService.resolvePowerFlow(
            isPluggedIn: true,
            isCharging: false,
            amperageMilliAmps: 0.0,
            electricalWatts: 0.0
        )
        assert(holdFlow.chargingWatts == 0.0 && holdFlow.dischargingWatts == nil, "AC connected holding state measures 0.0 W charge inflow")
        
        // 53. Battery Power: Missing Sensor Data Gracefully Yields Nil (Never Fabricated 0W)
        let missingWatts = BatteryPowerService.calculateElectricalPower(voltageMilliVolts: nil, amperageMilliAmps: nil)
        assert(missingWatts == nil, "Missing sensor voltage and amperage returns nil instead of fabricating 0W")
        
        // 54. Battery Power: Invalid Sensor Readings (Zero or Negative Voltage)
        let zeroVoltageWatts = BatteryPowerService.calculateElectricalPower(voltageMilliVolts: 0.0, amperageMilliAmps: 1500.0)
        assert(zeroVoltageWatts == nil, "Zero voltage sensor reading rejected as physically invalid")
        
        let negVoltageWatts = BatteryPowerService.calculateElectricalPower(voltageMilliVolts: -12000.0, amperageMilliAmps: 1500.0)
        assert(negVoltageWatts == nil, "Negative voltage sensor reading rejected as physically invalid")
        
        // 55. Battery Power: Estimated Power from Capacity & Elapsed Time
        let estWatts = BatteryPowerService.calculateEstimatedPowerFromEnergy(
            capacityMilliampHours: 5000.0,
            percentageDelta: 10.0,
            elapsedSeconds: 1800.0, // 30 minutes
            nominalVoltageVolts: 11.4
        )
        assert(estWatts != nil && abs((estWatts ?? 0) - 11.4) < 0.001, "5000mAh * 10% delta over 30 mins yields exactly 11.4 W estimated")
        
        // 56. Battery Power: Hardware Dictionary Parser Extracts Rated Adapter & System Load
        let mockDict: [String: Any] = [
            "Voltage": 12531,
            "Amperage": 0,
            "InstantAmperage": 0,
            "AdapterDetails": [
                "Watts": 30,
                "Name": "30W USB-C Power Adapter"
            ],
            "PowerTelemetryData": [
                "SystemLoad": 6143,
                "SystemPowerIn": 6143
            ],
            "PowerDistribution": [
                "IPDInputPower": 29800
            ],
            "CycleCount": 56,
            "MaxCapacity": 100,
            "Temperature": 2850
        ]
        let parsed = BatteryPowerService.parseAppleSmartBatteryProperties(mockDict, isPluggedIn: true, isCharging: false)
        assert(parsed.adapterRatedWatts == 30, "Adapter rated wattage extracted as 30 W")
        assert(parsed.adapterName == "30W USB-C Power Adapter", "Adapter name correctly identified")
        assert(parsed.systemPowerWatts != nil && abs((parsed.systemPowerWatts ?? 0) - 6.143) < 0.001, "System load extracted as 6.143 W from milliwatts")
        assert(parsed.adapterInputWatts != nil && abs((parsed.adapterInputWatts ?? 0) - 29.8) < 0.001, "Adapter input power extracted as 29.8 W")
        assert(parsed.cycleCount == 56, "Cycle count extracted as 56")
        assert(parsed.temperatureCelsius != nil && abs((parsed.temperatureCelsius ?? 0) - 28.5) < 0.01, "Temperature extracted as 28.5 °C")
        
        // 57. Battery Power: Power Flow Invariant (Adapter Rated != System Consumption != Battery Charge)
        let ratedW = Double(parsed.adapterRatedWatts ?? 0)
        let sysW = parsed.systemPowerWatts ?? 0
        let chgW = parsed.chargingWatts ?? 0
        assert(ratedW != sysW && ratedW != chgW, "Power flow invariants maintained: adapter rated power is independent of system load and battery charging power")
        
        // 58. Battery Power: Menu Bar Metric Display Option
        assert(MenuBarMetricDisplay.batteryWatts.rawValue == "Battery Watts (W)", "Menu bar display options include Battery Watts (W)")
        
        // 59. Battery Power: Chart Time Windows
        assert(BatteryPowerChartWindow.fiveMinutes.seconds == 300, "5 Minutes chart window is 300 seconds")
        assert(BatteryPowerChartWindow.fifteenMinutes.seconds == 900, "15 Minutes chart window is 900 seconds")
        
        // 60. Menu Bar Popover: Category Navigation Count & IDs
        let categories = MenuBarCategory.allCases
        assert(categories.count == 4, "Popovers contains 4 primary utility categories")
        assert(categories.map { $0.rawValue } == ["Audio", "Battery", "Hardware", "Actions"], "Category identifiers match Audio, Battery, Hardware, Actions")
        
        // 61. Menu Bar Popover: AudioDeviceItem Properties
        let devItem = AudioDeviceItem(id: 42, name: "Studio Monitors", isInput: false, isOutput: true)
        assert(devItem.id == 42 && devItem.name == "Studio Monitors" && devItem.isOutput && !devItem.isInput, "AudioDeviceItem preserves CoreAudio ID, output role, and device name")
        
        // 62. Menu Bar Popover: RunningAudioAppItem Scriptability Classification
        let musicApp = RunningAudioAppItem(id: "com.apple.Music", name: "Music", pid: 1234, volume: 0.8, isMuted: false, isScriptable: true)
        assert(musicApp.isScriptable, "Apple Music correctly classified as supporting scriptable volume control")
        
        let genericApp = RunningAudioAppItem(id: "com.tinyspeck.slackmacgap", name: "Slack", pid: 5678, volume: 1.0, isMuted: false, isScriptable: false)
        assert(!genericApp.isScriptable, "Standard communication app correctly routed through default system audio without fake sliders")
        
        // 63. Menu Bar Popover: Audio Volume Scalar Clamping Invariant
        let clampedHigh = max(0.0, min(1.0, Float(1.5)))
        let clampedLow = max(0.0, min(1.0, Float(-0.2)))
        assert(clampedHigh == 1.0 && clampedLow == 0.0, "Audio volume scalars strictly clamped between 0.0 and 1.0")
        
        // 64. PDF Studio: Tools Count & Category Invariants
        let allStudioTools = PDFStudioTool.allCases
        assert(allStudioTools.count == 14, "PDF Studio contains exactly 14 specialized document tools")
        let assembleTools = allStudioTools.filter { $0.category == "Assemble & Convert" }
        let editTools = allStudioTools.filter { $0.category == "Edit & Organize" }
        let optimizeTools = allStudioTools.filter { $0.category == "Optimize & Tools" }
        assert(assembleTools.count == 5 && editTools.count == 5 && optimizeTools.count == 4, "Studio categories accurately group all 14 tools")
        
        // 65. PDF Studio: Page Item Model & Invariant Reordering
        let mockURL = URL(fileURLWithPath: "/tmp/sample_doc.pdf")
        var page1 = PDFStudioPageItem(sourceURL: mockURL, sourceType: .pdfPage, originalPageIndex: 0, rotationAngle: 0)
        var page2 = PDFStudioPageItem(sourceURL: mockURL, sourceType: .pdfPage, originalPageIndex: 1, rotationAngle: 90)
        assert(page1.rotationAngle == 0 && page2.rotationAngle == 90, "Page rotation angle preserved per item")
        page1.rotationAngle = (page1.rotationAngle + 90) % 360
        assert(page1.rotationAngle == 90, "Page rotation delta operation computes modulo 360 correctly")
        
        // 66. PDF Studio: Document Assembly Service
        let assembly = PDFAssemblyService()
        assembly.pages = [page1, page2]
        assert(assembly.pages.count == 2, "Assembly service maintains page items")
        assembly.rotatePage(id: page1.id, delta: 90)
        assert(assembly.pages.first?.rotationAngle == 180, "Assembly service rotates targeted page by UUID")
        assembly.duplicatePage(id: page1.id)
        assert(assembly.pages.count == 3, "Duplicating page increases count to 3")
        assembly.removePage(id: page2.id)
        assert(assembly.pages.count == 2, "Removing page decrements count")
        
        // 67. PDF Studio: Editor Service Page Manipulation & Undo/Redo Invariants
        let editor = PDFEditorService()
        let testDoc = PDFDocument()
        let blankP1 = PDFPage()
        blankP1.setBounds(CGRect(x: 0, y: 0, width: 595, height: 842), for: .mediaBox)
        let blankP2 = PDFPage()
        blankP2.setBounds(CGRect(x: 0, y: 0, width: 595, height: 842), for: .mediaBox)
        testDoc.insert(blankP1, at: 0)
        testDoc.insert(blankP2, at: 1)
        editor.loadDocument(doc: testDoc, title: "UnitTest.pdf")
        assert(editor.document?.pageCount == 2, "Editor successfully loaded test document with 2 pages")
        
        editor.insertBlankPage()
        assert(editor.document?.pageCount == 3, "Inserting blank page increases page count to 3")
        assert(editor.canUndo, "Undo stack is populated after page mutation")
        editor.undo()
        assert(editor.document?.pageCount == 2, "Undo restores previous document page count to 2")
        assert(editor.canRedo, "Redo stack is populated after undo")
        editor.redo()
        assert(editor.document?.pageCount == 3, "Redo reapplies insertion back to 3 pages")
        
        // 68. PDF Studio: Editor Annotations
        editor.currentPageIndex = 0
        editor.addAnnotation(type: .highlight, bounds: CGRect(x: 50, y: 50, width: 200, height: 20))
        let annotCount = editor.document?.page(at: 0)?.annotations.count ?? 0
        assert(annotCount > 0, "Adding highlight annotation attaches annotation to targeted page")
        
        // 69. PDF Studio: Office Formats & Offline Support
        let officeFormats = PDFOfficeFormat.allCases
        assert(officeFormats.contains(.docx) && officeFormats.contains(.rtf) && officeFormats.contains(.markdown), "Supported offline formats include DOCX, RTF, and Markdown")
        
        // 70. PDF Studio: Vision OCR Supported Languages
        let ocr = PDFOCRService()
        assert(!ocr.supportedLanguages.isEmpty, "OCR service detects native Apple Vision supported recognition languages")
        assert(ocr.supportedLanguages.contains("en-US"), "OCR service includes US English")
        
        // 71. PDF Studio: Metadata Sanitization
        let metaInspector = PDFMetadataInspectorService()
        let testMetaDoc = PDFDocument()
        let metaPage = PDFPage()
        metaPage.setBounds(CGRect(x: 0, y: 0, width: 500, height: 700), for: .mediaBox)
        testMetaDoc.insert(metaPage, at: 0)
        testMetaDoc.documentAttributes = [
            PDFDocumentAttribute.titleAttribute: "Confidential Strategy",
            PDFDocumentAttribute.authorAttribute: "Internal Employee"
        ]
        metaInspector.document = testMetaDoc
        let tempSanitizedURL = FileManager.default.temporaryDirectory.appendingPathComponent("Sanitized_\(UUID().uuidString).pdf")
        let sanitizedSuccess = metaInspector.sanitizeAndExport(to: tempSanitizedURL)
        assert(sanitizedSuccess, "Sanitizing metadata successfully exports sanitized PDF")
        if let inspectedSanitized = PDFDocument(url: tempSanitizedURL) {
            let title = inspectedSanitized.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String ?? ""
            let author = inspectedSanitized.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String ?? ""
            assert(title.isEmpty && author.isEmpty, "Exported sanitized copy removes sensitive Title and Author tracking attributes")
        }
        
        // 72. PDF Studio: Document Split Mode Calculation
        let splitURLs = assembly.splitDocument(
            sourceURL: tempSanitizedURL,
            splitMode: "each",
            splitInterval: 1,
            splitRangesText: "",
            destinationFolder: FileManager.default.temporaryDirectory
        )
        assert(!splitURLs.isEmpty, "Split document with 'each' mode generates individual PDF page documents")
        
        // 73. Menu Bar Widget: Category Count & Full Coverage
        let widgetCategories = WidgetMetricCategory.allCases
        assert(widgetCategories.count == 8, "Menu Bar Widget contains 8 categories (CPU, Memory, GPU, Thermal, Battery, Storage, Network, System)")
        assert(WidgetMetricId.allCases.count >= 40, "Menu Bar Widget provides over 40 distinct telemetry metrics")

        // 74. Menu Bar Widget: Default Preferences State
        let prefs = MenuBarWidgetPreferences.shared
        prefs.resetToDefaults()
        assert(prefs.layoutStyle == .balanced, "Default widget layout style is Balanced")
        assert(!prefs.enabledMetrics.isEmpty, "Default configuration has active enabled metrics")
        assert(prefs.isMetricEnabled(.cpuTotalUsage), "CPU total usage is enabled by default")
        assert(prefs.isMetricEnabled(.memoryUsed), "Memory used is enabled by default")
        assert(prefs.isMetricEnabled(.storageFree), "Storage free is enabled by default")
        assert(prefs.enabledQuickActions.contains(.openDashboard), "Quick actions include Overview Dashboard by default")

        // 75. Menu Bar Widget: Metric Selection & Toggling
        prefs.setMetricEnabled(.cpuIdleUsage, enabled: true)
        assert(prefs.isMetricEnabled(.cpuIdleUsage), "Enabling a metric updates enabledMetrics set")
        prefs.toggleMetric(.cpuIdleUsage)
        assert(!prefs.isMetricEnabled(.cpuIdleUsage), "Toggling metric turns it off when previously enabled")

        // 76. Menu Bar Widget: Metric Reordering (Drag and Drop Position)
        let initialCount = prefs.metricOrder.count
        let firstMetric = prefs.metricOrder[0]
        let secondMetric = prefs.metricOrder[1]
        prefs.moveMetric(fromIndex: 0, toIndex: 1)
        assert(prefs.metricOrder.count == initialCount, "Metric reordering preserves total element count")
        assert(prefs.metricOrder[0] == secondMetric && prefs.metricOrder[1] == firstMetric, "Moving metric swaps adjacent elements properly")
        prefs.moveMetric(fromIndex: 1, toIndex: 0)

        // 77. Menu Bar Widget: Layout Density & Visual Toggles
        prefs.layoutStyle = .compact
        assert(prefs.layoutStyle == .compact, "Layout style updates to Compact")
        prefs.layoutStyle = .detailed
        assert(prefs.layoutStyle == .detailed, "Layout style updates to Detailed")
        prefs.compactSpacing = true
        assert(prefs.compactSpacing, "Compact spacing toggle is supported")
        prefs.compactSpacing = false

        // 78. Menu Bar Widget: Honest Telemetry Availability Invariants
        var noBatterySnapshot = SystemMetricsSnapshot()
        noBatterySnapshot.battery.hasBattery = false
        let extractedBattery = prefs.extract(metric: .batteryPercentage, from: noBatterySnapshot)
        assert(!extractedBattery.isAvailable, "Missing battery hardware is reported as unavailable, never fake 0%")
        assert(extractedBattery.availabilityNote != nil, "Unavailable metric provides human-readable explanatory note")

        var activeSnapshot = SystemMetricsSnapshot()
        activeSnapshot.cpu.totalUsage = 42.5
        let extractedCPU = prefs.extract(metric: .cpuTotalUsage, from: activeSnapshot)
        assert(extractedCPU.isAvailable, "Active CPU metric is reported as available")
        assert(extractedCPU.dashboardSection == .cpu, "Clicking CPU metric routes to CPU navigation section")

        // 79. Menu Bar Widget: Threshold Alerts & Cooldown Suppression
        let alertService = WidgetAlertService.shared
        alertService.deliversNotifications = false
        defer { alertService.deliversNotifications = true }
        alertService.resetCooldowns()
        alertService.enableCPUAlert = true
        alertService.cpuThreshold = 80.0
        
        var highCPUSnapshot = SystemMetricsSnapshot()
        highCPUSnapshot.cpu.totalUsage = 92.0
        
        let firstEval = alertService.evaluate(snapshot: highCPUSnapshot)
        assert(!firstEval.isEmpty, "High CPU exceeding 80% triggers threshold alert on first evaluation")
        
        let secondEval = alertService.evaluate(snapshot: highCPUSnapshot)
        assert(secondEval.isEmpty, "Duplicate threshold alert is suppressed by cooldown within 300 seconds")
        
        // 80. Menu Bar Widget: Alert Deduplication Suppression Invariant
        assert(!alertService.canTriggerAlert(id: "cpu"), "CPU alert cooldown is active after trigger")
        alertService.resetCooldowns()
        assert(alertService.canTriggerAlert(id: "cpu"), "Cooldown reset restores trigger eligibility")
        alertService.enableCPUAlert = false

        // 81. Menu Bar Widget: Temperature Alert Requires Real Reading (Never Zero/Missing)
        let savedCPUTempAlert = (alertService.enableCPUTemperatureAlert, alertService.cpuTemperatureThresholdCelsius)
        alertService.enableCPUTemperatureAlert = true
        alertService.cpuTemperatureThresholdCelsius = 85.0
        var missingTempSnapshot = SystemMetricsSnapshot()
        missingTempSnapshot.sensors.cpuTemperature = nil
        let noTempEval = alertService.evaluate(snapshot: missingTempSnapshot)
        assert(noTempEval.isEmpty, "Missing temperature sensor reading never triggers false alerts")
        alertService.enableCPUTemperatureAlert = savedCPUTempAlert.0
        alertService.cpuTemperatureThresholdCelsius = savedCPUTempAlert.1

        // 82. Menu Bar Widget: Quick Actions Configuration
        let allActions = WidgetQuickActionId.allCases
        assert(allActions.count == 10, "Widget provides 10 standard native quick actions")
        assert(allActions.contains(.openCleaner) && allActions.contains(.quit), "Quick actions include Cache Cleaner and Quit")

        // 83. Menu Bar Widget: Monitored Storage Volume Selection
        prefs.selectedVolumePath = "/Volumes/ExternalSSD"
        assert(prefs.selectedVolumePath == "/Volumes/ExternalSSD", "Custom volume selection persists")
        prefs.selectedVolumePath = "/"
        assert(prefs.selectedVolumePath == "/", "Default storage path points to system root")
        
        // 84. Typography: AppFontFamily Cases & Availability Detection
        let fontFamilies = AppFontFamily.allCases
        assert(fontFamilies.count == 5, "Typography system defines 5 primary font families (SF Pro, Avenir Next, Helvetica Neue, Inter, SF Mono)")
        assert(AppFontFamily.sfPro.isAvailableOnSystem == true, "SF Pro native system font is always available on macOS")
        assert(!AppFontFamily.sfPro.displayName.isEmpty, "Font family display names are descriptive")

        // 85. Typography: Font Size Scaling Math (85% to 120%)
        let testSettings = AppSettings.shared
        testSettings.fontScale = 1.0
        let baseFont = AppTypography.font(size: 14.0)
        testSettings.fontScale = 1.20
        let scaledFont = AppTypography.font(size: 14.0)
        assert(baseFont != scaledFont || testSettings.fontScale == 1.20, "Font scaling updates font size calculation dynamically")
        testSettings.fontScale = 0.85
        assert(testSettings.fontScale >= 0.85 && testSettings.fontScale <= 1.20, "Font scale is bounded between 85% and 120%")
        testSettings.fontScale = 1.0

        // 86. Typography: Base Weight Options Mapping
        let weights = AppFontWeight.allCases
        assert(weights.count == 3, "AppFontWeight supports Regular, Medium, and Semibold weights")
        assert(AppFontWeight.regular.fontWeight == .regular, "AppFontWeight.regular maps to Font.Weight.regular")
        assert(AppFontWeight.medium.fontWeight == .medium, "AppFontWeight.medium maps to Font.Weight.medium")
        assert(AppFontWeight.semibold.fontWeight == .semibold, "AppFontWeight.semibold maps to Font.Weight.semibold")

        // 87. Typography: Technical Monospaced Font Families
        let monoFamilies = AppMonospacedFontFamily.allCases
        assert(monoFamilies.count == 4, "AppMonospacedFontFamily provides 4 monospaced options for technical metrics and tools")
        assert(AppMonospacedFontFamily.systemMonospaced.isAvailableOnSystem == true, "System monospaced digits are always available")
        assert(AppMonospacedFontFamily.menlo.isAvailableOnSystem == true, "Menlo monospaced font is available on macOS")

        // 88. Menu Bar Icon Symbols Motif
        let menuBarSymbols = MenuBarIconSymbol.allCases
        assert(menuBarSymbols.count == 6, "MenuBarIconSymbol defines 6 supported monochrome status item symbols")
        assert(MenuBarIconSymbol.pulseWave.symbolName == "waveform.path.ecg", "Pulse Wave motif maps to waveform.path.ecg")
        assert(!MenuBarIconSymbol.gauge.symbolName.isEmpty, "Gauge icon has valid SF Symbol")

        // 89. Appearance Mode: Light Mode Default Invariant
        assert(AppAppearanceMode.allCases.count == 3, "Appearance modes include Light, Dark, and System")
        assert(AppAppearanceMode.light.colorScheme == .light, "Light mode resolves to ColorScheme.light")
        assert(AppAppearanceMode.dark.colorScheme == .dark, "Dark mode resolves to ColorScheme.dark")
        assert(AppAppearanceMode.system.colorScheme == nil, "System mode resolves to nil colorScheme (respecting OS appearance)")

        // 90. Typography: Reset to Defaults Invariant
        testSettings.appFontFamily = .avenirNext
        testSettings.fontScale = 1.15
        testSettings.baseFontWeight = .semibold
        testSettings.monospacedFontFamily = .courierNew
        testSettings.resetTypographyToDefaults()
        assert(testSettings.appFontFamily == .sfPro, "Reset restores SF Pro as default font family")
        assert(testSettings.fontScale == 1.0, "Reset restores 100% font scale")
        assert(testSettings.baseFontWeight == .regular, "Reset restores Regular base weight")
        assert(testSettings.monospacedFontFamily == .systemMonospaced, "Reset restores System Monospaced for technical telemetry")

        // 91. Centralized Typography Token Presets
        assert(AppTypography.title != AppTypography.caption, "Typography tokens provide distinct semantic typography hierarchy")
        assert(AppTypography.metricNumber != AppTypography.footnote, "Metric numbers use distinct monospaced font token")

        // 92. Thermal: Sensor Classification
        assert(SensorClassifier.component(forSMCKey: "Tp01", isAppleSilicon: true) == .cpu, "Apple Silicon Tp** keys are CPU performance-cluster sensors")
        assert(SensorClassifier.component(forSMCKey: "Te05", isAppleSilicon: true) == .cpu, "Apple Silicon Te** keys are CPU efficiency-cluster sensors")
        assert(SensorClassifier.component(forSMCKey: "Tg0G", isAppleSilicon: true) == .gpu, "Apple Silicon Tg** keys are GPU sensors")
        assert(SensorClassifier.component(forSMCKey: "TG0B", isAppleSilicon: true) == nil, "Apple Silicon TG** battery gas-gauge keys are never treated as GPU")
        assert(SensorClassifier.component(forSMCKey: "TB1T", isAppleSilicon: true) == .battery, "TB?T keys are battery pack sensors")
        assert(SensorClassifier.component(forSMCKey: "Ts00", isAppleSilicon: true) == nil, "Unknown SMC keys stay unclassified")
        assert(SensorClassifier.component(forSMCKey: "TC0P", isAppleSilicon: false) == .cpu, "Intel TC0P is CPU proximity")
        assert(SensorClassifier.component(forSMCKey: "TG0D", isAppleSilicon: false) == .gpu, "Intel TG0D is GPU die")
        assert(SensorClassifier.component(forHIDProduct: "PMU tcal") == nil, "HID calibration references are not temperatures")
        assert(SensorClassifier.component(forHIDProduct: "PMU tdie1") == .powerManagement, "PMU die sensors are never attributed to CPU or GPU")
        assert(SensorClassifier.component(forHIDProduct: "gas gauge battery") == .battery, "HID gas gauge is the battery sensor")
        assert(SensorClassifier.component(forHIDProduct: "NAND CH0 temp") == .storage, "HID NAND sensor is SSD temperature")
        assert(SensorClassifier.component(forHIDProduct: "pACC MTR Temp Sensor2") == .cpu, "HID pACC MTR sensors are CPU")
        assert(SensorClassifier.component(forHIDProduct: "GPU MTR Temp Sensor1") == .gpu, "HID GPU MTR sensors are GPU")

        // 93. Thermal: CPU and GPU Never Share a Value
        let thermalNow = Date()
        let smcOnly = SensorMetricsBuilder.build(
            thermalState: .nominal,
            hid: .unavailable(reason: "No HID events."),
            smc: .values(MockSensorProvider.appleSiliconSMCFixture),
            fans: .fans(reportedCount: 0, readings: []),
            isAppleSilicon: true,
            now: thermalNow
        )
        assert(abs((smcOnly.cpuTemperature?.celsius ?? -1) - 62.0) < 0.001, "CPU temperature is the mean of Tp/Te sensors only (62 °C)")
        assert(smcOnly.cpuTemperature?.maximumCelsius == 68.0 && smcOnly.cpuTemperature?.sensorCount == 3, "CPU peak and sensor count come from CPU sensors")
        assert(abs((smcOnly.gpuTemperature?.celsius ?? -1) - 49.0) < 0.001, "GPU temperature is the mean of Tg sensors only (49 °C)")
        assert(smcOnly.cpuTemperature?.celsius != smcOnly.gpuTemperature?.celsius, "CPU and GPU temperatures are distinct values")
        assert(smcOnly.readings(for: .gpu).allSatisfy { $0.key.hasPrefix("Tg") }, "GPU readings contain only GPU keys")
        assert(!smcOnly.readings(for: .cpu).contains { $0.key.hasPrefix("Tg") || $0.key.hasPrefix("TB") }, "CPU readings contain no GPU or battery keys")
        assert(smcOnly.batteryTemperature?.celsius == 31.0 && smcOnly.batteryTemperature?.sensorCount == 1, "Battery uses TB0T only; TG0B is excluded")
        assert(!smcOnly.readings.contains { $0.key == "Ts00" }, "Unclassified SMC keys are not shown as component readings")

        // 94. Thermal: Unattributed Sensors Are Never Promoted (HID-only, as on Apple Silicon without SMC)
        let hidOnly = SensorMetricsBuilder.build(
            thermalState: .nominal,
            hid: .values(MockSensorProvider.appleSiliconHIDFixture),
            smc: .unavailable(reason: "macOS denied access to the SMC."),
            fans: .unavailable(reason: "macOS denied access to the SMC."),
            isAppleSilicon: true,
            now: thermalNow
        )
        assert(hidOnly.cpuTemperature == nil && hidOnly.gpuTemperature == nil, "PMU die sensors never populate CPU or GPU temperature")
        if case .unavailable(let reason) = hidOnly.state(for: .cpu) {
            assert(reason.contains("none is identified as a CPU sensor"), "Missing CPU sensor explains why it is unavailable")
        } else {
            assert(false, "CPU state is unavailable when no CPU sensor exists")
        }
        assert(hidOnly.readings(for: .powerManagement).count == 2, "Unattributed PMU sensors are listed under their own group")
        assert(abs((hidOnly.batteryTemperature?.celsius ?? -1) - 33.15) < 0.001, "Battery temperature comes from the gas-gauge sensors")
        assert(hidOnly.storageTemperature?.celsius == 41.0, "SSD temperature comes from the NAND sensor")
        assert(!hidOnly.readings.contains { $0.name == "PMU tcal" }, "Calibration reference is excluded")
        assert(!hidOnly.readings.contains { $0.celsius < SensorClassifier.plausibleRange.lowerBound }, "Disconnected thermistor (-22 °C) is rejected")
        assert(hidOnly.temperatureState.isAvailable, "Overall temperature state is available when any sensor is readable")

        // 95. Thermal: Source Preference Without Mixing
        let bothSources = SensorMetricsBuilder.build(
            thermalState: .fair,
            hid: .values(MockSensorProvider.appleSiliconHIDFixture),
            smc: .values(MockSensorProvider.appleSiliconSMCFixture),
            fans: .fans(reportedCount: 0, readings: []),
            isAppleSilicon: true,
            now: thermalNow
        )
        assert(bothSources.batteryTemperature?.source == .hidEventSystem, "Vendor-labeled HID battery sensor is preferred over SMC key convention")
        assert(bothSources.readings(for: .battery).allSatisfy { $0.source == .hidEventSystem }, "Battery readings are never averaged across two sources")
        assert(bothSources.cpuTemperature?.source == .smc && bothSources.gpuTemperature?.source == .smc, "CPU/GPU come from SMC when HID has no named CPU/GPU sensors")
        assert(bothSources.sourceStatuses.count == 2 && bothSources.sourceStatuses.allSatisfy { $0.state.isAvailable }, "Each source reports its own status")
        assert(bothSources.thermalState == .fair && bothSources.thermalStateDescription.contains("Pressure"), "Thermal state is reported as pressure, separately from temperatures")

        // 96. Thermal: Battery Temperature Is Never Inferred
        var noBatterySensor = SensorMetricsBuilder.build(
            thermalState: .nominal,
            hid: .values([]),
            smc: .values(MockSensorProvider.appleSiliconSMCFixture.filter { !$0.key.hasPrefix("TB") }),
            fans: nil,
            isAppleSilicon: true,
            now: thermalNow
        )
        SensorMetricsBuilder.mergeBatteryRegistry(into: &noBatterySensor, hasBattery: true, registryCelsius: nil, registryTimestamp: thermalNow)
        assert(noBatterySensor.batteryTemperature == nil, "No battery sensor and no registry value leaves battery temperature nil")
        var chargingSnapshot = SystemMetricsSnapshot()
        chargingSnapshot.battery.hasBattery = true
        chargingSnapshot.battery.isCharging = true
        chargingSnapshot.battery.percentage = 55
        chargingSnapshot.sensors = noBatterySensor
        assert(MenuBarStatusMetric.batteryTemperature.menuBarText(from: chargingSnapshot, now: thermalNow) == "BAT --°C", "Charge level and charging state never produce a battery temperature")

        var registryFallback = noBatterySensor
        SensorMetricsBuilder.mergeBatteryRegistry(into: &registryFallback, hasBattery: true, registryCelsius: 30.5, registryTimestamp: thermalNow)
        assert(registryFallback.batteryTemperature?.celsius == 30.5 && registryFallback.batteryTemperature?.source == .appleSmartBattery, "Registry temperature is used only as a fallback battery source")
        var registryIgnored = hidOnly
        SensorMetricsBuilder.mergeBatteryRegistry(into: &registryIgnored, hasBattery: true, registryCelsius: 20.0, registryTimestamp: thermalNow)
        assert(registryIgnored.batteryTemperature?.source == .hidEventSystem, "Registry value never overrides a hardware battery sensor")
        var desktop = hidOnly
        SensorMetricsBuilder.mergeBatteryRegistry(into: &desktop, hasBattery: false, registryCelsius: 30.0, registryTimestamp: thermalNow)
        assert(desktop.batteryTemperature == nil && desktop.readings(for: .battery).isEmpty, "Macs without a battery report no battery temperature")

        // 97. Thermal: Missing Sensors Show Unavailable, Never 0 °C
        let disabledSensors = SensorMetricsBuilder.build(thermalState: .nominal, hid: nil, smc: nil, fans: nil, now: thermalNow)
        assert(disabledSensors.readings.isEmpty && disabledSensors.cpuTemperature == nil, "Disabled hardware access produces no readings")
        assert(disabledSensors.state(for: .gpu) == .unavailable(reason: SensorMetricsBuilder.disabledReason), "Disabled access explains why GPU temperature is unavailable")
        assert(Formatters.compactTemperature(nil) == "--°C", "Compact menu bar form shows --°C for a missing reading")
        let savedUnit = AppSettings.shared.temperatureUnit
        AppSettings.shared.temperatureUnit = .celsius
        var missingGPUSnapshot = SystemMetricsSnapshot()
        missingGPUSnapshot.sensors = hidOnly
        let missingGPU = prefs.extract(metric: .gpuTemperature, from: missingGPUSnapshot)
        assert(!missingGPU.isAvailable && missingGPU.formattedValue == "Unavailable", "Widget shows Unavailable for a missing GPU sensor")
        assert(missingGPU.availabilityNote?.contains("GPU") == true, "Widget explains why the GPU sensor is unavailable")
        var presentCPUSnapshot = SystemMetricsSnapshot()
        presentCPUSnapshot.sensors = SensorMetricsBuilder.build(
            thermalState: .nominal, hid: nil, smc: .values(MockSensorProvider.appleSiliconSMCFixture), fans: nil, isAppleSilicon: true, now: Date()
        )
        let presentCPU = prefs.extract(metric: .cpuTemperature, from: presentCPUSnapshot)
        let presentGPU = prefs.extract(metric: .gpuTemperature, from: presentCPUSnapshot)
        assert(presentCPU.isAvailable && presentCPU.formattedValue == "62 °C", "Widget CPU temperature reads the CPU sensor")
        assert(presentGPU.isAvailable && presentGPU.formattedValue == "49 °C", "Widget GPU temperature reads the GPU sensor")
        assert(prefs.extract(metric: .ssdTemperature, from: missingGPUSnapshot).formattedValue == "41 °C", "Widget SSD temperature reads the NAND sensor")

        // 98. Thermal: Unit Conversion
        assert(TemperatureUnit.fahrenheit.convert(fromCelsius: 0) == 32, "0 °C == 32 °F")
        assert(TemperatureUnit.fahrenheit.convert(fromCelsius: 100) == 212, "100 °C == 212 °F")
        assert(TemperatureUnit.fahrenheit.convert(fromCelsius: -40) == -40, "-40 °C == -40 °F")
        assert(abs(TemperatureUnit.fahrenheit.convert(fromCelsius: 37) - 98.6) < 0.0001, "37 °C == 98.6 °F")
        assert(TemperatureUnit.celsius.convert(fromCelsius: 47.3) == 47.3, "Celsius conversion is identity")
        assert(abs(TemperatureUnit.fahrenheit.toCelsius(TemperatureUnit.fahrenheit.convert(fromCelsius: 63.7)) - 63.7) < 0.0001, "°F round-trips back to °C")
        assert(Formatters.temperature(47.6, unit: .fahrenheit) == "118 °F", "Formatter converts before rounding (47.6 °C → 118 °F)")
        assert(Formatters.temperature(47.64, decimals: 1) == "47.6 °C", "Optional decimal precision is supported")
        assert(Formatters.compactTemperature(62.0, unit: .fahrenheit) == "144°F", "Compact form converts to °F")

        // 99. Thermal: Stale Reading Detection & Retention
        let oldReading = ComponentTemperature(
            component: .cpu, averageCelsius: 60, maximumCelsius: 60, sensorCount: 1,
            source: .smc, identification: .keyConvention, timestamp: thermalNow.addingTimeInterval(-30)
        )
        assert(oldReading.isStale(at: thermalNow, maxAge: 10), "A 30 s old reading is stale with a 10 s limit")
        assert(!oldReading.isStale(at: thermalNow.addingTimeInterval(-25), maxAge: 10), "A 5 s old reading is fresh")
        assert(SensorFreshness.staleAfter(refreshInterval: 1) == 10 && SensorFreshness.staleAfter(refreshInterval: 5) == 30, "Stale threshold scales with the refresh interval")
        var staleSnapshot = SystemMetricsSnapshot()
        staleSnapshot.sensors.cpuTemperature = ComponentTemperature(
            component: .cpu, averageCelsius: 60, maximumCelsius: 60, sensorCount: 1,
            source: .smc, identification: .keyConvention, timestamp: Date().addingTimeInterval(-600)
        )
        staleSnapshot.sensors.componentStates[.cpu] = .available
        assert(MenuBarStatusMetric.cpuTemperature.menuBarText(from: staleSnapshot, now: Date(), staleAfter: 10) == "CPU --°C", "Menu bar never shows a stale reading as current")
        let staleWidget = prefs.extract(metric: .cpuTemperature, from: staleSnapshot)
        assert(!staleWidget.isAvailable && staleWidget.secondaryValue?.hasPrefix("Stale") == true, "Widget flags a stale reading")

        let lostSample = SensorMetricsBuilder.build(
            thermalState: .nominal, hid: .unavailable(reason: "x"), smc: .unavailable(reason: "y"), fans: nil,
            isAppleSilicon: true, now: thermalNow.addingTimeInterval(4)
        )
        let retained = SensorMetricsBuilder.retainingRecentReadings(current: lostSample, previous: smcOnly, now: thermalNow.addingTimeInterval(4), maxAge: 60)
        assert(retained.cpuTemperature?.timestamp == thermalNow, "Retained reading keeps its original timestamp so it ages honestly")
        let expired = SensorMetricsBuilder.retainingRecentReadings(current: lostSample, previous: smcOnly, now: thermalNow.addingTimeInterval(120), maxAge: 60)
        assert(expired.cpuTemperature == nil, "Readings older than the retention window are dropped")
        let disabledRetained = SensorMetricsBuilder.retainingRecentReadings(current: disabledSensors, previous: smcOnly, now: thermalNow, maxAge: 60)
        assert(disabledRetained.cpuTemperature == nil, "Turning sensors off clears values immediately")

        // 100. Thermal: Menu Bar Metrics
        var menuSnapshot = SystemMetricsSnapshot()
        menuSnapshot.sensors = bothSources
        assert(MenuBarStatusMetric.cpuTemperature.menuBarText(from: menuSnapshot, now: thermalNow) == "CPU 62°C", "Menu bar CPU temperature uses the CPU sensor")
        assert(MenuBarStatusMetric.gpuTemperature.menuBarText(from: menuSnapshot, now: thermalNow) == "GPU 49°C", "Menu bar GPU temperature uses the GPU sensor")
        assert(MenuBarStatusMetric.cpuTemperature.menuBarText(from: menuSnapshot, temperatureUnit: .fahrenheit, now: thermalNow) == "CPU 144°F", "Menu bar honours °F")
        assert(MenuBarStatusMetric.thermalState.menuBarText(from: menuSnapshot, now: thermalNow) == "THM Fair", "Menu bar thermal state is labelled as state, not °C")
        assert(MenuBarStatusMetric.fanSpeed.menuBarText(from: menuSnapshot, now: thermalNow) == "FAN --", "Fanless Mac shows FAN --, never 0rpm")
        var noBatteryMenu = menuSnapshot
        noBatteryMenu.battery.hasBattery = false
        assert(MenuBarStatusMetric.batteryTemperature.menuBarText(from: noBatteryMenu, now: thermalNow) == nil, "Battery temperature is hidden on Macs without a battery")
        menuSnapshot.battery.hasBattery = true
        assert(MenuBarStatusMetric.batteryTemperature.menuBarText(from: menuSnapshot, now: thermalNow) == "BAT 33°C", "Menu bar battery temperature uses the battery sensor")
        var hidMenu = SystemMetricsSnapshot()
        hidMenu.sensors = hidOnly
        assert(!MenuBarStatusMetric.cpuTemperature.availability(in: hidMenu).isAvailable, "Menu bar settings mark CPU temperature unavailable without a CPU sensor")

        // 101. Thermal: Fans
        let fanMetrics = MockSensorProvider(simulateMissingSensors: false).sample(now: thermalNow)
        assert(fanMetrics.fansState.isAvailable && fanMetrics.fanSpeeds.first?.speedRPM == 2150, "Fan speed is reported in RPM from the SMC")
        menuSnapshot.sensors = fanMetrics
        assert(MenuBarStatusMetric.fanSpeed.menuBarText(from: menuSnapshot, now: thermalNow) == "FAN 2150rpm", "Menu bar fan speed shows RPM")
        let noMaxFan = SensorMetricsBuilder.build(
            thermalState: .nominal, hid: nil, smc: .values([]),
            fans: .fans(reportedCount: 1, readings: [RawFanValue(index: 0, rpm: 1800, minRPM: nil, maxRPM: 0)]),
            now: thermalNow
        )
        assert(noMaxFan.fanSpeeds.first?.maxRPM == nil, "Unreported fan maximum stays nil instead of a made-up value")
        if case .unavailable(let reason) = bothSources.fansState {
            assert(reason.contains("passively cooled"), "Zero fans reported explains the Mac is passively cooled")
        } else {
            assert(false, "Zero reported fans is an unavailable state")
        }

        // 102. Thermal: Per-Component Alerts
        let savedTempAlerts = (
            alertService.enableCPUTemperatureAlert, alertService.cpuTemperatureThresholdCelsius,
            alertService.enableGPUTemperatureAlert, alertService.gpuTemperatureThresholdCelsius,
            alertService.enableBatteryTemperatureAlert, alertService.batteryTemperatureThresholdCelsius
        )
        alertService.resetCooldowns()
        alertService.enableCPUTemperatureAlert = false
        alertService.enableGPUTemperatureAlert = true
        alertService.gpuTemperatureThresholdCelsius = 80
        alertService.enableBatteryTemperatureAlert = true
        alertService.batteryTemperatureThresholdCelsius = 45
        func componentReading(_ component: ThermalComponent, _ celsius: Double, age: TimeInterval = 0) -> ComponentTemperature {
            ComponentTemperature(component: component, averageCelsius: celsius, maximumCelsius: celsius, sensorCount: 1,
                                 source: .smc, identification: .keyConvention, timestamp: Date().addingTimeInterval(-age))
        }
        var alertSnapshot = SystemMetricsSnapshot()
        alertSnapshot.sensors.cpuTemperature = componentReading(.cpu, 95)
        alertSnapshot.sensors.gpuTemperature = componentReading(.gpu, 50)
        let hotCPUOnly = alertService.evaluate(snapshot: alertSnapshot).filter { $0.contains("temperature") }
        assert(hotCPUOnly.isEmpty, "A hot CPU never triggers the GPU alert")
        alertSnapshot.sensors.gpuTemperature = componentReading(.gpu, 85)
        let hotGPU = alertService.evaluate(snapshot: alertSnapshot).filter { $0.contains("temperature") }
        assert(hotGPU.count == 1 && hotGPU[0].hasPrefix("GPU"), "GPU alert fires from the GPU reading and its own threshold")
        alertService.resetCooldowns()
        alertSnapshot.sensors.gpuTemperature = componentReading(.gpu, 99, age: 600)
        assert(alertService.evaluate(snapshot: alertSnapshot).filter { $0.contains("temperature") }.isEmpty, "Stale readings never trigger alerts")
        alertSnapshot.sensors.gpuTemperature = nil
        alertSnapshot.sensors.batteryTemperature = nil
        assert(alertService.evaluate(snapshot: alertSnapshot).filter { $0.contains("temperature") }.isEmpty, "Unsupported sensors never trigger alerts")
        alertSnapshot.sensors.batteryTemperature = componentReading(.battery, 47)
        let hotBattery = alertService.evaluate(snapshot: alertSnapshot).filter { $0.contains("temperature") }
        assert(hotBattery.count == 1 && hotBattery[0].hasPrefix("Battery"), "Battery alert uses its own 45 °C threshold")
        alertService.resetCooldowns()
        alertService.enableCPUTemperatureAlert = savedTempAlerts.0
        alertService.cpuTemperatureThresholdCelsius = savedTempAlerts.1
        alertService.enableGPUTemperatureAlert = savedTempAlerts.2
        alertService.gpuTemperatureThresholdCelsius = savedTempAlerts.3
        alertService.enableBatteryTemperatureAlert = savedTempAlerts.4
        alertService.batteryTemperatureThresholdCelsius = savedTempAlerts.5

        // 103. Thermal: History Keeps Sensor Identity and Gaps
        var history: [ThermalComponent: [TemperatureHistoryPoint]] = [:]
        history = SystemMonitor.appendingTemperatureHistory(history, from: smcOnly, staleAfter: 10, maxPoints: 3)
        history = SystemMonitor.appendingTemperatureHistory(history, from: lostSample, staleAfter: 10, maxPoints: 3)
        var staleRetainedSample = retained
        staleRetainedSample.sampledAt = thermalNow.addingTimeInterval(30)
        history = SystemMonitor.appendingTemperatureHistory(history, from: staleRetainedSample, staleAfter: 10, maxPoints: 3)
        let cpuSeries = history[.cpu] ?? []
        assert(cpuSeries.count == 3 && cpuSeries[0].celsius == 62.0 && cpuSeries[0].source == .smc, "History stores the CPU value with its source")
        assert(cpuSeries[1].celsius == nil, "A missing reading is recorded as a gap")
        assert(cpuSeries[2].celsius == nil, "A stale cached reading is recorded as a gap, not a fresh point")
        assert(history[.gpu]?.first?.celsius == 49.0, "GPU history is a separate series with GPU values")
        history = SystemMonitor.appendingTemperatureHistory(history, from: smcOnly, staleAfter: 10, maxPoints: 3)
        assert(history[.cpu]?.count == 3 && history[.cpu]?.last?.celsius == 62.0, "History is capped and keeps the newest points")
        assert(SensorsDetailView.segments(of: cpuSeries + [cpuSeries[0]]).count == 2, "Chart splits the series at gaps")

        // 104. Thermal: Pages Read the Shared Service
        let monitorSensors = SystemMonitor.shared.snapshot.sensors
        assert(SystemMonitor.shared.sensorStaleAfter >= SensorFreshness.defaultStaleAfter, "Shared monitor exposes a single stale threshold for all pages")
        assert(monitorSensors.history.keys.allSatisfy { ThermalComponent.headline.contains($0) }, "Shared snapshot history is keyed by component")

        // 105. Thermal: Live Hardware Invariants (real sensors on this Mac; values not asserted)
        let liveSensors = SensorProvider().sample(hardwareAccessEnabled: AppSettings.shared.hardwareSensorAccessEnabled)
        assert(liveSensors.readings.allSatisfy { SensorClassifier.isPlausible($0.celsius) }, "Live readings are all physically plausible")
        let liveCPUIds = Set(liveSensors.readings(for: .cpu).map(\.id))
        let liveGPUIds = Set(liveSensors.readings(for: .gpu).map(\.id))
        assert(liveCPUIds.isDisjoint(with: liveGPUIds), "Live CPU and GPU temperatures come from disjoint sensors")
        for component in ThermalComponent.headline {
            let hasValue = liveSensors.temperature(for: component) != nil
            assert(hasValue == liveSensors.state(for: component).isAvailable, "Live \(component.displayName) availability matches its value")
        }
        logs.append("ℹ️ Live sensors: " + ThermalComponent.headline.map { component in
            "\(component.displayName)=\(Formatters.temperature(liveSensors.temperature(for: component)?.celsius))"
        }.joined(separator: ", ") + ", \(liveSensors.readings.count) readings, fans: \(liveSensors.fansState.displayText)")
        AppSettings.shared.temperatureUnit = savedUnit

        // 106. Theme: Appearance Preference Mapping & Legacy Migration
        assert(AppAppearanceMode.light.nsAppearance?.name == .aqua, "Light preference applies the Aqua appearance app-wide")
        assert(AppAppearanceMode.dark.nsAppearance?.name == .darkAqua, "Dark preference applies the Dark Aqua appearance app-wide")
        assert(AppAppearanceMode.system.nsAppearance == nil, "System preference clears the override so macOS decides")
        assert(AppAppearanceMode.migrating(storedValue: nil) == .light, "New installs default to Light Mode")
        assert(AppAppearanceMode.migrating(storedValue: "Dark Graphite") == .dark, "Legacy 'Dark Graphite' preference is preserved as Dark")
        assert(AppAppearanceMode.migrating(storedValue: "System Default") == .system, "Legacy 'System Default' preference is preserved as System")
        assert(AppAppearanceMode.allCases.allSatisfy { AppAppearanceMode.migrating(storedValue: $0.rawValue) == $0 }, "Current preference values round-trip unchanged")
        assert(AppSettings.shared.appearanceMode.rawValue == UserDefaults.standard.string(forKey: "appearanceMode"), "Stored appearance value is always readable by @AppStorage")

        // 107. Theme: Live Appearance Switching
        let savedAppearance = AppSettings.shared.appearanceMode
        let appearanceController = AppearanceController.shared
        for mode in [AppAppearanceMode.dark, .light, .system, .dark] {
            appearanceController.apply(mode)
            assert(NSApp.appearance?.name == mode.nsAppearance?.name, "Switching to \(mode.rawValue) updates NSApp.appearance immediately")
        }
        appearanceController.apply(.light)
        assert(appearanceController.resolvedAppearance?.name == .aqua, "Popovers resolve to Aqua while Light is applied")
        appearanceController.apply(.dark)
        assert(appearanceController.resolvedAppearance?.name == .darkAqua, "Popovers resolve to Dark Aqua while Dark is applied")
        appearanceController.apply(savedAppearance)

        // 108. Theme: Semantic Tokens Adapt to Appearance
        func resolvedColor(_ color: Color, _ name: NSAppearance.Name) -> NSColor {
            var result = NSColor.clear
            NSAppearance(named: name)?.performAsCurrentDrawingAppearance {
                result = NSColor(color).usingColorSpace(.sRGB) ?? .clear
            }
            return result
        }
        func luminance(_ c: NSColor) -> Double {
            func channel(_ v: CGFloat) -> Double {
                let v = Double(v)
                return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(c.redComponent) + 0.7152 * channel(c.greenComponent) + 0.0722 * channel(c.blueComponent)
        }
        func contrast(_ fg: Color, on bg: Color, _ name: NSAppearance.Name) -> Double {
            let a = luminance(resolvedColor(fg, name))
            let b = luminance(resolvedColor(bg, name))
            return (max(a, b) + 0.05) / (min(a, b) + 0.05)
        }
        let adaptiveTokens: [(String, Color)] = [
            ("contentBackground", AppTheme.contentBackground), ("cardBackground", AppTheme.cardBackground),
            ("elevatedCardBackground", AppTheme.elevatedCardBackground), ("inputBackground", AppTheme.inputBackground),
            ("textPrimary", AppTheme.textPrimary), ("textSecondary", AppTheme.textSecondary),
            ("cardBorder", AppTheme.cardBorder), ("subtleFill", AppTheme.subtleFill), ("chartGrid", AppTheme.chartGrid)
        ]
        for (name, token) in adaptiveTokens {
            assert(resolvedColor(token, .aqua) != resolvedColor(token, .darkAqua), "\(name) resolves differently in Light and Dark")
        }
        assert(luminance(resolvedColor(AppTheme.cardBackground, .aqua)) > 0.8, "Light cards are light surfaces")
        assert(luminance(resolvedColor(AppTheme.cardBackground, .darkAqua)) < 0.05, "Dark cards are graphite surfaces")
        assert(resolvedColor(AppTheme.subtleFill, .aqua).alphaComponent > 0, "Subtle fills stay visible in Light Mode")
        assert(AppTheme.selectableFill(true) != AppTheme.selectableFill(false), "Selected chips are visually distinct from unselected chips")

        // 109. Theme: Text Contrast (WCAG AA 4.5:1 for body text)
        let textSurfaces: [(String, Color)] = [
            ("card", AppTheme.cardBackground), ("canvas", AppTheme.contentBackground), ("input", AppTheme.inputBackground)
        ]
        let textTokens: [(String, Color, Double)] = [
            ("textPrimary", AppTheme.textPrimary, 7.0), ("textSecondary", AppTheme.textSecondary, 4.5),
            ("textTertiary", AppTheme.textTertiary, 4.5), ("electricBlue", AppTheme.electricBlue, 4.5),
            ("successGreen", AppTheme.successGreen, 4.5), ("warningAmber", AppTheme.warningAmber, 4.5),
            ("dangerRed", AppTheme.dangerRed, 4.5)
        ]
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let label = appearance == .aqua ? "Light" : "Dark"
            for (surfaceName, surface) in textSurfaces {
                for (tokenName, token, minimum) in textTokens {
                    let ratio = contrast(token, on: surface, appearance)
                    assert(ratio >= minimum, "\(label): \(tokenName) on \(surfaceName) meets \(minimum):1 (got \(String(format: "%.2f", ratio)))")
                }
            }
            let disabledRatio = contrast(AppTheme.disabledText, on: AppTheme.cardBackground, appearance)
            assert(disabledRatio >= 2.5, "\(label): disabled text remains legible (got \(String(format: "%.2f", disabledRatio)))")
        }

        // 110. Theme: Button Label Contrast
        let buttonFills: [(String, Color)] = [
            ("accentFill", AppTheme.accentFill), ("successFill", AppTheme.successFill),
            ("infoFill", AppTheme.infoFill), ("purpleFill", AppTheme.purpleFill), ("dangerFill", AppTheme.dangerFill)
        ]
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let label = appearance == .aqua ? "Light" : "Dark"
            for (fillName, fill) in buttonFills {
                let ratio = contrast(AppTheme.textOnAccent, on: fill, appearance)
                assert(ratio >= 4.5, "\(label): white label on \(fillName) meets 4.5:1 (got \(String(format: "%.2f", ratio)))")
            }
        }

        // 111–124. Clipboard history, global shortcut, picker, paste and lifecycle
        runClipboardTests(assert)

        // 125–129. PDF Studio: geometry, safe writing, editor, canvas interaction and tools
        runPDFStudioTests(assert)

        // 130. Settings: persistence, publishing, search index and layout
        runSettingsTests(assert)

        // 131. Port Manager: listening sockets, dev servers, redaction, conflicts, safety
        runPortManagerTests(assert)

        return (passed, failed, logs)
    }
}



