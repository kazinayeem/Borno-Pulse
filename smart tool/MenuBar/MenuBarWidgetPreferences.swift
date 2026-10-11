//
//  MenuBarWidgetPreferences.swift
//  Borno Pulse
//
//  Comprehensive preferences, metric registry, and persistence model
//  for the customizable menu bar widget and mini dashboard.
//

import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - Metric Categories
public enum WidgetMetricCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case cpu = "CPU"
    case memory = "Memory"
    case gpu = "GPU & Neural Engine"
    case thermal = "Temperature & Fans"
    case battery = "Battery & Power"
    case storage = "Storage"
    case network = "Network"
    case system = "System"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .gpu: return "circle.grid.cross"
        case .thermal: return "thermometer.medium"
        case .battery: return "battery.100.bolt"
        case .storage: return "internaldrive"
        case .network: return "network"
        case .system: return "macbook.and.iphone"
        }
    }
}

// MARK: - Widget Metric IDs (Stable Identifiers)
public enum WidgetMetricId: String, CaseIterable, Identifiable, Codable, Sendable {
    // CPU
    case cpuTotalUsage = "cpu_total_usage"
    case cpuUserUsage = "cpu_user_usage"
    case cpuSystemUsage = "cpu_system_usage"
    case cpuIdleUsage = "cpu_idle_usage"
    case cpuCoreCount = "cpu_core_count"
    case cpuFrequency = "cpu_frequency"
    case cpuLoadTrend = "cpu_load_trend"

    // Memory
    case memoryUsed = "memory_used"
    case memoryAvailable = "memory_available"
    case memoryTotal = "memory_total"
    case memoryPressure = "memory_pressure"
    case memorySwap = "memory_swap"
    case memoryUsagePercent = "memory_usage_percent"

    // GPU & Neural Engine
    case gpuUtilization = "gpu_utilization"
    case gpuDeviceInfo = "gpu_device_info"
    case gpuMemory = "gpu_memory"
    case neuralEngineAvailability = "neural_engine_availability"

    // Temperature & Fans
    case cpuTemperature = "cpu_temperature"
    case gpuTemperature = "gpu_temperature"
    case batteryTemperature = "battery_temperature"
    case ssdTemperature = "ssd_temperature"
    case fanSpeed = "fan_speed"
    case thermalPressure = "thermal_pressure"

    // Battery & Power
    case batteryPercentage = "battery_percentage"
    case batteryTimeRemaining = "battery_time_remaining"
    case batteryTimeUntilFull = "battery_time_until_full"
    case batteryState = "battery_state"
    case batteryHealth = "battery_health"
    case batteryCycleCount = "battery_cycle_count"
    case batteryChargingWatts = "battery_charging_watts"
    case batteryDischargingWatts = "battery_discharging_watts"
    case systemPowerWatts = "system_power_watts"
    case powerAdapterInfo = "power_adapter_info"

    // Storage
    case storageFree = "storage_free"
    case storageUsed = "storage_used"
    case storageTotal = "storage_total"
    case storageUsagePercent = "storage_usage_percent"
    case storageVolume = "storage_volume"
    case storageWarning = "storage_warning"

    // Network
    case networkDownload = "network_download"
    case networkUpload = "network_upload"
    case networkInterface = "network_interface"
    case networkStatus = "network_status"
    case networkSessionTransferred = "network_session_transferred"
    case wifiSignal = "wifi_signal"
    case publicIP = "public_ip"

    // System
    case systemUptime = "system_uptime"
    case systemActiveApp = "system_active_app"
    case systemProcessCount = "system_process_count"
    case systemHealthSummary = "system_health_summary"
    case monitoringStatus = "monitoring_status"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpuTotalUsage: return "CPU Utilization"
        case .cpuUserUsage: return "User CPU %"
        case .cpuSystemUsage: return "System CPU %"
        case .cpuIdleUsage: return "Idle CPU %"
        case .cpuCoreCount: return "Logical Core Count"
        case .cpuFrequency: return "CPU Frequency"
        case .cpuLoadTrend: return "CPU Load Trend"

        case .memoryUsed: return "Used RAM"
        case .memoryAvailable: return "Available RAM"
        case .memoryTotal: return "Total Physical RAM"
        case .memoryPressure: return "Memory Pressure"
        case .memorySwap: return "Swap Memory Used"
        case .memoryUsagePercent: return "Memory Utilization %"

        case .gpuUtilization: return "GPU Utilization"
        case .gpuDeviceInfo: return "GPU Device Info"
        case .gpuMemory: return "GPU Memory In-Use"
        case .neuralEngineAvailability: return "Neural Engine Status"

        case .cpuTemperature: return "CPU Temperature"
        case .gpuTemperature: return "GPU Temperature"
        case .batteryTemperature: return "Battery Temperature"
        case .ssdTemperature: return "SSD Temperature"
        case .fanSpeed: return "Fan Speed (RPM)"
        case .thermalPressure: return "Thermal State (Pressure)"

        case .batteryPercentage: return "Battery Level"
        case .batteryTimeRemaining: return "Estimated Time Remaining"
        case .batteryTimeUntilFull: return "Time Until Full"
        case .batteryState: return "Charge State"
        case .batteryHealth: return "Battery Health & Capacity"
        case .batteryCycleCount: return "Cycle Count"
        case .batteryChargingWatts: return "Charging Power (Watts)"
        case .batteryDischargingWatts: return "Discharging Power (Watts)"
        case .systemPowerWatts: return "System Load (Watts)"
        case .powerAdapterInfo: return "Power Adapter Details"

        case .storageFree: return "Free Disk Space"
        case .storageUsed: return "Used Disk Space"
        case .storageTotal: return "Total Disk Capacity"
        case .storageUsagePercent: return "Disk Utilization %"
        case .storageVolume: return "Selected Volume"
        case .storageWarning: return "Storage Capacity Warning"

        case .networkDownload: return "Download Speed"
        case .networkUpload: return "Upload Speed"
        case .networkInterface: return "Active Interface"
        case .networkStatus: return "Connection Status"
        case .networkSessionTransferred: return "Session Data Transferred"
        case .wifiSignal: return "Wi-Fi Signal Info"
        case .publicIP: return "Public IP Lookup"

        case .systemUptime: return "System Uptime"
        case .systemActiveApp: return "Frontmost App"
        case .systemProcessCount: return "Active Process Count"
        case .systemHealthSummary: return "System Health Score"
        case .monitoringStatus: return "Engine Monitoring Status"
        }
    }

    public var category: WidgetMetricCategory {
        switch self {
        case .cpuTotalUsage, .cpuUserUsage, .cpuSystemUsage, .cpuIdleUsage, .cpuCoreCount, .cpuFrequency, .cpuLoadTrend:
            return .cpu
        case .memoryUsed, .memoryAvailable, .memoryTotal, .memoryPressure, .memorySwap, .memoryUsagePercent:
            return .memory
        case .gpuUtilization, .gpuDeviceInfo, .gpuMemory, .neuralEngineAvailability:
            return .gpu
        case .cpuTemperature, .gpuTemperature, .batteryTemperature, .ssdTemperature, .fanSpeed, .thermalPressure:
            return .thermal
        case .batteryPercentage, .batteryTimeRemaining, .batteryTimeUntilFull, .batteryState, .batteryHealth,
             .batteryCycleCount, .batteryChargingWatts, .batteryDischargingWatts, .systemPowerWatts, .powerAdapterInfo:
            return .battery
        case .storageFree, .storageUsed, .storageTotal, .storageUsagePercent, .storageVolume, .storageWarning:
            return .storage
        case .networkDownload, .networkUpload, .networkInterface, .networkStatus, .networkSessionTransferred, .wifiSignal, .publicIP:
            return .network
        case .systemUptime, .systemActiveApp, .systemProcessCount, .systemHealthSummary, .monitoringStatus:
            return .system
        }
    }

    public var icon: String {
        switch self {
        case .cpuTotalUsage, .cpuLoadTrend: return "cpu"
        case .cpuUserUsage: return "person.fill"
        case .cpuSystemUsage: return "gearshape.2.fill"
        case .cpuIdleUsage: return "moon.stars.fill"
        case .cpuCoreCount: return "square.grid.3x3.fill"
        case .cpuFrequency: return "waveform.path.ecg"

        case .memoryUsed, .memoryUsagePercent: return "memorychip"
        case .memoryAvailable: return "archivebox"
        case .memoryTotal: return "server.rack"
        case .memoryPressure: return "gauge.medium"
        case .memorySwap: return "arrow.triangle.swap"

        case .gpuUtilization: return "circle.grid.cross.fill"
        case .gpuDeviceInfo: return "display"
        case .gpuMemory: return "memorychip.fill"
        case .neuralEngineAvailability: return "brain.head.profile"

        case .cpuTemperature: return "thermometer.sun.fill"
        case .gpuTemperature: return "thermometer.high"
        case .batteryTemperature: return "thermometer.medium"
        case .ssdTemperature: return "internaldrive"
        case .fanSpeed: return "fanblades.fill"
        case .thermalPressure: return "flame.fill"

        case .batteryPercentage, .batteryState: return "battery.100.bolt"
        case .batteryTimeRemaining: return "clock.fill"
        case .batteryTimeUntilFull: return "bolt.badge.clock.fill"
        case .batteryHealth: return "heart.text.square.fill"
        case .batteryCycleCount: return "arrow.triangle.2.circlepath"
        case .batteryChargingWatts: return "bolt.fill"
        case .batteryDischargingWatts: return "bolt.slash.fill"
        case .systemPowerWatts: return "powercord.fill"
        case .powerAdapterInfo: return "powerplug.fill"

        case .storageFree, .storageTotal: return "internaldrive"
        case .storageUsed, .storageUsagePercent: return "internaldrive.fill"
        case .storageVolume: return "externaldrive.fill"
        case .storageWarning: return "exclamationmark.triangle.fill"

        case .networkDownload: return "arrow.down.circle.fill"
        case .networkUpload: return "arrow.up.circle.fill"
        case .networkInterface: return "cable.connector"
        case .networkStatus: return "wifi"
        case .networkSessionTransferred: return "arrow.up.arrow.down"
        case .wifiSignal: return "antenna.radiowaves.left.and.right"
        case .publicIP: return "globe"

        case .systemUptime: return "hourglass"
        case .systemActiveApp: return "app.window.checkmark"
        case .systemProcessCount: return "list.bullet.rectangle"
        case .systemHealthSummary: return "waveform.path.ecg.rectangle"
        case .monitoringStatus: return "checkmark.seal.fill"
        }
    }

    public var dashboardSection: NavigationSection {
        switch self {
        case .cpuTotalUsage, .cpuUserUsage, .cpuSystemUsage, .cpuIdleUsage, .cpuCoreCount, .cpuFrequency, .cpuLoadTrend:
            return .cpu
        case .memoryUsed, .memoryAvailable, .memoryTotal, .memoryPressure, .memorySwap, .memoryUsagePercent:
            return .memory
        case .gpuUtilization, .gpuDeviceInfo, .gpuMemory, .neuralEngineAvailability:
            return .gpu
        case .cpuTemperature, .gpuTemperature, .batteryTemperature, .ssdTemperature, .fanSpeed, .thermalPressure:
            return .sensors
        case .batteryPercentage, .batteryTimeRemaining, .batteryTimeUntilFull, .batteryState, .batteryHealth,
             .batteryCycleCount, .batteryChargingWatts, .batteryDischargingWatts, .systemPowerWatts, .powerAdapterInfo:
            return .battery
        case .storageFree, .storageUsed, .storageTotal, .storageUsagePercent, .storageVolume, .storageWarning:
            return .storage
        case .networkDownload, .networkUpload, .networkInterface, .networkStatus, .networkSessionTransferred, .wifiSignal, .publicIP:
            return .network
        case .systemUptime, .systemActiveApp, .systemProcessCount, .systemHealthSummary, .monitoringStatus:
            return .overview
        }
    }
}

// MARK: - Layout Style
public enum WidgetLayoutStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case compact = "Compact"
    case balanced = "Balanced"
    case detailed = "Detailed"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .compact: return "Minimalist values with concise badges and icons."
        case .balanced: return "Clean cards with metric labels, values, and progress bars."
        case .detailed: return "Full data rows with live sparklines, trends, and secondary details."
        }
    }
}

// MARK: - Quick Action ID
public enum WidgetQuickActionId: String, CaseIterable, Identifiable, Codable, Sendable {
    case openDashboard = "open_dashboard"
    case openSystemMonitor = "open_system_monitor"
    case openBattery = "open_battery"
    case openStorage = "open_storage"
    case openNetwork = "open_network"
    case openFocus = "open_focus"
    case openCleaner = "open_cleaner"
    case openSettings = "open_settings"
    case refreshMetrics = "refresh_metrics"
    case quit = "quit"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .openDashboard: return "Overview"
        case .openSystemMonitor: return "CPU & Cores"
        case .openBattery: return "Battery"
        case .openStorage: return "Storage Analytics"
        case .openNetwork: return "Network"
        case .openFocus: return "Focus Timer"
        case .openCleaner: return "Cache Cleaner"
        case .openSettings: return "Settings"
        case .refreshMetrics: return "Refresh"
        case .quit: return "Quit"
        }
    }

    public var icon: String {
        switch self {
        case .openDashboard: return "square.grid.2x2"
        case .openSystemMonitor: return "cpu"
        case .openBattery: return "battery.100.bolt"
        case .openStorage: return "chart.pie.fill"
        case .openNetwork: return "network"
        case .openFocus: return "timer"
        case .openCleaner: return "sparkles"
        case .openSettings: return "gearshape"
        case .refreshMetrics: return "arrow.clockwise"
        case .quit: return "power"
        }
    }
}

// MARK: - Extracted Metric Value Representation
public struct WidgetExtractedMetric: Sendable {
    public let id: WidgetMetricId
    public let title: String
    public let icon: String
    public let category: WidgetMetricCategory
    public let formattedValue: String
    public let secondaryValue: String?
    public let progress: Double? // 0.0 to 1.0
    public let sparkline: [Double]?
    public let isAvailable: Bool
    public let availabilityNote: String?
    public let dashboardSection: NavigationSection

    public init(
        id: WidgetMetricId,
        title: String,
        icon: String,
        category: WidgetMetricCategory,
        formattedValue: String,
        secondaryValue: String? = nil,
        progress: Double? = nil,
        sparkline: [Double]? = nil,
        isAvailable: Bool = true,
        availabilityNote: String? = nil,
        dashboardSection: NavigationSection
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.category = category
        self.formattedValue = formattedValue
        self.secondaryValue = secondaryValue
        self.progress = progress
        self.sparkline = sparkline
        self.isAvailable = isAvailable
        self.availabilityNote = availabilityNote
        self.dashboardSection = dashboardSection
    }
}

// MARK: - Preferences Manager
@MainActor
public final class MenuBarWidgetPreferences: ObservableObject {
    public static let shared = MenuBarWidgetPreferences()

    // MARK: - Keys
    private let kEnabledMetrics = "borno_widget_enabled_metrics"
    private let kMetricOrder = "borno_widget_metric_order"
    private let kLayoutStyle = "borno_widget_layout_style"
    private let kEnabledQuickActions = "borno_widget_quick_actions"
    private let kCompactSpacing = "borno_widget_compact_spacing"
    private let kShowIcons = "borno_widget_show_icons"
    private let kShowLabels = "borno_widget_show_labels"
    private let kShowProgressBars = "borno_widget_show_progress_bars"
    private let kShowTrendCharts = "borno_widget_show_trend_charts"
    private let kUsePercentages = "borno_widget_use_percentages"
    private let kDecimalPlaces = "borno_widget_decimal_places"
    private let kMaxVisibleRows = "borno_widget_max_visible_rows"
    private let kSelectedVolumePath = "borno_widget_selected_volume_path"
    private let kWidgetRefreshInterval = "borno_widget_refresh_interval"

    // MARK: - Published Properties
    @Published public var enabledMetrics: Set<WidgetMetricId> {
        didSet { saveEnabledMetrics() }
    }

    @Published public var metricOrder: [WidgetMetricId] {
        didSet { saveMetricOrder() }
    }

    @Published public var layoutStyle: WidgetLayoutStyle {
        didSet { UserDefaults.standard.set(layoutStyle.rawValue, forKey: kLayoutStyle) }
    }

    @Published public var enabledQuickActions: [WidgetQuickActionId] {
        didSet { saveQuickActions() }
    }

    @Published public var compactSpacing: Bool {
        didSet { UserDefaults.standard.set(compactSpacing, forKey: kCompactSpacing) }
    }

    @Published public var showIcons: Bool {
        didSet { UserDefaults.standard.set(showIcons, forKey: kShowIcons) }
    }

    @Published public var showLabels: Bool {
        didSet { UserDefaults.standard.set(showLabels, forKey: kShowLabels) }
    }

    @Published public var showProgressBars: Bool {
        didSet { UserDefaults.standard.set(showProgressBars, forKey: kShowProgressBars) }
    }

    @Published public var showTrendCharts: Bool {
        didSet { UserDefaults.standard.set(showTrendCharts, forKey: kShowTrendCharts) }
    }

    @Published public var usePercentages: Bool {
        didSet { UserDefaults.standard.set(usePercentages, forKey: kUsePercentages) }
    }

    @Published public var decimalPlaces: Int {
        didSet { UserDefaults.standard.set(decimalPlaces, forKey: kDecimalPlaces) }
    }

    @Published public var maxVisibleRows: Int {
        didSet { UserDefaults.standard.set(maxVisibleRows, forKey: kMaxVisibleRows) }
    }

    @Published public var selectedVolumePath: String {
        didSet { UserDefaults.standard.set(selectedVolumePath, forKey: kSelectedVolumePath) }
    }

    @Published public var widgetRefreshInterval: Double {
        didSet { UserDefaults.standard.set(widgetRefreshInterval, forKey: kWidgetRefreshInterval) }
    }

    // Default configuration constants
    public static let defaultMetrics: [WidgetMetricId] = [
        .cpuTotalUsage,
        .memoryUsed,
        .batteryPercentage,
        .storageFree,
        .networkDownload,
        .thermalPressure,
        .systemUptime
    ]

    public static let defaultQuickActions: [WidgetQuickActionId] = [
        .openDashboard,
        .openBattery,
        .openStorage,
        .openSettings,
        .quit
    ]

    // MARK: - Initialization
    private init() {
        let defaults = UserDefaults.standard

        // 1. Enabled Metrics
        if let data = defaults.data(forKey: kEnabledMetrics),
           let rawArray = try? JSONDecoder().decode([String].self, from: data) {
            let loaded = rawArray.compactMap { WidgetMetricId(rawValue: $0) }
            self.enabledMetrics = Set(loaded.isEmpty ? Self.defaultMetrics : loaded)
        } else {
            self.enabledMetrics = Set(Self.defaultMetrics)
        }

        // 2. Metric Order
        if let data = defaults.data(forKey: kMetricOrder),
           let rawArray = try? JSONDecoder().decode([String].self, from: data) {
            var loaded = rawArray.compactMap { WidgetMetricId(rawValue: $0) }
            // Append newly introduced metrics to maintain completeness
            for m in WidgetMetricId.allCases where !loaded.contains(m) {
                loaded.append(m)
            }
            self.metricOrder = loaded
        } else {
            self.metricOrder = WidgetMetricId.allCases
        }

        // 3. Layout Style
        if let rawStyle = defaults.string(forKey: kLayoutStyle),
           let style = WidgetLayoutStyle(rawValue: rawStyle) {
            self.layoutStyle = style
        } else {
            self.layoutStyle = .balanced
        }

        // 4. Quick Actions
        if let data = defaults.data(forKey: kEnabledQuickActions),
           let rawArray = try? JSONDecoder().decode([String].self, from: data) {
            let loaded = rawArray.compactMap { WidgetQuickActionId(rawValue: $0) }
            self.enabledQuickActions = loaded.isEmpty ? Self.defaultQuickActions : loaded
        } else {
            self.enabledQuickActions = Self.defaultQuickActions
        }

        // 5. Layout Toggles
        self.compactSpacing = defaults.object(forKey: kCompactSpacing) as? Bool ?? false
        self.showIcons = defaults.object(forKey: kShowIcons) as? Bool ?? true
        self.showLabels = defaults.object(forKey: kShowLabels) as? Bool ?? true
        self.showProgressBars = defaults.object(forKey: kShowProgressBars) as? Bool ?? true
        self.showTrendCharts = defaults.object(forKey: kShowTrendCharts) as? Bool ?? true
        self.usePercentages = defaults.object(forKey: kUsePercentages) as? Bool ?? true
        self.decimalPlaces = defaults.object(forKey: kDecimalPlaces) as? Int ?? 1
        self.maxVisibleRows = defaults.object(forKey: kMaxVisibleRows) as? Int ?? 10
        self.selectedVolumePath = defaults.string(forKey: kSelectedVolumePath) ?? "/"
        self.widgetRefreshInterval = defaults.object(forKey: kWidgetRefreshInterval) as? Double ?? 1.0
    }

    // MARK: - Mutators
    public func isMetricEnabled(_ id: WidgetMetricId) -> Bool {
        enabledMetrics.contains(id)
    }

    public func setMetricEnabled(_ id: WidgetMetricId, enabled: Bool) {
        if enabled {
            enabledMetrics.insert(id)
        } else {
            enabledMetrics.remove(id)
        }
    }

    public func toggleMetric(_ id: WidgetMetricId) {
        if enabledMetrics.contains(id) {
            enabledMetrics.remove(id)
        } else {
            enabledMetrics.insert(id)
        }
    }

    public func moveMetric(fromIndex: Int, toIndex: Int) {
        guard fromIndex >= 0 && fromIndex < metricOrder.count,
              toIndex >= 0 && toIndex < metricOrder.count,
              fromIndex != toIndex else { return }
        let item = metricOrder.remove(at: fromIndex)
        metricOrder.insert(item, at: toIndex)
    }

    public func resetToDefaults() {
        self.enabledMetrics = Set(Self.defaultMetrics)
        self.metricOrder = WidgetMetricId.allCases
        self.layoutStyle = .balanced
        self.enabledQuickActions = Self.defaultQuickActions
        self.compactSpacing = false
        self.showIcons = true
        self.showLabels = true
        self.showProgressBars = true
        self.showTrendCharts = true
        self.usePercentages = true
        self.decimalPlaces = 1
        self.maxVisibleRows = 10
        self.selectedVolumePath = "/"
        self.widgetRefreshInterval = 1.0
    }

    // MARK: - Ordered Active Metrics
    public var activeOrderedMetrics: [WidgetMetricId] {
        metricOrder.filter { enabledMetrics.contains($0) }
    }

    // MARK: - Value Extractor Engine
    public func extract(metric: WidgetMetricId, from snapshot: SystemMetricsSnapshot) -> WidgetExtractedMetric {
        switch metric {
        // CPU
        case .cpuTotalUsage:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: String(format: "%.\(decimalPlaces)f%%", snapshot.cpu.totalUsage),
                secondaryValue: "\(snapshot.cpu.logicalCoreCount) Cores",
                progress: snapshot.cpu.totalUsage / 100.0,
                sparkline: snapshot.cpu.historicalUsage,
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .cpuUserUsage:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: String(format: "%.\(decimalPlaces)f%%", snapshot.cpu.userUsage),
                progress: snapshot.cpu.userUsage / 100.0,
                dashboardSection: metric.dashboardSection
            )

        case .cpuSystemUsage:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: String(format: "%.\(decimalPlaces)f%%", snapshot.cpu.systemUsage),
                progress: snapshot.cpu.systemUsage / 100.0,
                dashboardSection: metric.dashboardSection
            )

        case .cpuIdleUsage:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: String(format: "%.\(decimalPlaces)f%%", snapshot.cpu.idleUsage),
                progress: snapshot.cpu.idleUsage / 100.0,
                dashboardSection: metric.dashboardSection
            )

        case .cpuCoreCount:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: "\(snapshot.cpu.physicalCoreCount)P / \(snapshot.cpu.logicalCoreCount)L",
                secondaryValue: snapshot.cpu.architecture,
                dashboardSection: metric.dashboardSection
            )

        case .cpuFrequency:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: "Dynamic",
                secondaryValue: "Managed by Apple Silicon power governor",
                isAvailable: false,
                availabilityNote: "Direct CPU clock frequency is restricted by macOS kernel architecture on Apple Silicon.",
                dashboardSection: metric.dashboardSection
            )

        case .cpuLoadTrend:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: snapshot.cpu.totalUsage > 60 ? "Rising" : "Stable",
                sparkline: snapshot.cpu.historicalUsage,
                dashboardSection: metric.dashboardSection
            )

        // Memory
        case .memoryUsed:
            let usedStr = Formatters.bytes(snapshot.memory.usedBytes)
            let totalStr = Formatters.bytes(snapshot.memory.totalBytes)
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: usedStr,
                secondaryValue: "of \(totalStr)",
                progress: snapshot.memory.usagePercentage / 100.0,
                sparkline: snapshot.memory.historicalUsage,
                dashboardSection: metric.dashboardSection
            )

        case .memoryAvailable:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: Formatters.bytes(snapshot.memory.availableBytes),
                progress: Double(snapshot.memory.availableBytes) / Double(max(snapshot.memory.totalBytes, 1)),
                dashboardSection: metric.dashboardSection
            )

        case .memoryTotal:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: Formatters.bytes(snapshot.memory.totalBytes),
                secondaryValue: "Unified Memory",
                dashboardSection: metric.dashboardSection
            )

        case .memoryPressure:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: snapshot.memory.pressureLevel.rawValue,
                progress: snapshot.memory.pressurePercentage / 100.0,
                dashboardSection: metric.dashboardSection
            )

        case .memorySwap:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: Formatters.bytes(snapshot.memory.swapUsedBytes),
                secondaryValue: "Max: \(Formatters.bytes(snapshot.memory.swapTotalBytes))",
                dashboardSection: metric.dashboardSection
            )

        case .memoryUsagePercent:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: String(format: "%.\(decimalPlaces)f%%", snapshot.memory.usagePercentage),
                progress: snapshot.memory.usagePercentage / 100.0,
                sparkline: snapshot.memory.historicalUsage,
                dashboardSection: metric.dashboardSection
            )

        // GPU & Neural Engine
        case .gpuUtilization:
            if let util = snapshot.gpu.deviceUtilization {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: String(format: "%.\(decimalPlaces)f%%", util),
                    progress: util / 100.0,
                    sparkline: snapshot.gpu.historicalUsage,
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "Unavailable",
                    isAvailable: false,
                    availabilityNote: "IOAccelerator does not expose hardware GPU load telemetry on this architecture.",
                    dashboardSection: metric.dashboardSection
                )
            }

        case .gpuDeviceInfo:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: snapshot.gpu.deviceName,
                secondaryValue: snapshot.gpu.hasUnifiedMemory ? "Unified Architecture" : "Discrete VRAM",
                dashboardSection: metric.dashboardSection
            )

        case .gpuMemory:
            if let inUse = snapshot.gpu.inUseMemoryBytes {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: Formatters.bytes(inUse),
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "Shared RAM",
                    isAvailable: true,
                    availabilityNote: "Shared dynamically from macOS unified system memory.",
                    dashboardSection: metric.dashboardSection
                )
            }

        case .neuralEngineAvailability:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: snapshot.gpu.neuralEngineAvailable ? "Active" : "Unavailable",
                secondaryValue: snapshot.gpu.neuralEngineDescription,
                isAvailable: snapshot.gpu.neuralEngineAvailable,
                dashboardSection: metric.dashboardSection
            )

        // Temperature & Fans
        case .cpuTemperature:
            return temperatureMetric(metric, component: .cpu, snapshot: snapshot)

        case .gpuTemperature:
            return temperatureMetric(metric, component: .gpu, snapshot: snapshot)

        case .batteryTemperature:
            return temperatureMetric(metric, component: .battery, snapshot: snapshot)

        case .ssdTemperature:
            return temperatureMetric(metric, component: .storage, snapshot: snapshot)

        case .fanSpeed:
            if let fastest = snapshot.sensors.fanSpeeds.max(by: { $0.speedRPM < $1.speedRPM }) {
                let fanCount = snapshot.sensors.fanSpeeds.count
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: Formatters.rpm(fastest.speedRPM),
                    secondaryValue: fanCount > 1 ? "Fastest of \(fanCount) fans" : fastest.name,
                    progress: fastest.maxRPM.map { min(1.0, fastest.speedRPM / $0) },
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "Unavailable",
                    isAvailable: false,
                    availabilityNote: snapshot.sensors.fansState.displayText,
                    dashboardSection: metric.dashboardSection
                )
            }

        case .thermalPressure:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: snapshot.sensors.thermalState.shortLabel,
                secondaryValue: snapshot.sensors.isThrottling ? "Performance reduced" : "No throttling",
                progress: thermalProgress(for: snapshot.sensors.thermalState),
                isAvailable: true,
                availabilityNote: "macOS thermal pressure level — not a temperature.",
                dashboardSection: metric.dashboardSection
            )

        // Battery & Power
        case .batteryPercentage:
            if snapshot.battery.hasBattery {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "\(snapshot.battery.percentage)%",
                    secondaryValue: snapshot.battery.isCharging ? "Charging" : (snapshot.battery.isPluggedIn ? "Power Adapter" : "Discharging"),
                    progress: Double(snapshot.battery.percentage) / 100.0,
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "Unavailable (AC)",
                    secondaryValue: "Desktop Mac (No battery installed)",
                    isAvailable: false,
                    availabilityNote: "This Mac runs on continuous AC power with no internal battery installed.",
                    dashboardSection: metric.dashboardSection
                )
            }

        case .batteryTimeRemaining:
            if snapshot.battery.hasBattery {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: snapshot.battery.formattedTimeRemaining,
                    secondaryValue: snapshot.battery.estimateConfidence.rawValue,
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "Continuous (AC)",
                    secondaryValue: "Desktop Mac",
                    isAvailable: false,
                    availabilityNote: "Desktop Mac is connected to continuous AC power.",
                    dashboardSection: metric.dashboardSection
                )
            }

        case .batteryTimeUntilFull:
            if snapshot.battery.hasBattery && snapshot.battery.isCharging {
                let mins = snapshot.battery.timeToFullMinutes ?? snapshot.battery.estimatedMinutes
                let formatted = mins != nil ? "\(mins! / 60)h \(mins! % 60)m until full" : "Calculating..."
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: formatted,
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else if !snapshot.battery.hasBattery {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "N/A (Desktop)",
                    isAvailable: false,
                    availabilityNote: "Desktop Mac has no battery to charge.",
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: snapshot.battery.isFullyCharged ? "Fully Charged" : "Not Charging",
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            }

        case .batteryState:
            if snapshot.battery.hasBattery {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: snapshot.battery.stateOfCharge.rawValue,
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "AC Power",
                    secondaryValue: "Desktop Mac",
                    isAvailable: false,
                    availabilityNote: "Desktop Mac runs on continuous AC line voltage.",
                    dashboardSection: metric.dashboardSection
                )
            }

        case .batteryHealth:
            if snapshot.battery.hasBattery, let hp = snapshot.battery.healthPercentage {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "\(hp)%",
                    secondaryValue: snapshot.battery.condition,
                    progress: Double(hp) / 100.0,
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: snapshot.battery.hasBattery ? "Normal" : "N/A (Desktop)",
                    isAvailable: snapshot.battery.hasBattery,
                    availabilityNote: snapshot.battery.hasBattery ? nil : "No battery installed on desktop Mac architecture.",
                    dashboardSection: metric.dashboardSection
                )
            }

        case .batteryCycleCount:
            if let cycles = snapshot.battery.cycleCount {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "\(cycles) Cycles",
                    secondaryValue: "of 1000 Max",
                    progress: min(1.0, Double(cycles) / 1000.0),
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "N/A",
                    isAvailable: false,
                    dashboardSection: metric.dashboardSection
                )
            }

        case .batteryChargingWatts:
            if let cw = snapshot.battery.chargingWatts, cw > 0.05 {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: String(format: "+%.1f W", cw),
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "0.0 W",
                    secondaryValue: "Not Charging",
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            }

        case .batteryDischargingWatts:
            if let dw = snapshot.battery.dischargingWatts, dw > 0.05 {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: String(format: "-%.1f W", dw),
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "0.0 W",
                    secondaryValue: snapshot.battery.isPluggedIn ? "AC Connected" : "Idle",
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            }

        case .systemPowerWatts:
            if let sw = snapshot.battery.systemPowerWatts {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: String(format: "%.1f W", sw),
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "Unavailable",
                    isAvailable: false,
                    availabilityNote: "Power distribution telemetry not exposed by hardware on this machine.",
                    dashboardSection: metric.dashboardSection
                )
            }

        case .powerAdapterInfo:
            if let name = snapshot.battery.adapterName, let watts = snapshot.battery.adapterRatedWatts {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: "\(watts)W Adapter",
                    secondaryValue: name,
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            } else {
                return WidgetExtractedMetric(
                    id: metric,
                    title: metric.title,
                    icon: metric.icon,
                    category: metric.category,
                    formattedValue: snapshot.battery.isPluggedIn ? "Connected" : "Disconnected",
                    isAvailable: true,
                    dashboardSection: metric.dashboardSection
                )
            }

        // Storage
        case .storageFree:
            let volume = resolveVolume(from: snapshot)
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: Formatters.bytes(volume.freeBytes),
                secondaryValue: volume.name,
                progress: Double(volume.freeBytes) / Double(max(volume.totalBytes, 1)),
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .storageUsed:
            let volume = resolveVolume(from: snapshot)
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: Formatters.bytes(volume.usedBytes),
                secondaryValue: volume.name,
                progress: volume.usedPercentage / 100.0,
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .storageTotal:
            let volume = resolveVolume(from: snapshot)
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: Formatters.bytes(volume.totalBytes),
                secondaryValue: volume.fileSystem,
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .storageUsagePercent:
            let volume = resolveVolume(from: snapshot)
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: String(format: "%.\(decimalPlaces)f%%", volume.usedPercentage),
                progress: volume.usedPercentage / 100.0,
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .storageVolume:
            let volume = resolveVolume(from: snapshot)
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: volume.name,
                secondaryValue: volume.mountPoint,
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .storageWarning:
            let volume = resolveVolume(from: snapshot)
            let isLow = volume.usedPercentage > 90.0
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: isLow ? "Low Space Warning" : "Healthy Space",
                secondaryValue: "\(Formatters.bytes(volume.freeBytes)) remaining",
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        // Network
        case .networkDownload:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: Formatters.speed(snapshot.network.downloadSpeedBytesPerSec),
                sparkline: snapshot.network.historicalDownload,
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .networkUpload:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: Formatters.speed(snapshot.network.uploadSpeedBytesPerSec),
                sparkline: snapshot.network.historicalUpload,
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .networkInterface:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: snapshot.network.primaryInterface,
                secondaryValue: snapshot.network.activeInterfaces.first(where: { $0.name == snapshot.network.primaryInterface })?.displayName,
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .networkStatus:
            let isConnected = !snapshot.network.activeInterfaces.isEmpty
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: isConnected ? "Connected" : "Disconnected",
                secondaryValue: "\(snapshot.network.activeInterfaces.count) Active IFs",
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .networkSessionTransferred:
            let total = snapshot.network.totalReceivedBytes + snapshot.network.totalSentBytes
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: Formatters.bytes(total),
                secondaryValue: "↓\(Formatters.bytes(snapshot.network.totalReceivedBytes)) ↑\(Formatters.bytes(snapshot.network.totalSentBytes))",
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .wifiSignal:
            let wifiIf = snapshot.network.activeInterfaces.first(where: { $0.isWiFi })
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: wifiIf != nil ? "Active" : "Ethernet / Other",
                secondaryValue: wifiIf?.name ?? "No Wi-Fi",
                isAvailable: wifiIf != nil,
                availabilityNote: wifiIf == nil ? "Device is currently using Ethernet or cellular interface." : nil,
                dashboardSection: metric.dashboardSection
            )

        case .publicIP:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: "Manual Lookup",
                secondaryValue: "Click to query public IP",
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        // System
        case .systemUptime:
            let uptimeSecs = ProcessInfo.processInfo.systemUptime
            let hours = Int(uptimeSecs) / 3600
            let days = hours / 24
            let remHours = hours % 24
            let formatted = days > 0 ? "\(days)d \(remHours)h" : "\(hours)h \(Int(uptimeSecs) % 3600 / 60)m"
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: formatted,
                secondaryValue: "System Uptime",
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .systemActiveApp:
            let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Finder"
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: frontApp,
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .systemProcessCount:
            let procCount = ProcessInfo.processInfo.activeProcessorCount * 12 // Estimate representative thread pool
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: "\(procCount) Tasks",
                dashboardSection: metric.dashboardSection
            )

        case .systemHealthSummary:
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: "\(snapshot.healthScore)/100",
                secondaryValue: snapshot.healthStatusText,
                progress: Double(snapshot.healthScore) / 100.0,
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )

        case .monitoringStatus:
            let isRunning = SystemMonitor.shared.isMonitoring && !SystemMonitor.shared.isPaused
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: isRunning ? "Live Polling" : "Paused",
                secondaryValue: "\(String(format: "%.1fs", AppSettings.shared.refreshIntervalSeconds)) interval",
                isAvailable: true,
                dashboardSection: metric.dashboardSection
            )
        }
    }

    private func resolveVolume(from snapshot: SystemMetricsSnapshot) -> StorageVolume {
        if let match = snapshot.storage.volumes.first(where: { $0.mountPoint == selectedVolumePath }) {
            return match
        }
        if let primary = snapshot.storage.primaryVolume {
            return primary
        }
        if let first = snapshot.storage.volumes.first {
            return first
        }
        return StorageVolume(
            name: "Macintosh HD",
            mountPoint: "/",
            totalBytes: snapshot.storage.totalCapacityBytes,
            usedBytes: snapshot.storage.usedCapacityBytes,
            freeBytes: snapshot.storage.availableCapacityBytes
        )
    }

    private func temperatureMetric(
        _ metric: WidgetMetricId,
        component: ThermalComponent,
        snapshot: SystemMetricsSnapshot,
        now: Date = Date()
    ) -> WidgetExtractedMetric {
        let unit = AppSettings.shared.temperatureUnit
        let staleAfter = SensorFreshness.staleAfter(refreshInterval: AppSettings.shared.refreshIntervalSeconds)

        guard let value = snapshot.sensors.temperature(for: component) else {
            return WidgetExtractedMetric(
                id: metric,
                title: metric.title,
                icon: metric.icon,
                category: metric.category,
                formattedValue: Formatters.unavailableTemperature,
                isAvailable: false,
                availabilityNote: snapshot.sensors.state(for: component).displayText,
                dashboardSection: metric.dashboardSection
            )
        }

        let isStale = value.isStale(at: now, maxAge: staleAfter)
        let sparkline = snapshot.sensors.history[component]?
            .compactMap(\.celsius)
            .map { unit.convert(fromCelsius: $0) }
        let detail = value.sensorCount > 1
            ? "Peak \(Formatters.temperature(value.maximumCelsius, unit: unit)) · \(value.sensorCount) sensors"
            : value.source.displayName
        return WidgetExtractedMetric(
            id: metric,
            title: metric.title,
            icon: metric.icon,
            category: metric.category,
            formattedValue: Formatters.temperature(value.celsius, unit: unit),
            secondaryValue: isStale ? "Stale · updated \(Formatters.readingAge(since: value.timestamp, now: now))" : detail,
            sparkline: sparkline,
            isAvailable: !isStale,
            availabilityNote: isStale ? "This reading has stopped updating." : nil,
            dashboardSection: metric.dashboardSection
        )
    }

    private func thermalProgress(for state: ProcessInfo.ThermalState) -> Double {
        switch state {
        case .nominal: return 0.25
        case .fair: return 0.50
        case .serious: return 0.75
        case .critical: return 1.00
        @unknown default: return 0.25
        }
    }

    // MARK: - Persistence Serialization
    private func saveEnabledMetrics() {
        let rawArray = Array(enabledMetrics).map { $0.rawValue }
        if let data = try? JSONEncoder().encode(rawArray) {
            UserDefaults.standard.set(data, forKey: kEnabledMetrics)
        }
    }

    private func saveMetricOrder() {
        let rawArray = metricOrder.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(rawArray) {
            UserDefaults.standard.set(data, forKey: kMetricOrder)
        }
    }

    private func saveQuickActions() {
        let rawArray = enabledQuickActions.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(rawArray) {
            UserDefaults.standard.set(data, forKey: kEnabledQuickActions)
        }
    }
}
