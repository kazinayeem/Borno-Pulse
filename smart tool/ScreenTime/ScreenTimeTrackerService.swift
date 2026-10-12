//
//  ScreenTimeTrackerService.swift
//  Borno Pulse
//

import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - Category Breakdown Item
public struct CategoryBreakdownItem: Identifiable, Sendable {
    public var id: String { category.rawValue }
    public let category: AppUsageCategory
    public let totalDuration: TimeInterval
    public let activeDuration: TimeInterval
    public let idleDuration: TimeInterval
    public let percentage: Double
    
    public init(
        category: AppUsageCategory,
        totalDuration: TimeInterval,
        activeDuration: TimeInterval,
        idleDuration: TimeInterval,
        percentage: Double
    ) {
        self.category = category
        self.totalDuration = totalDuration
        self.activeDuration = activeDuration
        self.idleDuration = idleDuration
        self.percentage = percentage
    }
}

// MARK: - Daily Trend Chart Point
public struct DailyTrendPoint: Identifiable, Sendable {
    public var id: String { dayKey }
    public let dayKey: String
    public let date: Date
    public let activeDurationHours: Double
    public let idleDurationHours: Double
    public let totalDurationHours: Double
    public let label: String
    
    public init(dayKey: String, date: Date, activeSeconds: TimeInterval, idleSeconds: TimeInterval, label: String) {
        self.dayKey = dayKey
        self.date = date
        self.activeDurationHours = activeSeconds / 3600.0
        self.idleDurationHours = idleSeconds / 3600.0
        self.totalDurationHours = (activeSeconds + idleSeconds) / 3600.0
        self.label = label
    }
    
    public var weekdayLabel: String {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df.string(from: date)
    }
    
    public var shortDateLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}

// MARK: - Screen Time Tracker Service
@MainActor
public final class ScreenTimeTrackerService: ObservableObject {
    public static let shared = ScreenTimeTrackerService()
    
    // MARK: - Published State
    @Published public var isTrackingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isTrackingEnabled, forKey: "ScreenTime_TrackingEnabled")
            if isTrackingEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @Published public var isTrackingPaused: Bool {
        didSet {
            UserDefaults.standard.set(isTrackingPaused, forKey: "ScreenTime_TrackingPaused")
        }
    }
    
    @Published public var currentAppName: String = "Finder"
    @Published public var currentAppBundleID: String = "com.apple.finder"
    @Published public var currentAppCategory: AppUsageCategory = .utilities
    @Published public var currentSessionDuration: TimeInterval = 0
    @Published public var currentSystemIdleSeconds: TimeInterval = 0
    @Published public var isCurrentlyIdle: Bool = false
    
    @Published public var excludedBundleIDs: Set<String> {
        didSet {
            if let data = try? JSONEncoder().encode(Array(excludedBundleIDs)) {
                UserDefaults.standard.set(data, forKey: "ScreenTime_ExcludedBundleIDs")
            }
        }
    }
    
    @Published public var dailyRecords: [String: DailyAppUsageSummary] = [:]
    @Published public var selectedRange: ScreenTimeRangeOption = .today
    @Published public var filterSearchText: String = ""
    @Published public var filterCategory: AppUsageCategory? = nil
    @Published public var minDurationSeconds: TimeInterval = 0
    
    @Published public var websiteTrackingSupported: Bool = true
    @Published public var websiteTrackingNotice: String = "Standalone tracking: Active domain sampled locally via Apple Events when permitted. No extension required."
    
    // MARK: - Internal Engine Properties
    private var pulseTimer: AnyCancellable?
    private var websiteSampleCounter: Int = 0
    private var lastSessionTick: Date = Date()
    private var currentActiveWebsiteDomain: String? = nil
    private let idleThresholdSeconds: TimeInterval = 120.0 // 2 minutes of zero hardware input
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
    
    private let displayDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }()
    
    // MARK: - Initializer
    private init() {
        let savedEnabled = UserDefaults.standard.object(forKey: "ScreenTime_TrackingEnabled") as? Bool ?? true
        let savedPaused = UserDefaults.standard.bool(forKey: "ScreenTime_TrackingPaused")
        
        if let data = UserDefaults.standard.data(forKey: "ScreenTime_ExcludedBundleIDs"),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            self.excludedBundleIDs = Set(arr)
        } else {
            // Default excluded: internal system daemons if desired
            self.excludedBundleIDs = ["com.apple.loginwindow", "com.apple.notificationcenterui"]
        }
        
        self.isTrackingEnabled = savedEnabled
        self.isTrackingPaused = savedPaused
        
        loadHistoryFromDisk()
        setupNotificationObservers()
        
        if isTrackingEnabled {
            startMonitoring()
        }
    }
    
    // MARK: - Storage File Path
    private var storageFileURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NaemSmartTool/ScreenTime", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("screen_time_history.json")
    }
    
    // MARK: - Observers Setup
    private func setupNotificationObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        
        nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self = self, self.isTrackingEnabled, !self.isTrackingPaused else { return }
                if let app {
                    self.handleApplicationActivated(app)
                }
            }
        }
        
        nc.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isCurrentlyIdle = true
            }
        }
        
        nc.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isCurrentlyIdle = false
            }
        }
        
        nc.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isCurrentlyIdle = true
            }
        }
        
        nc.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isCurrentlyIdle = false
            }
        }
    }
    
    // MARK: - Monitoring Control
    public func startMonitoring() {
        guard pulseTimer == nil else { return }
        
        // Seed initial frontmost app
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            handleApplicationActivated(frontApp)
        }
        
        lastSessionTick = Date()
        
        pulseTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.tick(at: now)
            }
    }
    
    public func stopMonitoring() {
        pulseTimer?.cancel()
        pulseTimer = nil
        saveHistoryToDisk()
    }
    
    public func pauseTracking() {
        isTrackingPaused = true
    }
    
    public func resumeTracking() {
        isTrackingPaused = false
        lastSessionTick = Date()
    }
    
    // MARK: - Foreground Switch Handler
    private func handleApplicationActivated(_ app: NSRunningApplication) {
        let bundleID = app.bundleIdentifier ?? "unknown.bundle"
        let appName = app.localizedName ?? "Unknown App"
        
        currentAppName = appName
        currentAppBundleID = bundleID
        currentAppCategory = AppUsageCategory.classify(bundleIdentifier: bundleID, appName: appName)
        currentSessionDuration = 0
        currentActiveWebsiteDomain = nil
        lastSessionTick = Date()
    }
    
    // MARK: - 1-Second Engine Pulse Tick
    private func tick(at now: Date) {
        guard isTrackingEnabled, !isTrackingPaused else { return }
        
        let elapsed = now.timeIntervalSince(lastSessionTick)
        lastSessionTick = now
        guard elapsed > 0 && elapsed < 10 else { return } // Protect against huge jumps after system sleep
        
        // 1. Idle Detection
        let idleSecs = IdleDetector.shared.getSystemIdleTimeSeconds()
        currentSystemIdleSeconds = idleSecs
        let isIdle = idleSecs >= idleThresholdSeconds
        isCurrentlyIdle = isIdle
        
        // 2. Check Excluded
        if excludedBundleIDs.contains(currentAppBundleID) {
            return
        }
        
        currentSessionDuration += elapsed
        
        // 3. Accumulate into Today's summary
        let todayKey = dateFormatter.string(from: now)
        var summary = dailyRecords[todayKey] ?? DailyAppUsageSummary(dayKey: todayKey, date: Calendar.current.startOfDay(for: now))
        
        summary.totalForegroundDuration += elapsed
        if isIdle {
            summary.totalIdleDuration += elapsed
        } else {
            summary.totalActiveDuration += elapsed
        }
        
        // Hourly Bucket
        let currentHour = Calendar.current.component(.hour, from: now)
        if currentHour >= 0 && currentHour < summary.hourlyBuckets.count {
            if isIdle {
                summary.hourlyBuckets[currentHour].idleDuration += elapsed
            } else {
                summary.hourlyBuckets[currentHour].activeDuration += elapsed
            }
        }
        
        // App Breakdown Item
        var appItem = summary.appBreakdown[currentAppBundleID] ?? AppUsageAggregate(
            bundleIdentifier: currentAppBundleID,
            appName: currentAppName,
            category: currentAppCategory,
            firstSeen: now,
            lastSeen: now
        )
        
        appItem.appName = currentAppName
        appItem.category = currentAppCategory
        appItem.totalDuration += elapsed
        if isIdle {
            appItem.idleDuration += elapsed
        } else {
            appItem.activeDuration += elapsed
        }
        appItem.lastSeen = now
        summary.appBreakdown[currentAppBundleID] = appItem
        
        // 4. Sample Active Website if Browser
        websiteSampleCounter += 1
        if websiteSampleCounter >= 5 {
            websiteSampleCounter = 0
            if currentAppCategory == .browsers {
                Task { [weak self, bundleID = currentAppBundleID, name = currentAppName] in
                    let result = await WebsiteInspectionHelper.shared.inspectActiveDomain(
                        bundleIdentifier: bundleID,
                        appName: name
                    )
                    self?.handleWebsiteInspectionResult(result, elapsed: 5.0, dayKey: todayKey)
                }
            }
        }
        
        // 5. Append Timeline Segment if changed or periodically
        recordTimelineSegment(in: &summary, now: now, elapsed: elapsed)
        
        dailyRecords[todayKey] = summary
        
        // Periodic disk flush every 30 seconds
        if Int(now.timeIntervalSince1970) % 30 == 0 {
            saveHistoryToDisk()
        }
    }
    
    private func handleWebsiteInspectionResult(
        _ result: WebsiteInspectionHelper.InspectionResult,
        elapsed: TimeInterval,
        dayKey: String
    ) {
        switch result {
        case .success(let domain):
            guard !domain.isEmpty else { return }
            var summary = dailyRecords[dayKey] ?? DailyAppUsageSummary(dayKey: dayKey, date: Date())
            var webItem = summary.websiteBreakdown[domain] ?? WebsiteUsageAggregate(
                domain: domain,
                browserName: currentAppName
            )
            webItem.totalDuration += elapsed
            webItem.visitCount += 1
            summary.websiteBreakdown[domain] = webItem
            dailyRecords[dayKey] = summary
            websiteTrackingNotice = "Active domain: \(domain) (sampled locally via Apple Events)"
        case .permissionDenied:
            websiteTrackingNotice = "Automation access not granted. Application time is tracked accurately without website details."
        case .windowUnavailable, .notABrowser, .executionError:
            break
        }
    }
    
    private func recordTimelineSegment(in summary: inout DailyAppUsageSummary, now: Date, elapsed: TimeInterval) {
        if let last = summary.timelineSegments.last,
           last.bundleIdentifier == currentAppBundleID,
           now.timeIntervalSince(last.endTime) < 5.0 {
            // Extend existing segment
            let updated = TimelineSegment(
                id: last.id,
                appName: last.appName,
                bundleIdentifier: last.bundleIdentifier,
                category: last.category,
                startTime: last.startTime,
                endTime: now,
                duration: last.duration + elapsed
            )
            summary.timelineSegments[summary.timelineSegments.count - 1] = updated
        } else {
            // New segment
            let seg = TimelineSegment(
                appName: currentAppName,
                bundleIdentifier: currentAppBundleID,
                category: currentAppCategory,
                startTime: now.addingTimeInterval(-elapsed),
                endTime: now,
                duration: elapsed
            )
            summary.timelineSegments.append(seg)
            // Limit timeline segments to recent 300 to avoid runaway memory
            if summary.timelineSegments.count > 300 {
                summary.timelineSegments.removeFirst(summary.timelineSegments.count - 300)
            }
        }
    }
    
    // MARK: - Disk Persistence
    public func saveHistoryToDisk() {
        do {
            let data = try JSONEncoder().encode(dailyRecords)
            try data.write(to: storageFileURL, options: .atomic)
        } catch {
            print("Failed saving Screen Time history: \(error)")
        }
    }
    
    public func loadHistoryFromDisk() {
        guard FileManager.default.fileExists(atPath: storageFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageFileURL)
            let loaded = try JSONDecoder().decode([String: DailyAppUsageSummary].self, from: data)
            self.dailyRecords = loaded
        } catch {
            print("Failed loading Screen Time history: \(error)")
        }
    }
    
    public func clearAllHistory() {
        dailyRecords.removeAll()
        try? FileManager.default.removeItem(at: storageFileURL)
    }
    
    // MARK: - Exclusions
    public func toggleExclusion(for bundleID: String) {
        if excludedBundleIDs.contains(bundleID) {
            excludedBundleIDs.remove(bundleID)
        } else {
            excludedBundleIDs.insert(bundleID)
        }
    }
    
    public func isExcluded(_ bundleID: String) -> Bool {
        excludedBundleIDs.contains(bundleID)
    }
    
    // MARK: - Query & Aggregation Engine
    
    /// Returns the active days within the selected range option.
    public func getDays(for range: ScreenTimeRangeOption) -> [DailyAppUsageSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let limitDays = range.numberOfDays
        
        var results: [DailyAppUsageSummary] = []
        for dayOffset in (0..<limitDays).reversed() {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let key = dateFormatter.string(from: targetDate)
            if let record = dailyRecords[key] {
                results.append(record)
            } else {
                results.append(DailyAppUsageSummary(dayKey: key, date: targetDate))
            }
        }
        return results
    }
    
    /// Aggregated application usage across the selected range with active filtering.
    public func getFilteredAppAggregates(for range: ScreenTimeRangeOption) -> [AppUsageAggregate] {
        let days = getDays(for: range)
        var combined: [String: AppUsageAggregate] = [:]
        
        for day in days {
            for (bundleID, app) in day.appBreakdown {
                if isExcluded(bundleID) { continue }
                if let existing = combined[bundleID] {
                    var updated = existing
                    updated.totalDuration += app.totalDuration
                    updated.activeDuration += app.activeDuration
                    updated.idleDuration += app.idleDuration
                    updated.sessionCount += app.sessionCount
                    updated.lastSeen = max(existing.lastSeen, app.lastSeen)
                    combined[bundleID] = updated
                } else {
                    combined[bundleID] = app
                }
            }
        }
        
        var list = Array(combined.values)
        
        // Search Filter
        if !filterSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = filterSearchText.lowercased()
            list = list.filter {
                $0.appName.lowercased().contains(query) ||
                $0.bundleIdentifier.lowercased().contains(query)
            }
        }
        
        // Category Filter
        if let cat = filterCategory {
            list = list.filter { $0.category == cat }
        }
        
        // Minimum Duration Filter
        if minDurationSeconds > 0 {
            list = list.filter { $0.totalDuration >= minDurationSeconds }
        }
        
        return list.sorted { $0.totalDuration > $1.totalDuration }
    }
    
    /// Category distribution for donut charts.
    public func getCategoryBreakdown(for range: ScreenTimeRangeOption) -> [CategoryBreakdownItem] {
        let apps = getFilteredAppAggregates(for: range)
        let totalTime = apps.reduce(0.0) { $0 + $1.totalDuration }
        guard totalTime > 0 else { return [] }
        
        var catTotals: [AppUsageCategory: (total: TimeInterval, active: TimeInterval, idle: TimeInterval)] = [:]
        for app in apps {
            let curr = catTotals[app.category] ?? (0, 0, 0)
            catTotals[app.category] = (
                curr.total + app.totalDuration,
                curr.active + app.activeDuration,
                curr.idle + app.idleDuration
            )
        }
        
        return catTotals.map { cat, values in
            let pct = (values.total / totalTime) * 100.0
            return CategoryBreakdownItem(
                category: cat,
                totalDuration: values.total,
                activeDuration: values.active,
                idleDuration: values.idle,
                percentage: pct
            )
        }.sorted { $0.totalDuration > $1.totalDuration }
    }
    
    /// Daily trend data for bar / area charts.
    public func getDailyTrend(for range: ScreenTimeRangeOption) -> [DailyTrendPoint] {
        let days = getDays(for: range)
        return days.map { day in
            let label = displayDateFormatter.string(from: day.date)
            return DailyTrendPoint(
                dayKey: day.dayKey,
                date: day.date,
                activeSeconds: day.totalActiveDuration,
                idleSeconds: day.totalIdleDuration,
                label: label
            )
        }
    }
    
    /// Summary cards statistics calculation.
    public func getStatistics() -> ScreenTimeStatistics {
        let todayKey = dateFormatter.string(from: Date())
        let todayRecord = dailyRecords[todayKey]
        
        let todayActive = todayRecord?.totalActiveDuration ?? 0
        let todayIdle = todayRecord?.totalIdleDuration ?? 0
        let todayTotal = todayRecord?.totalForegroundDuration ?? 0
        
        // 7 Days
        let weekDays = getDays(for: .week)
        let weekTotal = weekDays.reduce(0.0) { $0 + $1.totalActiveDuration }
        let dailyAvg7Days = weekDays.isEmpty ? 0 : (weekTotal / Double(weekDays.count))
        
        // 30 Days
        let monthDays = getDays(for: .month)
        let monthTotal = monthDays.reduce(0.0) { $0 + $1.totalActiveDuration }
        let monthlyDailyAvg = monthDays.isEmpty ? 0 : (monthTotal / Double(monthDays.count))
        
        // Most used apps
        let todayTop = getFilteredAppAggregates(for: .today).first.map { ($0.appName, $0.totalDuration, $0.category) }
        let weekTop = getFilteredAppAggregates(for: .week).first.map { ($0.appName, $0.totalDuration, $0.category) }
        let monthTop = getFilteredAppAggregates(for: .month).first.map { ($0.appName, $0.totalDuration, $0.category) }
        
        return ScreenTimeStatistics(
            todayActiveDuration: todayActive,
            todayIdleDuration: todayIdle,
            todayTotalForegroundDuration: todayTotal,
            dailyAverage7Days: dailyAvg7Days,
            weeklyTotalDuration: weekTotal,
            monthlyTotalDuration: monthTotal,
            monthlyDailyAverage: monthlyDailyAvg,
            mostUsedAppToday: todayTop,
            mostUsedAppWeek: weekTop,
            mostUsedAppMonth: monthTop,
            systemUptime: ProcessInfo.processInfo.systemUptime
        )
    }
    
    // MARK: - CSV Export
    public func generateCSVReport(for range: ScreenTimeRangeOption) -> String {
        let apps = getFilteredAppAggregates(for: range)
        var csv = "Application,Category,Bundle Identifier,Total Seconds,Formatted Total,Active Seconds,Idle Seconds,Active %,Sessions\n"
        
        for app in apps {
            let activePct = String(format: "%.1f%%", app.activePercentage)
            let formattedDuration = Formatters.duration(app.totalDuration, showSeconds: true)
            let row = "\"\(app.appName.replacingOccurrences(of: "\"", with: "\"\""))\",\"\(app.category.rawValue)\",\"\(app.bundleIdentifier)\",\(Int(app.totalDuration)),\"\(formattedDuration)\",\(Int(app.activeDuration)),\(Int(app.idleDuration)),\"\(activePct)\",\(app.sessionCount)\n"
            csv.append(row)
        }
        return csv
    }
    
    // MARK: - Sample Demo Data Generator (For Testing / Immediate Preview)
    public func generateSampleHistoryIfEmpty() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let sampleCatalog: [(name: String, bundle: String, cat: AppUsageCategory, weight: Double)] = [
            ("Xcode", "com.apple.dt.Xcode", .developer, 3.2),
            ("Cursor", "com.anysphere.cursor", .developer, 2.8),
            ("Safari", "com.apple.Safari", .browsers, 2.5),
            ("Slack", "com.tinyspeck.slackmacgap", .social, 1.4),
            ("Figma", "com.figma.Desktop", .creativity, 1.9),
            ("Notes", "com.apple.Notes", .productivity, 0.8),
            ("Terminal", "com.apple.Terminal", .developer, 1.1),
            ("Spotify", "com.spotify.client", .media, 1.5),
            ("Borno Pulse", "com.naem.smart-tool", .utilities, 0.6),
            ("System Settings", "com.apple.systempreferences", .system, 0.3)
        ]
        
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let key = dateFormatter.string(from: date)
            if dailyRecords[key] != nil { continue } // don't overwrite real data
            
            var summary = DailyAppUsageSummary(dayKey: key, date: date)
            let dayFactor = Double.random(in: 0.7...1.3)
            
            for item in sampleCatalog {
                let duration = (item.weight * 3600.0 * dayFactor) * Double.random(in: 0.8...1.2)
                let idle = duration * Double.random(in: 0.05...0.20)
                let active = duration - idle
                
                let app = AppUsageAggregate(
                    bundleIdentifier: item.bundle,
                    appName: item.name,
                    category: item.cat,
                    totalDuration: duration,
                    activeDuration: active,
                    idleDuration: idle,
                    sessionCount: Int.random(in: 4...18),
                    firstSeen: date,
                    lastSeen: date.addingTimeInterval(duration)
                )
                summary.appBreakdown[item.bundle] = app
                summary.totalForegroundDuration += duration
                summary.totalActiveDuration += active
                summary.totalIdleDuration += idle
            }
            
            // Populate hourly buckets
            for h in 0..<24 {
                let isWorkHour = (h >= 9 && h <= 19)
                let activeSecs = isWorkHour ? Double.random(in: 900...2700) : Double.random(in: 0...400)
                let idleSecs = activeSecs * Double.random(in: 0.05...0.2)
                summary.hourlyBuckets[h] = HourlyUsageBucket(hour: h, activeDuration: activeSecs, idleDuration: idleSecs)
            }
            
            // Sample websites
            summary.websiteBreakdown["github.com"] = WebsiteUsageAggregate(domain: "github.com", browserName: "Safari", totalDuration: 3600 * dayFactor, visitCount: 15)
            summary.websiteBreakdown["developer.apple.com"] = WebsiteUsageAggregate(domain: "developer.apple.com", browserName: "Safari", totalDuration: 2400 * dayFactor, visitCount: 8)
            summary.websiteBreakdown["stackoverflow.com"] = WebsiteUsageAggregate(domain: "stackoverflow.com", browserName: "Safari", totalDuration: 1800 * dayFactor, visitCount: 12)
            
            dailyRecords[key] = summary
        }
        
        saveHistoryToDisk()
    }
}
