//
//  AppSettings.swift
//  Borno Pulse
//

import Combine
import SwiftUI

// MARK: - Legacy single-mode enum (kept for migration compatibility)
public enum MenuBarMetricDisplay: String, CaseIterable, Identifiable, Codable {
    case iconOnly = "Icon Only"
    case cpuPercentage = "CPU %"
    case memoryPercentage = "Memory %"
    case networkSpeed = "Network Speed"
    case cpuAndMemory = "CPU + Memory"
    case cpuAndNetwork = "CPU + Network"
    case batteryPercentage = "Battery %"
    case batteryTimeRemaining = "Battery Time Remaining"
    case batteryWatts = "Battery Watts (W)"
    case batteryStatus = "Battery Status Icon"
    case batteryPercentAndTime = "Battery % + Time"

    public var id: String { rawValue }
}

// MARK: - Multi-Metric Menu Bar

/// Individual metric that can appear in the macOS menu bar status item.
public enum MenuBarStatusMetric: String, CaseIterable, Identifiable, Codable, Sendable {
    case iconOnly         = "icon_only"
    case cpuUsage         = "cpu_usage"
    case memoryUsage      = "memory_usage"
    case gpuUsage         = "gpu_usage"
    case networkDownload  = "network_download"
    case networkUpload    = "network_upload"
    case networkCombined  = "network_combined"
    case batteryPercent   = "battery_percent"
    case batteryTime      = "battery_time"
    case batteryWatts     = "battery_watts"
    case batteryStatus    = "battery_status"
    case cpuTemperature   = "cpu_temperature"
    case gpuTemperature   = "gpu_temperature"
    case batteryTemperature = "battery_temperature"
    case thermalState     = "thermal_state"
    case fanSpeed         = "fan_speed"

    public var id: String { rawValue }

    /// Short label shown in the menu bar (≤ 4 chars).
    public var shortLabel: String {
        switch self {
        case .iconOnly:        return ""
        case .cpuUsage:        return "CPU"
        case .memoryUsage:     return "MEM"
        case .gpuUsage:        return "GPU"
        case .networkDownload: return "↓"
        case .networkUpload:   return "↑"
        case .networkCombined: return "NET"
        case .batteryPercent:  return "BAT"
        case .batteryTime:     return "BAT"
        case .batteryWatts:    return "PWR"
        case .batteryStatus:   return ""
        case .cpuTemperature:  return "CPU"
        case .gpuTemperature:  return "GPU"
        case .batteryTemperature: return "BAT"
        case .thermalState:    return "THM"
        case .fanSpeed:        return "FAN"
        }
    }

    /// Human-readable display name for Settings UI.
    public var displayName: String {
        switch self {
        case .iconOnly:        return "Icon Only"
        case .cpuUsage:        return "CPU Usage (%)"
        case .memoryUsage:     return "Memory Usage (%)"
        case .gpuUsage:        return "GPU Usage (%, if available)"
        case .networkDownload: return "Network Download Speed"
        case .networkUpload:   return "Network Upload Speed"
        case .networkCombined: return "Combined Network Speed"
        case .batteryPercent:  return "Battery Percentage"
        case .batteryTime:     return "Battery Time Remaining"
        case .batteryWatts:    return "Battery Power (W)"
        case .batteryStatus:   return "Battery Status Icon"
        case .cpuTemperature:  return "CPU Temperature"
        case .gpuTemperature:  return "GPU Temperature"
        case .batteryTemperature: return "Battery Temperature"
        case .thermalState:    return "System Thermal State"
        case .fanSpeed:        return "Fan Speed (RPM)"
        }
    }

    /// SF Symbol for the Settings list.
    public var icon: String {
        switch self {
        case .iconOnly:        return "gauge.with.dots.needle.bottom.100percent"
        case .cpuUsage:        return "cpu"
        case .memoryUsage:     return "memorychip"
        case .gpuUsage:        return "circle.grid.cross.fill"
        case .networkDownload: return "arrow.down.circle.fill"
        case .networkUpload:   return "arrow.up.circle.fill"
        case .networkCombined: return "arrow.up.arrow.down"
        case .batteryPercent:  return "battery.100.bolt"
        case .batteryTime:     return "clock.fill"
        case .batteryWatts:    return "bolt.fill"
        case .batteryStatus:   return "battery.75"
        case .cpuTemperature:  return "thermometer.sun.fill"
        case .gpuTemperature:  return "thermometer.high"
        case .batteryTemperature: return "thermometer.medium"
        case .thermalState:    return "flame.fill"
        case .fanSpeed:        return "fanblades.fill"
        }
    }

    /// Metrics that are mutually exclusive with each other (user shouldn't combine them freely).
    /// Selecting one from the same group replaces the others.
    public var exclusionGroup: String? {
        switch self {
        case .batteryPercent, .batteryTime, .batteryWatts, .batteryStatus: return "battery"
        case .networkDownload, .networkUpload, .networkCombined: return "network"
        default: return nil
        }
    }

    /// True when the metric requires battery hardware.
    public var requiresBattery: Bool {
        switch self {
        case .batteryPercent, .batteryTime, .batteryWatts, .batteryStatus, .batteryTemperature: return true
        default: return false
        }
    }

    /// Whether the current Mac can supply this metric, with the reason when it can't.
    public func availability(in snapshot: SystemMetricsSnapshot) -> AvailabilityState {
        if requiresBattery && !snapshot.battery.hasBattery {
            return .unavailable(reason: "This Mac has no internal battery.")
        }
        switch self {
        case .gpuUsage:
            return snapshot.gpu.deviceUtilization != nil ? .available : .unavailable(reason: "GPU utilization is not exposed on this Mac.")
        case .cpuTemperature: return snapshot.sensors.state(for: .cpu)
        case .gpuTemperature: return snapshot.sensors.state(for: .gpu)
        case .batteryTemperature: return snapshot.sensors.state(for: .battery)
        case .fanSpeed: return snapshot.sensors.fansState
        default: return .available
        }
    }

    /// Render a compact text string for the live menu bar status item.
    /// Returns nil when the metric is unavailable or should be suppressed.
    public func menuBarText(
        from snapshot: SystemMetricsSnapshot,
        temperatureUnit: TemperatureUnit = .celsius,
        now: Date = Date(),
        staleAfter: TimeInterval = SensorFreshness.defaultStaleAfter
    ) -> String? {
        func freshCelsius(_ component: ThermalComponent) -> Double? {
            guard let value = snapshot.sensors.temperature(for: component),
                  !value.isStale(at: now, maxAge: staleAfter) else { return nil }
            return value.celsius
        }

        switch self {
        case .cpuTemperature:
            return "CPU " + Formatters.compactTemperature(freshCelsius(.cpu), unit: temperatureUnit)

        case .gpuTemperature:
            return "GPU " + Formatters.compactTemperature(freshCelsius(.gpu), unit: temperatureUnit)

        case .batteryTemperature:
            guard snapshot.battery.hasBattery else { return nil }
            return "BAT " + Formatters.compactTemperature(freshCelsius(.battery), unit: temperatureUnit)

        case .thermalState:
            return "THM " + snapshot.sensors.thermalState.shortLabel

        case .fanSpeed:
            guard let fastest = snapshot.sensors.fanSpeeds.max(by: { $0.speedRPM < $1.speedRPM }) else { return "FAN --" }
            return String(format: "FAN %.0frpm", fastest.speedRPM)

        case .iconOnly:
            return nil  // icon-only — caller sets just an image

        case .cpuUsage:
            return String(format: "CPU %.0f%%", snapshot.cpu.totalUsage)

        case .memoryUsage:
            return String(format: "MEM %.0f%%", snapshot.memory.usagePercentage)

        case .gpuUsage:
            if let util = snapshot.gpu.deviceUtilization {
                return String(format: "GPU %.0f%%", util)
            }
            return nil  // omit when unavailable

        case .networkDownload:
            return "↓ " + Formatters.speed(snapshot.network.downloadSpeedBytesPerSec)

        case .networkUpload:
            return "↑ " + Formatters.speed(snapshot.network.uploadSpeedBytesPerSec)

        case .networkCombined:
            let dl = Formatters.speed(snapshot.network.downloadSpeedBytesPerSec)
            let ul = Formatters.speed(snapshot.network.uploadSpeedBytesPerSec)
            return "↓\(dl) ↑\(ul)"

        case .batteryPercent:
            if snapshot.battery.hasBattery {
                let charging = snapshot.battery.isCharging ? "⚡" : ""
                return "BAT \(snapshot.battery.percentage)%\(charging)"
            }
            return "AC"

        case .batteryTime:
            if snapshot.battery.hasBattery && !snapshot.battery.isCharging {
                let t = snapshot.battery.formattedTimeRemaining
                return t.isEmpty ? nil : "~\(t)"
            }
            return nil

        case .batteryWatts:
            if snapshot.battery.hasBattery {
                if let w = snapshot.battery.chargingWatts, w > 0.05 {
                    return String(format: "+%.1fW", w)
                } else if let w = snapshot.battery.dischargingWatts, w > 0.05 {
                    return String(format: "-%.1fW", w)
                } else if let w = snapshot.battery.wattage {
                    return String(format: "%.1fW", abs(w))
                }
            }
            return nil

        case .batteryStatus:
            return nil  // icon-only; caller sets image based on charge state
        }
    }

    /// The SF Symbol to show alongside this metric in the menu bar, or nil to keep the current icon.
    public func menuBarSymbol(from snapshot: SystemMetricsSnapshot) -> String? {
        switch self {
        case .iconOnly:
            return nil  // caller uses the user-chosen icon
        case .batteryStatus:
            if snapshot.battery.hasBattery {
                return snapshot.battery.isCharging ? "bolt.batteryblock.fill" : "battery.75"
            }
            return "powerplug"
        default:
            return nil
        }
    }

    // MARK: - Migration helper
    /// Convert the old single-mode enum into an initial multi-metric selection.
    public static func migrate(from legacy: MenuBarMetricDisplay) -> [MenuBarStatusMetric] {
        switch legacy {
        case .iconOnly:           return [.iconOnly]
        case .cpuPercentage:      return [.cpuUsage]
        case .memoryPercentage:   return [.memoryUsage]
        case .networkSpeed:       return [.networkDownload]
        case .cpuAndMemory:       return [.cpuUsage, .memoryUsage]
        case .cpuAndNetwork:      return [.cpuUsage, .networkDownload]
        case .batteryPercentage:  return [.batteryPercent]
        case .batteryTimeRemaining: return [.batteryTime]
        case .batteryWatts:       return [.batteryWatts]
        case .batteryStatus:      return [.batteryStatus]
        case .batteryPercentAndTime: return [.batteryPercent, .batteryTime]
        }
    }
}

public enum AppAppearanceMode: String, CaseIterable, Identifiable, Codable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    public var id: String { rawValue }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = .migrating(storedValue: try container.decode(String.self))
    }

    /// Maps a persisted value, including the pre-1.0 "Dark Graphite" / "System Default" raw values,
    /// to a current mode. `@AppStorage` only uses `init(rawValue:)`, so legacy values must be
    /// rewritten before it reads them or the user's choice silently falls back to Light.
    /// A missing value (new install) resolves to Light.
    public static func migrating(storedValue: String?) -> AppAppearanceMode {
        switch storedValue?.lowercased() {
        case "dark", "dark graphite": return .dark
        case "system", "system default": return .system
        default: return .light
        }
    }
}

public enum TemperatureUnit: String, CaseIterable, Identifiable, Codable {
    case celsius = "Celsius (°C)"
    case fahrenheit = "Fahrenheit (°F)"
    
    public var id: String { rawValue }
    public var isFahrenheit: Bool { self == .fahrenheit }

    public var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }

    /// Converts a Celsius reading into this unit.
    public func convert(fromCelsius celsius: Double) -> Double {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return celsius * 9.0 / 5.0 + 32.0
        }
    }

    /// Converts a value expressed in this unit back to Celsius.
    public func toCelsius(_ value: Double) -> Double {
        switch self {
        case .celsius: return value
        case .fahrenheit: return (value - 32.0) * 5.0 / 9.0
        }
    }
}

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    @AppStorage("launchAtLogin") public var launchAtLogin: Bool = false
    /// Legacy single-mode key — kept so migration can read the old value.
    @AppStorage("menuBarDisplay") public var menuBarDisplay: MenuBarMetricDisplay = .cpuPercentage
    @AppStorage("refreshIntervalSeconds") public var refreshIntervalSeconds: Double = 1.0
    @AppStorage("temperatureUnit") public var temperatureUnit: TemperatureUnit = .celsius
    /// Allows reading SMC / IOHID thermal sensors (undocumented interfaces, unavailable when sandboxed).
    @AppStorage("hardwareSensorAccessEnabled") public var hardwareSensorAccessEnabled: Bool = true
    @AppStorage("appearanceMode") public var appearanceMode: AppAppearanceMode = .light
    @AppStorage("historyDurationPoints") public var historyDurationPoints: Int = 60

    // Typography Customization
    @AppStorage("appFontFamily") public var appFontFamily: AppFontFamily = .sfPro
    @AppStorage("fontScale") public var fontScale: Double = 1.0
    @AppStorage("baseFontWeight") public var baseFontWeight: AppFontWeight = .regular
    @AppStorage("monospacedFontFamily") public var monospacedFontFamily: AppMonospacedFontFamily = .systemMonospaced

    // Menu Bar Icon Customization
    @AppStorage("menuBarIconSymbol") public var menuBarIconSymbol: MenuBarIconSymbol = .gauge

    // MARK: - Multi-Metric Menu Bar
    private let kMenuBarStatusMetrics = "borno_menubar_status_metrics_v2"
    private let kMenuBarMaxVisible    = "borno_menubar_max_visible"

    /// Ordered list of metrics shown in the macOS menu bar status item (1 – 4).
    @Published public private(set) var menuBarStatusMetrics: [MenuBarStatusMetric] = [] {
        didSet { saveMenuBarMetrics() }
    }

    /// Maximum number of metrics displayed simultaneously (1 – 4).
    @Published public var menuBarMaxVisible: Int = 4 {
        didSet { UserDefaults.standard.set(menuBarMaxVisible, forKey: kMenuBarMaxVisible) }
    }

    public static let defaultMenuBarMetrics: [MenuBarStatusMetric] = [
        .cpuUsage, .memoryUsage, .networkDownload, .batteryPercent
    ]

    // MARK: - Mutation helpers
    public func setMenuBarMetrics(_ metrics: [MenuBarStatusMetric]) {
        menuBarStatusMetrics = Array(metrics.prefix(4))
    }

    public func moveMenuBarMetric(from: Int, to: Int) {
        guard from >= 0, from < menuBarStatusMetrics.count,
              to   >= 0, to   < menuBarStatusMetrics.count,
              from != to else { return }
        var updated = menuBarStatusMetrics
        let item = updated.remove(at: from)
        updated.insert(item, at: to)
        menuBarStatusMetrics = updated
    }

    public func addMenuBarMetric(_ metric: MenuBarStatusMetric) {
        guard !menuBarStatusMetrics.contains(metric),
              menuBarStatusMetrics.count < 4 else { return }
        menuBarStatusMetrics.append(metric)
    }

    public func removeMenuBarMetric(_ metric: MenuBarStatusMetric) {
        menuBarStatusMetrics.removeAll { $0 == metric }
    }

    public func resetMenuBarMetrics() {
        menuBarStatusMetrics = Self.defaultMenuBarMetrics
    }

    private func saveMenuBarMetrics() {
        let rawValues = menuBarStatusMetrics.map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues) {
            UserDefaults.standard.set(data, forKey: kMenuBarStatusMetrics)
        }
    }
    
    public func resetTypographyToDefaults() {
        appFontFamily = .sfPro
        fontScale = 1.0
        baseFontWeight = .regular
        monospacedFontFamily = .systemMonospaced
        objectWillChange.send()
    }
    
    // Notifications & Alert Thresholds
    @AppStorage("notifyHighCPU") public var notifyHighCPU: Bool = false
    @AppStorage("cpuAlertThreshold") public var cpuAlertThreshold: Double = 90.0
    
    @AppStorage("notifyHighMemory") public var notifyHighMemory: Bool = false
    @AppStorage("memoryAlertThreshold") public var memoryAlertThreshold: Double = 90.0
    
    @AppStorage("notifyLowBattery") public var notifyLowBattery: Bool = true
    @AppStorage("batteryAlertThreshold") public var batteryAlertThreshold: Int = 20
    @AppStorage("notifyFullyCharged") public var notifyFullyCharged: Bool = true
    @AppStorage("notifyPowerDisconnected") public var notifyPowerDisconnected: Bool = true
    @AppStorage("notifyRapidDischarge") public var notifyRapidDischarge: Bool = true
    @AppStorage("rapidDischargeThresholdRatePerHour") public var rapidDischargeThresholdRatePerHour: Double = 30.0
    
    // Excluded paths for cleanup
    @AppStorage("cleanupExclusionsJSON") private var cleanupExclusionsJSON: String = "[]"
    
    public var cleanupExclusions: [String] {
        get {
            guard let data = cleanupExclusionsJSON.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                cleanupExclusionsJSON = str
                objectWillChange.send()
            }
        }
    }
    
    private init() {
        let storedAppearance = UserDefaults.standard.string(forKey: "appearanceMode")
        let normalizedAppearance = AppAppearanceMode.migrating(storedValue: storedAppearance)
        if storedAppearance != normalizedAppearance.rawValue {
            UserDefaults.standard.set(normalizedAppearance.rawValue, forKey: "appearanceMode")
        }

        // Load multi-metric bar preferences
        let defaults = UserDefaults.standard
        let maxVis = defaults.object(forKey: kMenuBarMaxVisible) as? Int ?? 4
        self.menuBarMaxVisible = max(1, min(4, maxVis))

        if let data = defaults.data(forKey: kMenuBarStatusMetrics),
           let rawArray = try? JSONDecoder().decode([String].self, from: data) {
            let loaded = rawArray.compactMap { MenuBarStatusMetric(rawValue: $0) }
            self.menuBarStatusMetrics = loaded.isEmpty ? Self.defaultMenuBarMetrics : Array(loaded.prefix(4))
        } else {
            // First launch or migration from legacy single-mode
            if let legacyRaw = defaults.string(forKey: "menuBarDisplay"),
               let legacy = MenuBarMetricDisplay(rawValue: legacyRaw) {
                self.menuBarStatusMetrics = MenuBarStatusMetric.migrate(from: legacy)
            } else {
                self.menuBarStatusMetrics = Self.defaultMenuBarMetrics
            }
        }
    }
}
