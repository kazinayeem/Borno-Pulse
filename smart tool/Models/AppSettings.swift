//
//  AppSettings.swift
//  Borno Pulse
//

import Combine
import SwiftUI

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
        let raw = try container.decode(String.self)
        switch raw.lowercased() {
        case "light": self = .light
        case "dark", "dark graphite": self = .dark
        case "system", "system default": self = .system
        default: self = .light
        }
    }
}

public enum TemperatureUnit: String, CaseIterable, Identifiable, Codable {
    case celsius = "Celsius (°C)"
    case fahrenheit = "Fahrenheit (°F)"
    
    public var id: String { rawValue }
    public var isFahrenheit: Bool { self == .fahrenheit }
}

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    @AppStorage("launchAtLogin") public var launchAtLogin: Bool = false
    @AppStorage("menuBarDisplay") public var menuBarDisplay: MenuBarMetricDisplay = .cpuPercentage
    @AppStorage("refreshIntervalSeconds") public var refreshIntervalSeconds: Double = 1.0
    @AppStorage("temperatureUnit") public var temperatureUnit: TemperatureUnit = .celsius
    @AppStorage("appearanceMode") public var appearanceMode: AppAppearanceMode = .light
    @AppStorage("historyDurationPoints") public var historyDurationPoints: Int = 60
    
    // Typography Customization
    @AppStorage("appFontFamily") public var appFontFamily: AppFontFamily = .sfPro
    @AppStorage("fontScale") public var fontScale: Double = 1.0
    @AppStorage("baseFontWeight") public var baseFontWeight: AppFontWeight = .regular
    @AppStorage("monospacedFontFamily") public var monospacedFontFamily: AppMonospacedFontFamily = .systemMonospaced
    
    // Menu Bar Icon Customization
    @AppStorage("menuBarIconSymbol") public var menuBarIconSymbol: MenuBarIconSymbol = .gauge
    
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
        if UserDefaults.standard.object(forKey: "appearanceMode") == nil {
            UserDefaults.standard.set(AppAppearanceMode.light.rawValue, forKey: "appearanceMode")
        }
    }
}
