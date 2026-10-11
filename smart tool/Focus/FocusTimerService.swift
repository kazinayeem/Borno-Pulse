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
    
    // Published State
    @Published public var currentMode: FocusSessionMode = .focus
    @Published public var isRunning: Bool = false
    @Published public var remainingSeconds: TimeInterval = 25 * 60
    @Published public var totalSessionSeconds: TimeInterval = 25 * 60
    @Published public var completedCyclesCount: Int = 0
    @Published public var sessionHistory: [FocusSessionRecord] = []
    
    // Configurable Settings
    @Published public var focusMinutes: Int = 25
    @Published public var shortBreakMinutes: Int = 5
    @Published public var longBreakMinutes: Int = 15
    @Published public var soundEnabled: Bool = true
    
    // Engine State
    private var timerCancellable: AnyCancellable?
    private var targetEndTime: Date? = nil
    private var sessionStartTime: Date? = nil
    
    private var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NaemSmartTool/Focus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("focus_history.json")
    }
    
    private init() {
        loadHistory()
        resetToCurrentMode()
    }
    
    // MARK: - Timer Controls
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        sessionStartTime = Date()
        targetEndTime = Date().addingTimeInterval(remainingSeconds)
        
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
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
        resetToCurrentMode()
    }
    
    public func skipToNextMode() {
        pause()
        if currentMode == .focus {
            completedCyclesCount += 1
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
    
    public func setFocusDuration(minutes: Int) {
        focusMinutes = minutes
        if currentMode == .focus && !isRunning {
            resetToCurrentMode()
        }
    }
    
    private func resetToCurrentMode() {
        let mins = {
            switch currentMode {
            case .focus: return focusMinutes
            case .shortBreak: return shortBreakMinutes
            case .longBreak: return longBreakMinutes
            }
        }()
        totalSessionSeconds = TimeInterval(mins * 60)
        remainingSeconds = totalSessionSeconds
    }
    
    private func tick(now: Date) {
        guard let target = targetEndTime else { return }
        let diff = target.timeIntervalSince(now)
        
        if diff <= 0 {
            // Completed Session!
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
        
        // Advance cycle
        skipToNextMode()
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
