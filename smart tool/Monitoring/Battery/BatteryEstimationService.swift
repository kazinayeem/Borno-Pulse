//
//  BatteryEstimationService.swift
//  Borno Pulse
//

import AppKit
import Foundation
import UserNotifications

// MARK: - Time Range
public enum BatteryTimeRange: String, CaseIterable, Identifiable, Codable, Sendable {
    case oneHour = "1 Hour"
    case sixHours = "6 Hours"
    case oneDay = "24 Hours"
    case sevenDays = "7 Days"
    
    public var id: String { rawValue }
    
    public var intervalSeconds: TimeInterval {
        switch self {
        case .oneHour: return 3600
        case .sixHours: return 3600 * 6
        case .oneDay: return 3600 * 24
        case .sevenDays: return 3600 * 24 * 7
        }
    }
}

// MARK: - Historical Sample
public struct BatteryHistoricalSample: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let percentage: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let ratePerHour: Double?
    public let wattage: Double?
    public let estimatedMinutes: Int?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        percentage: Int,
        isCharging: Bool,
        isPluggedIn: Bool,
        ratePerHour: Double? = nil,
        wattage: Double? = nil,
        estimatedMinutes: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.ratePerHour = ratePerHour
        self.wattage = wattage
        self.estimatedMinutes = estimatedMinutes
    }
}

// MARK: - Battery Estimate Result
public struct BatteryEstimateResult: Sendable {
    public let estimatedMinutes: Int?
    public let confidence: BatteryEstimateConfidence
    public let ratePercentagePerHour: Double?
    public let wattage: Double?
    public let stateOfCharge: BatteryStateOfCharge
    public let formattedTimeRemaining: String
    public let lastUpdated: Date
    
    public init(
        estimatedMinutes: Int?,
        confidence: BatteryEstimateConfidence,
        ratePercentagePerHour: Double?,
        wattage: Double?,
        stateOfCharge: BatteryStateOfCharge,
        formattedTimeRemaining: String,
        lastUpdated: Date = Date()
    ) {
        self.estimatedMinutes = estimatedMinutes
        self.confidence = confidence
        self.ratePercentagePerHour = ratePercentagePerHour
        self.wattage = wattage
        self.stateOfCharge = stateOfCharge
        self.formattedTimeRemaining = formattedTimeRemaining
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Battery Estimation Service
@MainActor
public final class BatteryEstimationService: ObservableObject {
    public static let shared = BatteryEstimationService()
    
    @Published public var history: [BatteryHistoricalSample] = []
    @Published public var latestEstimate: BatteryEstimateResult? = nil
    
    // In-memory sliding window for slope calculation
    private var activeWindowSamples: [(date: Date, percentage: Double, isCharging: Bool, isPluggedIn: Bool)] = []
    
    // Notification debounce flags
    private var lastPluggedInState: Bool? = nil
    private var hasAlertedLowBattery: Bool = false
    private var hasAlertedFullCharge: Bool = false
    private var hasAlertedRapidDischarge: Bool = false
    
    private var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NaemSmartTool/Battery", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("battery_history.json")
    }
    
    private init() {
        loadHistory()
        requestNotificationPermission()
    }
    
    // MARK: - Process Raw Battery Sample
    public func processSample(
        hasBattery: Bool,
        percentage: Int,
        isCharging: Bool,
        isPluggedIn: Bool,
        timeToEmptyMinutes: Int?,
        timeToFullMinutes: Int?,
        voltageVolts: Double?,
        amperageAmps: Double?,
        wattage: Double?,
        temperatureCelsius: Double?
    ) -> (estimatedMinutes: Int?, confidence: BatteryEstimateConfidence, state: BatteryStateOfCharge, ratePerHour: Double?, formatted: String) {
        guard hasBattery else {
            return (
                estimatedMinutes: nil,
                confidence: .unavailable,
                state: .acDesktop,
                ratePerHour: nil,
                formatted: "AC Power Connected (Desktop Mac)"
            )
        }
        
        let now = Date()
        
        // Check state transitions (charging changed or AC plugged changed)
        if let lastState = activeWindowSamples.last {
            if lastState.isPluggedIn != isPluggedIn || lastState.isCharging != isCharging {
                // Reset active window on state transition
                activeWindowSamples.removeAll()
                if !isPluggedIn {
                    // Reset full charge alert on unplugging
                    hasAlertedFullCharge = false
                }
                if isPluggedIn {
                    // Reset low battery and rapid discharge alerts on plugging in
                    hasAlertedLowBattery = false
                    hasAlertedRapidDischarge = false
                }
            } else if now.timeIntervalSince(lastState.date) > 45.0 {
                // Machine was asleep or large time gap -> reset window to avoid skewed rate
                activeWindowSamples.removeAll()
            }
        }
        
        // Add to active window
        activeWindowSamples.append((date: now, percentage: Double(percentage), isCharging: isCharging, isPluggedIn: isPluggedIn))
        // Keep active window bounded to last 15 minutes of samples
        let cutoff = now.addingTimeInterval(-900)
        activeWindowSamples.removeAll { $0.date < cutoff }
        
        let lowThreshold = AppSettings.shared.batteryAlertThreshold
        
        // Compute estimate
        let estimate = Self.computeEstimate(
            samples: activeWindowSamples,
            lowBatteryThreshold: lowThreshold,
            osTimeToEmptyMinutes: timeToEmptyMinutes,
            osTimeToFullMinutes: timeToFullMinutes
        )
        
        let estimateResult = BatteryEstimateResult(
            estimatedMinutes: estimate.minutes,
            confidence: estimate.confidence,
            ratePercentagePerHour: estimate.ratePerHour,
            wattage: wattage,
            stateOfCharge: estimate.state,
            formattedTimeRemaining: estimate.formatted,
            lastUpdated: now
        )
        self.latestEstimate = estimateResult
        
        // Append to historical samples (throttle history append to once every 30 seconds unless state changed)
        let shouldRecordHistory: Bool
        if let lastHistorical = history.last {
            let elapsed = now.timeIntervalSince(lastHistorical.timestamp)
            let stateChanged = lastHistorical.isCharging != isCharging || lastHistorical.isPluggedIn != isPluggedIn
            shouldRecordHistory = elapsed >= 30.0 || stateChanged
        } else {
            shouldRecordHistory = true
        }
        
        if shouldRecordHistory {
            let sample = BatteryHistoricalSample(
                timestamp: now,
                percentage: percentage,
                isCharging: isCharging,
                isPluggedIn: isPluggedIn,
                ratePerHour: estimate.ratePerHour,
                wattage: wattage,
                estimatedMinutes: estimate.minutes
            )
            history.append(sample)
            pruneAndPersistHistory()
        }
        
        // Evaluate notifications
        evaluateNotifications(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            ratePerHour: estimate.ratePerHour,
            formattedRemaining: estimate.formatted
        )
        
        return (
            estimatedMinutes: estimate.minutes,
            confidence: estimate.confidence,
            state: estimate.state,
            ratePerHour: estimate.ratePerHour,
            formatted: estimate.formatted
        )
    }
    
    // MARK: - Mathematical Estimation Engine (Pure & Testable)
    public static func computeEstimate(
        samples: [(date: Date, percentage: Double, isCharging: Bool, isPluggedIn: Bool)],
        lowBatteryThreshold: Int,
        osTimeToEmptyMinutes: Int?,
        osTimeToFullMinutes: Int?
    ) -> (minutes: Int?, confidence: BatteryEstimateConfidence, ratePerHour: Double?, state: BatteryStateOfCharge, formatted: String) {
        guard let current = samples.last else {
            return (nil, .unavailable, nil, .unknown, "Time remaining unavailable")
        }
        
        let currentPct = current.percentage
        let isPluggedIn = current.isPluggedIn
        let isCharging = current.isCharging
        
        // 1. Fully Charged State
        if isPluggedIn && (currentPct >= 100.0 || (!isCharging && currentPct >= 99.0)) {
            return (0, .high, 0.0, .fullyCharged, "Fully Charged")
        }
        
        // 2. Charging State
        if isCharging {
            let state: BatteryStateOfCharge = .charging
            
            // Check OS native estimate first if valid
            if let osMinutes = osTimeToFullMinutes, osMinutes > 0 && osMinutes < 1440 {
                let formatted = formatDuration(minutes: osMinutes, prefix: "until full")
                return (osMinutes, .high, nil, state, formatted)
            }
            
            // Empirical rate calculation
            guard samples.count >= 3 else {
                return (nil, .calculating, nil, state, "Calculating charge estimate...")
            }
            
            guard let first = samples.first,
                  let last = samples.last else {
                return (nil, .calculating, nil, state, "Calculating charge estimate...")
            }
            let timeDiffHours = last.date.timeIntervalSince(first.date) / 3600.0
            guard timeDiffHours >= (15.0 / 3600.0) else { // Need at least 15 seconds
                return (nil, .calculating, nil, state, "Calculating charge estimate...")
            }
            
            let pctDiff = last.percentage - first.percentage
            var chargeRatePerHour = pctDiff / timeDiffHours
            
            // Guard against negative or near-zero charging rate
            if chargeRatePerHour <= 0.5 {
                // If battery is nearly full, it charges very slowly (constant voltage saturation)
                if currentPct >= 90.0 {
                    let remMinutes = Int((100.0 - currentPct) * 4.0) // ~4 min per % near 100%
                    let clamped = max(5, min(remMinutes, 120))
                    return (clamped, .low, 1.5, state, formatDuration(minutes: clamped, prefix: "until full"))
                }
                return (nil, .unavailable, nil, state, "Calculating charge estimate...")
            }
            
            // Lithium charging curve compensation:
            // From 80% to 100%, charge rate typically tapers by ~40-50%
            var estimatedHours: Double
            if currentPct < 80.0 {
                let to80 = (80.0 - currentPct) / chargeRatePerHour
                let from80to100 = 20.0 / (chargeRatePerHour * 0.6)
                estimatedHours = to80 + from80to100
            } else {
                let taperedRate = max(1.0, chargeRatePerHour * 0.7)
                estimatedHours = (100.0 - currentPct) / taperedRate
            }
            
            let minutes = max(1, min(Int(estimatedHours * 60.0), 1440))
            let confidence: BatteryEstimateConfidence = samples.count >= 8 && timeDiffHours >= (60.0 / 3600.0) ? .high : .medium
            let formatted = formatDuration(minutes: minutes, prefix: "until full")
            return (minutes, confidence, chargeRatePerHour, state, formatted)
        }
        
        // 3. Discharging State
        let state: BatteryStateOfCharge = isPluggedIn ? .charging : .discharging
        
        // If plugged in but not charging (e.g. Optimized Battery Charging holding at 80%)
        if isPluggedIn && !isCharging {
            return (nil, .high, 0.0, .acDesktop, "On Power Adapter (Not Charging)")
        }
        
        // Check OS native time to empty if valid
        if let osMinutes = osTimeToEmptyMinutes, osMinutes > 0 && osMinutes < 2880 {
            let formatted = formatDuration(minutes: osMinutes, prefix: "remaining")
            return (osMinutes, .high, nil, state, formatted)
        }
        
        // Empirical discharge rate calculation
        guard samples.count >= 3 else {
            return (nil, .calculating, nil, state, "Calculating estimate...")
        }
        
        guard let first = samples.first,
              let last = samples.last else {
            return (nil, .calculating, nil, state, "Calculating estimate...")
        }
        let timeDiffHours = last.date.timeIntervalSince(first.date) / 3600.0
        guard timeDiffHours >= (15.0 / 3600.0) else { // Need at least 15 seconds
            return (nil, .calculating, nil, state, "Calculating estimate...")
        }
        
        let pctDrop = first.percentage - last.percentage
        var dischargeRatePerHour = pctDrop / timeDiffHours
        
        // If discharge rate has not produced enough % drop yet, calculate from available drop
        if dischargeRatePerHour <= 0.1 {
            // Very low drain or not enough delta yet
            if timeDiffHours < (90.0 / 3600.0) {
                return (nil, .calculating, nil, state, "Calculating estimate...")
            }
            // Conservative fallback for ultra-idle state (e.g. 5% per hour)
            dischargeRatePerHour = 5.0
        }
        
        // Cap unrealistic discharge rates (> 80%/hour is improbable for normal usage)
        let clampedRate = min(80.0, max(1.0, dischargeRatePerHour))
        
        // Calculate time remaining until configured low battery threshold (e.g. 10%)
        let usablePercentage = max(0.0, currentPct - Double(lowBatteryThreshold))
        let estimatedHours = usablePercentage / clampedRate
        let minutes = max(0, min(Int(estimatedHours * 60.0), 2880))
        
        let confidence: BatteryEstimateConfidence
        if samples.count >= 10 && timeDiffHours >= (120.0 / 3600.0) {
            confidence = .high
        } else if samples.count >= 5 && timeDiffHours >= (30.0 / 3600.0) {
            confidence = .medium
        } else {
            confidence = .low
        }
        
        let formatted = formatDuration(minutes: minutes, prefix: "remaining")
        return (minutes, confidence, -clampedRate, state, formatted)
    }
    
    // MARK: - Format Duration Helper
    public static func formatDuration(minutes: Int, prefix: String = "") -> String {
        let h = minutes / 60
        let m = minutes % 60
        
        let durStr: String
        if h > 0 {
            durStr = "\(h)h \(m)m"
        } else {
            durStr = "\(m)m"
        }
        
        if prefix.isEmpty {
            return durStr
        } else {
            return "\(durStr) \(prefix)"
        }
    }
    
    // MARK: - Range Filter Helper
    public func samples(for range: BatteryTimeRange) -> [BatteryHistoricalSample] {
        let cutoff = Date().addingTimeInterval(-range.intervalSeconds)
        return history.filter { $0.timestamp >= cutoff }
    }
    
    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func evaluateNotifications(
        percentage: Int,
        isCharging: Bool,
        isPluggedIn: Bool,
        ratePerHour: Double?,
        formattedRemaining: String
    ) {
        let settings = AppSettings.shared
        
        // 1. AC Disconnected Notification
        if let previous = lastPluggedInState {
            if previous && !isPluggedIn && settings.notifyPowerDisconnected {
                sendNotification(
                    title: "Mac Disconnected from Power",
                    body: "Now running on battery power at \(percentage)%. Estimated \(formattedRemaining)."
                )
            }
        }
        lastPluggedInState = isPluggedIn
        
        // 2. Low Battery Notification
        if !isPluggedIn && percentage <= settings.batteryAlertThreshold {
            if !hasAlertedLowBattery && settings.notifyLowBattery {
                hasAlertedLowBattery = true
                sendNotification(
                    title: "Low Battery Warning (\(percentage)%)",
                    body: "Battery is low. Approximately \(formattedRemaining). Connect your power adapter."
                )
            }
        } else if percentage > settings.batteryAlertThreshold + 5 {
            hasAlertedLowBattery = false
        }
        
        // 3. Fully Charged Notification
        if isPluggedIn && percentage >= 100 {
            if !hasAlertedFullCharge && settings.notifyFullyCharged {
                hasAlertedFullCharge = true
                sendNotification(
                    title: "Battery Fully Charged",
                    body: "Your Mac battery has reached 100% capacity."
                )
            }
        }
        
        // 4. Rapid Discharge Notification
        if let rate = ratePerHour, rate < -settings.rapidDischargeThresholdRatePerHour && !isPluggedIn {
            if !hasAlertedRapidDischarge && settings.notifyRapidDischarge {
                hasAlertedRapidDischarge = true
                sendNotification(
                    title: "Unusually Rapid Battery Discharge",
                    body: String(format: "Battery is draining at %.1f%%/hour. Check high-energy processes.", abs(rate))
                )
            }
        } else if let rate = ratePerHour, rate > -settings.rapidDischargeThresholdRatePerHour * 0.7 {
            hasAlertedRapidDischarge = false
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "BornoPulse_Battery_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Persistence & Retention (7 Days)
    private func pruneAndPersistHistory() {
        let retentionCutoff = Date().addingTimeInterval(-7 * 86400) // 7 days retention
        history.removeAll { $0.timestamp < retentionCutoff }
        
        // Atomic save
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyFileURL, options: .atomic)
        }
    }
    
    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyFileURL),
              let list = try? JSONDecoder().decode([BatteryHistoricalSample].self, from: data) else {
            return
        }
        let retentionCutoff = Date().addingTimeInterval(-7 * 86400)
        self.history = list.filter { $0.timestamp >= retentionCutoff }
    }
    
    public func clearHistory() {
        history.removeAll()
        try? FileManager.default.removeItem(at: historyFileURL)
    }
}
