//
//  ScreenTimeModels.swift
//  Naem Smart Tool
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Application Usage Category
public enum AppUsageCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case developer = "Developer & Code"
    case productivity = "Productivity & Office"
    case browsers = "Web Browsing"
    case social = "Social & Messaging"
    case media = "Media & Streaming"
    case creativity = "Design & Creativity"
    case utilities = "Utilities & System Tools"
    case system = "macOS & System"
    case other = "Other Applications"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .productivity: return "doc.text.fill"
        case .browsers: return "safari.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .media: return "play.rectangle.fill"
        case .creativity: return "paintpalette.fill"
        case .utilities: return "wrench.and.screwdriver.fill"
        case .system: return "applelogo"
        case .other: return "app.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .developer: return AppTheme.electricBlue
        case .productivity: return AppTheme.matrixGreen
        case .browsers: return AppTheme.electricCyan
        case .social: return AppTheme.purpleAccent
        case .media: return AppTheme.orangeAccent
        case .creativity: return Color(red: 0.96, green: 0.35, blue: 0.65)
        case .utilities: return AppTheme.warningAmber
        case .system: return Color(red: 0.65, green: 0.68, blue: 0.75)
        case .other: return Color(red: 0.45, green: 0.48, blue: 0.55)
        }
    }
    
    public static func classify(bundleIdentifier: String, appName: String) -> AppUsageCategory {
        let b = bundleIdentifier.lowercased()
        let n = appName.lowercased()
        
        // Developer tools
        if b.contains("xcode") || b.contains("terminal") || b.contains("iterm") ||
           b.contains("vscode") || b.contains("vscodium") || b.contains("sublime") ||
           b.contains("cursor") || b.contains("intellij") || b.contains("pycharm") ||
           b.contains("webstorm") || b.contains("docker") || b.contains("postman") ||
           b.contains("simulator") || b.contains("git") || b.contains("tower") ||
           b.contains("sourcetree") || b.contains("fork") ||
           n.contains("xcode") || n.contains("terminal") || n.contains("iterm") ||
           n.contains("vs code") || n.contains("cursor") || n.contains("intellij") ||
           n.contains("docker") || n.contains("postman") {
            return .developer
        }
        
        // Browsers
        if b.contains("safari") || b.contains("chrome") || b.contains("firefox") ||
           b.contains("brave") || b.contains("edge") || b.contains("arc") ||
           b.contains("orion") || b.contains("opera") || b.contains("vivaldi") ||
           n.contains("safari") || n.contains("chrome") || n.contains("firefox") ||
           n.contains("brave") || n.contains("edge") || n.contains("arc browser") {
            return .browsers
        }
        
        // Social & Messaging
        if b.contains("slack") || b.contains("discord") || b.contains("telegram") ||
           b.contains("whatsapp") || b.contains("messages") || b.contains("zoom") ||
           b.contains("teams") || b.contains("skype") || b.contains("signal") ||
           b.contains("mattermost") || b.contains("wechat") ||
           n.contains("slack") || n.contains("discord") || n.contains("telegram") ||
           n.contains("whatsapp") || n.contains("messages") || n.contains("zoom") ||
           n.contains("teams") {
            return .social
        }
        
        // Productivity & Office
        if b.contains("notes") || b.contains("reminders") || b.contains("pages") ||
           b.contains("numbers") || b.contains("keynote") || b.contains("word") ||
           b.contains("excel") || b.contains("powerpoint") || b.contains("notion") ||
           b.contains("obsidian") || b.contains("calendar") || b.contains("mail") ||
           b.contains("craft") || b.contains("things") || b.contains("omnifocus") ||
           b.contains("bear") || b.contains("ticktick") || b.contains("linear") ||
           n.contains("notes") || n.contains("reminders") || n.contains("notion") ||
           n.contains("obsidian") || n.contains("calendar") || n.contains("mail") ||
           n.contains("excel") || n.contains("word") {
            return .productivity
        }
        
        // Design & Creativity
        if b.contains("figma") || b.contains("photoshop") || b.contains("illustrator") ||
           b.contains("indesign") || b.contains("premiere") || b.contains("aftereffects") ||
           b.contains("sketch") || b.contains("blender") || b.contains("lightroom") ||
           b.contains("finalcut") || b.contains("davinci") || b.contains("affinity") ||
           n.contains("figma") || n.contains("photoshop") || n.contains("illustrator") ||
           n.contains("sketch") || n.contains("blender") || n.contains("canva") {
            return .creativity
        }
        
        // Media & Streaming
        if b.contains("music") || b.contains("spotify") || b.contains("podcasts") ||
           b.contains("vlc") || b.contains("iina") || b.contains("quicktime") ||
           b.contains("tv") || b.contains("netflix") || b.contains("youtube") ||
           n.contains("music") || n.contains("spotify") || n.contains("podcasts") ||
           n.contains("vlc") || n.contains("iina") || n.contains("quicktime") {
            return .media
        }
        
        // Utilities & Tools
        if b.contains("smart tool") || b.contains("finder") || b.contains("activitymonitor") ||
           b.contains("archiveutility") || b.contains("diskutility") || b.contains("keychain") ||
           b.contains("raycast") || b.contains("alfred") || b.contains("cleanshot") ||
           b.contains("1password") || b.contains("bitwarden") || b.contains("bartender") ||
           n.contains("finder") || n.contains("activity monitor") || n.contains("raycast") ||
           n.contains("smart tool") || n.contains("disk utility") {
            return .utilities
        }
        
        // macOS & System
        if b.contains("systempreferences") || b.contains("systemsettings") ||
           b.contains("windowserver") || b.contains("dock") || b.contains("loginwindow") ||
           b.contains("controlcenter") || b.contains("coreauth") ||
           n.contains("system settings") || n.contains("system preferences") {
            return .system
        }
        
        return .other
    }
}

// MARK: - App Session Record
public struct AppSessionRecord: Identifiable, Codable, Sendable {
    public let id: UUID
    public let bundleIdentifier: String
    public let appName: String
    public let category: AppUsageCategory
    public let startTime: Date
    public var endTime: Date
    public var duration: TimeInterval
    public var idleDuration: TimeInterval
    public var activeDuration: TimeInterval {
        max(0, duration - idleDuration)
    }
    public var activeWebsiteDomain: String?
    
    public init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appName: String,
        category: AppUsageCategory,
        startTime: Date,
        endTime: Date,
        duration: TimeInterval,
        idleDuration: TimeInterval = 0,
        activeWebsiteDomain: String? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.idleDuration = idleDuration
        self.activeWebsiteDomain = activeWebsiteDomain
    }
}

// MARK: - Application Usage Aggregate Item
public struct AppUsageAggregate: Identifiable, Codable, Sendable {
    public var id: String { bundleIdentifier }
    public let bundleIdentifier: String
    public var appName: String
    public var category: AppUsageCategory
    public var totalDuration: TimeInterval
    public var activeDuration: TimeInterval
    public var idleDuration: TimeInterval
    public var sessionCount: Int
    public var firstSeen: Date
    public var lastSeen: Date
    
    public var activePercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return (activeDuration / totalDuration) * 100.0
    }
    
    public init(
        bundleIdentifier: String,
        appName: String,
        category: AppUsageCategory,
        totalDuration: TimeInterval = 0,
        activeDuration: TimeInterval = 0,
        idleDuration: TimeInterval = 0,
        sessionCount: Int = 0,
        firstSeen: Date = Date(),
        lastSeen: Date = Date()
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.category = category
        self.totalDuration = totalDuration
        self.activeDuration = activeDuration
        self.idleDuration = idleDuration
        self.sessionCount = sessionCount
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
    }
}

// MARK: - Website Usage Aggregate (Safe Standalone Tracking)
public struct WebsiteUsageAggregate: Identifiable, Codable, Sendable {
    public var id: String { domain }
    public let domain: String
    public var browserName: String
    public var totalDuration: TimeInterval
    public var visitCount: Int
    
    public init(domain: String, browserName: String, totalDuration: TimeInterval = 0, visitCount: Int = 0) {
        self.domain = domain
        self.browserName = browserName
        self.totalDuration = totalDuration
        self.visitCount = visitCount
    }
}

// MARK: - Hourly Usage Bucket
public struct HourlyUsageBucket: Identifiable, Codable, Sendable {
    public var id: Int { hour }
    public let hour: Int // 0..23
    public var activeDuration: TimeInterval
    public var idleDuration: TimeInterval
    
    public var totalDuration: TimeInterval {
        activeDuration + idleDuration
    }
    
    public init(hour: Int, activeDuration: TimeInterval = 0, idleDuration: TimeInterval = 0) {
        self.hour = hour
        self.activeDuration = activeDuration
        self.idleDuration = idleDuration
    }
}

// MARK: - Timeline Segment (Gantt Visualization)
public struct TimelineSegment: Identifiable, Codable, Sendable {
    public let id: UUID
    public let appName: String
    public let bundleIdentifier: String
    public let category: AppUsageCategory
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
    
    public init(
        id: UUID = UUID(),
        appName: String,
        bundleIdentifier: String,
        category: AppUsageCategory,
        startTime: Date,
        endTime: Date,
        duration: TimeInterval
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
    }
}

// MARK: - Daily App Usage Summary
public struct DailyAppUsageSummary: Identifiable, Codable, Sendable {
    public var id: String { dayKey }
    public let dayKey: String // "yyyy-MM-dd"
    public let date: Date
    public var totalForegroundDuration: TimeInterval
    public var totalActiveDuration: TimeInterval
    public var totalIdleDuration: TimeInterval
    public var appBreakdown: [String: AppUsageAggregate] // bundleID -> aggregate
    public var websiteBreakdown: [String: WebsiteUsageAggregate] // domain -> aggregate
    public var hourlyBuckets: [HourlyUsageBucket]
    public var timelineSegments: [TimelineSegment]
    
    public init(
        dayKey: String,
        date: Date,
        totalForegroundDuration: TimeInterval = 0,
        totalActiveDuration: TimeInterval = 0,
        totalIdleDuration: TimeInterval = 0,
        appBreakdown: [String: AppUsageAggregate] = [:],
        websiteBreakdown: [String: WebsiteUsageAggregate] = [:],
        hourlyBuckets: [HourlyUsageBucket] = (0..<24).map { HourlyUsageBucket(hour: $0) },
        timelineSegments: [TimelineSegment] = []
    ) {
        self.dayKey = dayKey
        self.date = date
        self.totalForegroundDuration = totalForegroundDuration
        self.totalActiveDuration = totalActiveDuration
        self.totalIdleDuration = totalIdleDuration
        self.appBreakdown = appBreakdown
        self.websiteBreakdown = websiteBreakdown
        self.hourlyBuckets = hourlyBuckets
        self.timelineSegments = timelineSegments
    }
    
    public var sortedApps: [AppUsageAggregate] {
        appBreakdown.values.sorted { $0.totalDuration > $1.totalDuration }
    }
    
    public var sortedWebsites: [WebsiteUsageAggregate] {
        websiteBreakdown.values.sorted { $0.totalDuration > $1.totalDuration }
    }
}

// MARK: - Screen Time Range Option
public enum ScreenTimeRangeOption: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Last 7 Days"
    case month = "Last 30 Days"
    
    public var id: String { rawValue }
    
    public var numberOfDays: Int {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        }
    }
}

// MARK: - Aggregated Screen Time Statistics
public struct ScreenTimeStatistics: Sendable {
    public var todayActiveDuration: TimeInterval
    public var todayIdleDuration: TimeInterval
    public var todayTotalForegroundDuration: TimeInterval
    public var dailyAverage7Days: TimeInterval
    public var weeklyTotalDuration: TimeInterval
    public var monthlyTotalDuration: TimeInterval
    public var monthlyDailyAverage: TimeInterval
    public var mostUsedAppToday: (name: String, duration: TimeInterval, category: AppUsageCategory)?
    public var mostUsedAppWeek: (name: String, duration: TimeInterval, category: AppUsageCategory)?
    public var mostUsedAppMonth: (name: String, duration: TimeInterval, category: AppUsageCategory)?
    public var systemUptime: TimeInterval
    
    public init(
        todayActiveDuration: TimeInterval = 0,
        todayIdleDuration: TimeInterval = 0,
        todayTotalForegroundDuration: TimeInterval = 0,
        dailyAverage7Days: TimeInterval = 0,
        weeklyTotalDuration: TimeInterval = 0,
        monthlyTotalDuration: TimeInterval = 0,
        monthlyDailyAverage: TimeInterval = 0,
        mostUsedAppToday: (name: String, duration: TimeInterval, category: AppUsageCategory)? = nil,
        mostUsedAppWeek: (name: String, duration: TimeInterval, category: AppUsageCategory)? = nil,
        mostUsedAppMonth: (name: String, duration: TimeInterval, category: AppUsageCategory)? = nil,
        systemUptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        self.todayActiveDuration = todayActiveDuration
        self.todayIdleDuration = todayIdleDuration
        self.todayTotalForegroundDuration = todayTotalForegroundDuration
        self.dailyAverage7Days = dailyAverage7Days
        self.weeklyTotalDuration = weeklyTotalDuration
        self.monthlyTotalDuration = monthlyTotalDuration
        self.monthlyDailyAverage = monthlyDailyAverage
        self.mostUsedAppToday = mostUsedAppToday
        self.mostUsedAppWeek = mostUsedAppWeek
        self.mostUsedAppMonth = mostUsedAppMonth
        self.systemUptime = systemUptime
    }
}
