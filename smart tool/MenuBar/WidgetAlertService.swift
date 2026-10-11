//
//  WidgetAlertService.swift
//  Borno Pulse
//
//  Threshold evaluation, duplicate alert suppression, and local notifications
//  for real hardware metrics.
//

import AppKit
import Foundation
import UserNotifications

@MainActor
public final class WidgetAlertService: ObservableObject {
    public static let shared = WidgetAlertService()

    // MARK: - Threshold Configuration
    @Published public var enableCPUAlert: Bool {
        didSet { UserDefaults.standard.set(enableCPUAlert, forKey: "borno_alert_cpu_enabled") }
    }
    @Published public var cpuThreshold: Double {
        didSet { UserDefaults.standard.set(cpuThreshold, forKey: "borno_alert_cpu_threshold") }
    }

    @Published public var enableMemoryAlert: Bool {
        didSet { UserDefaults.standard.set(enableMemoryAlert, forKey: "borno_alert_memory_enabled") }
    }
    @Published public var memoryThreshold: Double {
        didSet { UserDefaults.standard.set(memoryThreshold, forKey: "borno_alert_memory_threshold") }
    }

    @Published public var enableDiskAlert: Bool {
        didSet { UserDefaults.standard.set(enableDiskAlert, forKey: "borno_alert_disk_enabled") }
    }
    @Published public var diskThresholdGB: Double {
        didSet { UserDefaults.standard.set(diskThresholdGB, forKey: "borno_alert_disk_threshold_gb") }
    }

    @Published public var enableBatteryAlert: Bool {
        didSet { UserDefaults.standard.set(enableBatteryAlert, forKey: "borno_alert_battery_enabled") }
    }
    @Published public var batteryThresholdPercent: Int {
        didSet { UserDefaults.standard.set(batteryThresholdPercent, forKey: "borno_alert_battery_threshold") }
    }

    @Published public var enableTemperatureAlert: Bool {
        didSet { UserDefaults.standard.set(enableTemperatureAlert, forKey: "borno_alert_temp_enabled") }
    }
    @Published public var temperatureThresholdCelsius: Double {
        didSet { UserDefaults.standard.set(temperatureThresholdCelsius, forKey: "borno_alert_temp_threshold") }
    }

    @Published public var enableNetworkDisconnectAlert: Bool {
        didSet { UserDefaults.standard.set(enableNetworkDisconnectAlert, forKey: "borno_alert_net_disc_enabled") }
    }

    // Cooldown tracking to deduplicate and prevent alert fatigue
    private var lastTriggeredDates: [String: Date] = [:]
    public var cooldownSeconds: TimeInterval = 300.0 // 5 minutes

    private init() {
        let defaults = UserDefaults.standard
        self.enableCPUAlert = defaults.object(forKey: "borno_alert_cpu_enabled") as? Bool ?? false
        self.cpuThreshold = defaults.object(forKey: "borno_alert_cpu_threshold") as? Double ?? 90.0

        self.enableMemoryAlert = defaults.object(forKey: "borno_alert_memory_enabled") as? Bool ?? false
        self.memoryThreshold = defaults.object(forKey: "borno_alert_memory_threshold") as? Double ?? 90.0

        self.enableDiskAlert = defaults.object(forKey: "borno_alert_disk_enabled") as? Bool ?? true
        self.diskThresholdGB = defaults.object(forKey: "borno_alert_disk_threshold_gb") as? Double ?? 15.0

        self.enableBatteryAlert = defaults.object(forKey: "borno_alert_battery_enabled") as? Bool ?? true
        self.batteryThresholdPercent = defaults.object(forKey: "borno_alert_battery_threshold") as? Int ?? 20

        self.enableTemperatureAlert = defaults.object(forKey: "borno_alert_temp_enabled") as? Bool ?? false
        self.temperatureThresholdCelsius = defaults.object(forKey: "borno_alert_temp_threshold") as? Double ?? 90.0

        self.enableNetworkDisconnectAlert = defaults.object(forKey: "borno_alert_net_disc_enabled") as? Bool ?? false

        requestNotificationAuthorization()
    }

    public func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Evaluate Real Measurements
    @discardableResult
    public func evaluate(snapshot: SystemMetricsSnapshot) -> [String] {
        var triggeredAlerts: [String] = []
        let now = Date()

        // 1. CPU Threshold
        if enableCPUAlert && snapshot.cpu.totalUsage >= cpuThreshold {
            if canTriggerAlert(id: "cpu", at: now) {
                let msg = "High CPU Load: \(String(format: "%.1f%%", snapshot.cpu.totalUsage)) (Exceeds \(Int(cpuThreshold))% threshold)"
                sendNotification(title: "High CPU Alert", body: msg)
                markAlertTriggered(id: "cpu", at: now)
                triggeredAlerts.append(msg)
            }
        }

        // 2. Memory Pressure / Usage
        if enableMemoryAlert && snapshot.memory.usagePercentage >= memoryThreshold {
            if canTriggerAlert(id: "memory", at: now) {
                let msg = "High Memory Pressure: \(String(format: "%.1f%%", snapshot.memory.usagePercentage)) used"
                sendNotification(title: "Memory Alert", body: msg)
                markAlertTriggered(id: "memory", at: now)
                triggeredAlerts.append(msg)
            }
        }

        // 3. Disk Free Space
        let freeGB = Double(snapshot.storage.availableCapacityBytes) / (1024.0 * 1024.0 * 1024.0)
        if enableDiskAlert && freeGB < diskThresholdGB && snapshot.storage.totalCapacityBytes > 0 {
            if canTriggerAlert(id: "disk", at: now) {
                let msg = "Low Disk Space: Only \(String(format: "%.1f GB", freeGB)) available on system volume"
                sendNotification(title: "Storage Warning", body: msg)
                markAlertTriggered(id: "disk", at: now)
                triggeredAlerts.append(msg)
            }
        }

        // 4. Low Battery
        if enableBatteryAlert && snapshot.battery.hasBattery && !snapshot.battery.isCharging && snapshot.battery.percentage <= batteryThresholdPercent {
            if canTriggerAlert(id: "battery", at: now) {
                let msg = "Battery is at \(snapshot.battery.percentage)% — connect power adapter"
                sendNotification(title: "Low Battery", body: msg)
                markAlertTriggered(id: "battery", at: now)
                triggeredAlerts.append(msg)
            }
        }

        // 5. High Temperature (Only when genuinely measured)
        if enableTemperatureAlert, let cpuTemp = snapshot.sensors.cpuTemperature, cpuTemp >= temperatureThresholdCelsius {
            if canTriggerAlert(id: "temp", at: now) {
                let msg = "CPU temperature has reached \(String(format: "%.1f °C", cpuTemp))"
                sendNotification(title: "Thermal Warning", body: msg)
                markAlertTriggered(id: "temp", at: now)
                triggeredAlerts.append(msg)
            }
        }

        // 6. Network Disconnected
        if enableNetworkDisconnectAlert && snapshot.network.activeInterfaces.isEmpty {
            if canTriggerAlert(id: "network", at: now) {
                let msg = "All network interfaces are currently inactive."
                sendNotification(title: "Network Offline", body: msg)
                markAlertTriggered(id: "network", at: now)
                triggeredAlerts.append(msg)
            }
        }

        return triggeredAlerts
    }

    public func canTriggerAlert(id: String, at date: Date = Date()) -> Bool {
        guard let last = lastTriggeredDates[id] else { return true }
        return date.timeIntervalSince(last) >= cooldownSeconds
    }

    public func markAlertTriggered(id: String, at date: Date = Date()) {
        lastTriggeredDates[id] = date
    }

    public func resetCooldowns() {
        lastTriggeredDates.removeAll()
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
