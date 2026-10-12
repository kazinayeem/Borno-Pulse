//
//  FocusTimerService.swift
//  Borno Pulse
//

import AppKit
import Combine
import Foundation

@MainActor
public final class FocusTimerService: ObservableObject {
    public static let shared = FocusTimerService()
    
    // MARK: - Published State
    @Published public var currentMode: FocusSessionMode = .focus
    @Published public var isRunning: Bool = false
    @Published public var remainingSeconds: TimeInterval = 25 * 60
    @Published public var totalSessionSeconds: TimeInterval = 25 * 60
    @Published public var completedCyclesCount: Int = 0
    @Published public var sessionHistory: [FocusSessionRecord] = []
    
    // Configurable Settings (Persisted to UserDefaults)
    @Published public var focusDurationSeconds: TimeInterval = 25 * 60 {
        didSet {
            UserDefaults.standard.set(focusDurationSeconds, forKey: Keys.focusDurationSeconds)
        }
    }
    
    @Published public var customFocusDurationSeconds: TimeInterval = 25 * 60 {
        didSet {
            UserDefaults.standard.set(customFocusDurationSeconds, forKey: Keys.customFocusDurationSeconds)
        }
    }
    
    @Published public var shortBreakMinutes: Int = 5 {
        didSet {
            UserDefaults.standard.set(shortBreakMinutes, forKey: Keys.shortBreakMinutes)
        }
    }
    
    @Published public var longBreakMinutes: Int = 15 {
        didSet {
            UserDefaults.standard.set(longBreakMinutes, forKey: Keys.longBreakMinutes)
        }
    }
    
    @Published public var soundEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled)
        }
    }
    
    // Compatibility helper for legacy minutes callers
    public var focusMinutes: Int {
        get { Int(round(focusDurationSeconds / 60.0)) }
        set { setFocusDuration(seconds: TimeInterval(newValue * 60)) }
    }
    
    // Validation Constraints
    public static let minDurationSeconds: TimeInterval = 10.0         // 10 seconds minimum
    public static let maxDurationSeconds: TimeInterval = 12.0 * 3600  // 12 hours maximum
    
    public enum DurationValidationError: LocalizedError, Equatable {
        case zeroOrNegative
        case belowMinimum(TimeInterval)
        case exceedsMaximum(TimeInterval)
        
        public var errorDescription: String? {
            switch self {
            case .zeroOrNegative:
                return "Duration must be greater than zero."
            case .belowMinimum(let minSecs):
                return "Minimum duration is \(Int(minSecs)) seconds."
            case .exceedsMaximum(let maxSecs):
                let maxHours = Int(maxSecs / 3600)
                return "Maximum duration is \(maxHours) hours."
            }
        }
    }
    
    // Engine State
    private var timerCancellable: AnyCancellable?
    private var targetEndTime: Date? = nil
    private var sessionStartTime: Date? = nil
    
    private enum Keys {
        static let focusDurationSeconds = "borno_focus_duration_seconds"
        static let customFocusDurationSeconds = "borno_custom_focus_duration_seconds"
        static let shortBreakMinutes = "borno_short_break_minutes"
        static let longBreakMinutes = "borno_long_break_minutes"
        static let soundEnabled = "borno_focus_sound_enabled"
        static let completedCyclesCount = "borno_focus_completed_cycles"
    }
    
    private var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NaemSmartTool/Focus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("focus_history.json")
    }
    
    private init() {
        let savedDuration = UserDefaults.standard.double(forKey: Keys.focusDurationSeconds)
        if savedDuration >= Self.minDurationSeconds && savedDuration <= Self.maxDurationSeconds {
            self.focusDurationSeconds = savedDuration
        } else {
            self.focusDurationSeconds = 25 * 60
        }
        
        let savedCustom = UserDefaults.standard.double(forKey: Keys.customFocusDurationSeconds)
        if savedCustom >= Self.minDurationSeconds && savedCustom <= Self.maxDurationSeconds {
            self.customFocusDurationSeconds = savedCustom
        } else {
            self.customFocusDurationSeconds = 25 * 60
        }
        
        let savedShortBreak = UserDefaults.standard.integer(forKey: Keys.shortBreakMinutes)
        if savedShortBreak > 0 {
            self.shortBreakMinutes = savedShortBreak
        }
        
        let savedLongBreak = UserDefaults.standard.integer(forKey: Keys.longBreakMinutes)
        if savedLongBreak > 0 {
            self.longBreakMinutes = savedLongBreak
        }
        
        if UserDefaults.standard.object(forKey: Keys.soundEnabled) != nil {
            self.soundEnabled = UserDefaults.standard.bool(forKey: Keys.soundEnabled)
        }
        
        self.completedCyclesCount = UserDefaults.standard.integer(forKey: Keys.completedCyclesCount)
        
        loadHistory()
        resetToCurrentMode()
    }
    
    // MARK: - Duration Configuration
    public static func validateDuration(hours: Int, minutes: Int, seconds: Int) -> Result<TimeInterval, DurationValidationError> {
        guard hours >= 0 && minutes >= 0 && seconds >= 0 else {
            return .failure(.zeroOrNegative)
        }
        let total = TimeInterval(hours * 3600 + minutes * 60 + seconds)
        guard total > 0 else {
            return .failure(.zeroOrNegative)
        }
        guard total >= minDurationSeconds else {
            return .failure(.belowMinimum(minDurationSeconds))
        }
        guard total <= maxDurationSeconds else {
            return .failure(.exceedsMaximum(maxDurationSeconds))
        }
        return .success(total)
    }
    
    @discardableResult
    public func setFocusDuration(seconds: TimeInterval) -> Bool {
        guard !isRunning else { return false }
        guard seconds >= Self.minDurationSeconds && seconds <= Self.maxDurationSeconds else { return false }
        focusDurationSeconds = seconds
        if currentMode == .focus {
            resetToCurrentMode()
        }
        return true
    }
    
    @discardableResult
    public func setFocusDuration(minutes: Int) -> Bool {
        setFocusDuration(seconds: TimeInterval(minutes * 60))
    }
    
    @discardableResult
    public func applyCustomDuration(hours: Int, minutes: Int, seconds: Int) -> Result<TimeInterval, DurationValidationError> {
        guard !isRunning else {
            return .failure(.zeroOrNegative)
        }
        let validation = Self.validateDuration(hours: hours, minutes: minutes, seconds: seconds)
        switch validation {
        case .success(let secs):
            self.customFocusDurationSeconds = secs
            self.focusDurationSeconds = secs
            if currentMode == .focus {
                resetToCurrentMode()
            }
            return .success(secs)
        case .failure(let err):
            return .failure(err)
        }
    }
    
    public static func formatDuration(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        
        if hours > 0 {
            if mins > 0 {
                return "\(hours)h \(mins)m"
            } else {
                return "\(hours)h"
            }
        } else if mins > 0 {
            if secs > 0 {
                return "\(mins)m \(secs)s"
            } else {
                return "\(mins)m"
            }
        } else {
            return "\(secs)s"
        }
    }
    
    public var formattedCurrentFocusDuration: String {
        Self.formatDuration(seconds: focusDurationSeconds)
    }
    
    // MARK: - Timer Controls
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        sessionStartTime = Date()
        targetEndTime = Date().addingTimeInterval(remainingSeconds)
        
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.tick(now: now)
            }
    }
    
    public func pause() {
        guard isRunning else { return }
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        targetEndTime = nil
    }
    
    public func reset() {
        pause()
        sessionStartTime = nil
        resetToCurrentMode()
    }
    
    public func skipToNextMode() {
        pause()
        sessionStartTime = nil
        // Advance mode without recording completed focus history
        if currentMode == .focus {
            if (completedCyclesCount + 1) % 4 == 0 {
                currentMode = .longBreak
            } else {
                currentMode = .shortBreak
            }
        } else {
            currentMode = .focus
        }
        resetToCurrentMode()
    }
    
    private func resetToCurrentMode() {
        let secs: TimeInterval = {
            switch currentMode {
            case .focus: return focusDurationSeconds
            case .shortBreak: return TimeInterval(shortBreakMinutes * 60)
            case .longBreak: return TimeInterval(longBreakMinutes * 60)
            }
        }()
        totalSessionSeconds = secs
        remainingSeconds = secs
    }
    
    private func tick(now: Date) {
        guard let target = targetEndTime else { return }
        let diff = target.timeIntervalSince(now)
        
        if diff <= 0 {
            remainingSeconds = 0
            completeSession()
        } else {
            remainingSeconds = diff
        }
    }
    
    private func completeSession() {
        pause()
        if soundEnabled {
            NSSound(named: "Glass")?.play()
        }
        
        let start = sessionStartTime ?? Date().addingTimeInterval(-totalSessionSeconds)
        let record = FocusSessionRecord(
            startTime: start,
            endTime: Date(),
            durationSeconds: totalSessionSeconds,
            mode: currentMode,
            isCompleted: true
        )
        sessionHistory.insert(record, at: 0)
        saveHistory()
        sessionStartTime = nil
        
        // Advance cycle
        if currentMode == .focus {
            completedCyclesCount += 1
            UserDefaults.standard.set(completedCyclesCount, forKey: Keys.completedCyclesCount)
            if completedCyclesCount % 4 == 0 {
                currentMode = .longBreak
            } else {
                currentMode = .shortBreak
            }
        } else {
            currentMode = .focus
        }
        
        resetToCurrentMode()
    }
    
    // MARK: - Query & Aggregations
    public var todayFocusSeconds: TimeInterval {
        let today = Calendar.current.startOfDay(for: Date())
        return sessionHistory
            .filter { $0.mode == .focus && $0.startTime >= today }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    public var weekFocusSeconds: TimeInterval {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return sessionHistory
            .filter { $0.mode == .focus && $0.startTime >= weekAgo }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    public func deleteRecord(id: UUID) {
        sessionHistory.removeAll { $0.id == id }
        saveHistory()
    }
    
    public func clearAllHistory() {
        sessionHistory.removeAll()
        saveHistory()
    }
    
    // MARK: - Persistence
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(sessionHistory)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed saving focus history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyFileURL)
            self.sessionHistory = try JSONDecoder().decode([FocusSessionRecord].self, from: data)
        } catch {
            print("Failed loading focus history: \(error)")
        }
    }
}
