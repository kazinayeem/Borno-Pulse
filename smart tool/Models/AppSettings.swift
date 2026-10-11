//
//  AppSettings.swift
//  Naem Smart Tool
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
    
    public var id: String { rawValue }
}

public enum AppAppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system = "System Default"
    case dark = "Dark Graphite"
    case light = "Light"
    
    public var id: String { rawValue }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
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
    @AppStorage("appearanceMode") public var appearanceMode: AppAppearanceMode = .dark
    @AppStorage("historyDurationPoints") public var historyDurationPoints: Int = 60
    
    // Notifications & Alert Thresholds
    @AppStorage("notifyHighCPU") public var notifyHighCPU: Bool = false
    @AppStorage("cpuAlertThreshold") public var cpuAlertThreshold: Double = 90.0
    
    @AppStorage("notifyHighMemory") public var notifyHighMemory: Bool = false
    @AppStorage("memoryAlertThreshold") public var memoryAlertThreshold: Double = 90.0
    
    @AppStorage("notifyLowBattery") public var notifyLowBattery: Bool = true
    @AppStorage("batteryAlertThreshold") public var batteryAlertThreshold: Int = 20
    
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
    
    private init() {}
}
