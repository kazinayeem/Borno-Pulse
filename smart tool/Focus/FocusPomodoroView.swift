//
//  FocusPomodoroView.swift
//  Borno Pulse
//

import Charts
import SwiftUI

public struct FocusPomodoroView: View {
    @ObservedObject var focus = FocusTimerService.shared
    @ObservedObject var screenTime = ScreenTimeTrackerService.shared
    @State private var showCustomPopover: Bool = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                AdaptivePageHeader(
                    title: "Focus & Pomodoro",
                    subtitle: "Distraction-free focus sessions, structured breaks & session reporting",
                    icon: "timer",
                    iconColor: AppTheme.matrixGreen
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: focus.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 12))
                        Toggle("Chime", isOn: $focus.soundEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                }
                
                // Main Timer Card
                timerDisplayCard
                
                // Focus Metrics Grid
                AdaptiveCardGrid(minColumnWidth: 150, spacing: 12) {
                    metricCard(title: "Today's Focus", value: Formatters.duration(focus.todayFocusSeconds), icon: "target", tint: AppTheme.matrixGreen)
                    metricCard(title: "Last 7 Days", value: Formatters.duration(focus.weekFocusSeconds), icon: "chart.bar.fill", tint: AppTheme.electricBlue)
                    metricCard(title: "Cycles Completed", value: "\(focus.completedCyclesCount)", icon: "repeat", tint: AppTheme.purpleAccent)
                    metricCard(title: "Foreground Active", value: Formatters.duration(screenTime.getStatistics().todayActiveDuration), icon: "hourglass", tint: AppTheme.warningAmber)
                }
                
                // Session History Table
                historyTableCard
            }
            .padding(18)
        }
        .background(AppTheme.graphiteCanvas)
    }
    
    // MARK: - Timer Display Card
    private var timerDisplayCard: some View {
        VStack(spacing: 16) {
            // Mode Indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(focus.currentMode == .focus ? AppTheme.matrixGreen : AppTheme.electricCyan)
                    .frame(width: 8, height: 8)
                
                Text(focus.currentMode.rawValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(focus.currentMode == .focus ? AppTheme.matrixGreen : AppTheme.electricCyan)
                
                Text("• Cycle \( (focus.completedCyclesCount % 4) + 1 ) of 4")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(AppTheme.subtleFill)
            .clipShape(Capsule())
            
            // Circular Ring & Digits
            ZStack {
                let progress = focus.totalSessionSeconds > 0 ? (focus.remainingSeconds / focus.totalSessionSeconds) : 0
                
                Circle()
                    .stroke(AppTheme.subtleFillStrong, lineWidth: 10)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        focus.currentMode == .focus ? AppTheme.matrixGreen : AppTheme.electricCyan,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 200, height: 200)
                    .animation(.linear(duration: 0.5), value: progress)
                
                VStack(spacing: 2) {
                    Text(formattedCountdown)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(focus.isRunning ? "IN PROGRESS" : "PAUSED")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(focus.isRunning ? AppTheme.matrixGreen : AppTheme.textTertiary)
                }
            }
            .padding(.vertical, 6)
            
            // Primary Controls
            HStack(spacing: 14) {
                // Reset
                Button {
                    focus.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .help("Reset Timer to Selected Duration")
                .accessibilityLabel("Reset Timer")
                
                // Play / Pause
                Button {
                    if focus.isRunning {
                        focus.pause()
                    } else {
                        focus.start()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: focus.isRunning ? "pause.fill" : "play.fill")
                        Text(focus.isRunning ? "Pause" : "Start Focus")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 130)
                }
                .buttonStyle(.borderedProminent)
                .tint(focus.currentMode == .focus ? AppTheme.successFill : AppTheme.infoFill)
                .accessibilityLabel(focus.isRunning ? "Pause Focus" : "Start Focus")
                
                // Skip
                Button {
                    focus.skipToNextMode()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .help("Skip to next cycle without completing")
                .accessibilityLabel("Skip to next cycle")
            }
            
            // Duration Configuration & Presets
            if focus.currentMode == .focus {
                durationConfigurationSection
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .smartCard()
    }
    
    // MARK: - Duration Configuration Section
    private var durationConfigurationSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
                
                Text("Focus Duration:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                
                Text(focus.formattedCurrentFocusDuration)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.matrixGreen)
                
                if focus.isRunning {
                    Text("(Locked during session)")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            
            HStack(spacing: 6) {
                presetButton(title: "1m", seconds: 60)
                presetButton(title: "2m", seconds: 120)
                presetButton(title: "15m", seconds: 15 * 60)
                presetButton(title: "25m", seconds: 25 * 60)
                presetButton(title: "45m", seconds: 45 * 60)
                presetButton(title: "50m", seconds: 50 * 60)
                
                customButton
            }
            .disabled(focus.isRunning)
            .opacity(focus.isRunning ? 0.6 : 1.0)
            
            if focus.isRunning {
                Text("Pause or reset the session to select a different duration")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.top, 4)
    }
    
    private func presetButton(title: String, seconds: TimeInterval) -> some View {
        let isSelected = abs(focus.focusDurationSeconds - seconds) < 0.5
        return Button {
            focus.setFocusDuration(seconds: seconds)
        } label: {
            Text(title)
                .fontWeight(isSelected ? .bold : .regular)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? AppTheme.matrixGreen : Color.secondary)
        .controlSize(.small)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var customButton: some View {
        let isCustomSelected = ![60, 120, 15 * 60, 25 * 60, 45 * 60, 50 * 60].contains(Int(round(focus.focusDurationSeconds)))
        return Button {
            showCustomPopover = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10))
                Text(isCustomSelected ? "Custom (\(FocusTimerService.formatDuration(seconds: focus.focusDurationSeconds)))" : "Custom…")
            }
            .fontWeight(isCustomSelected ? .bold : .regular)
        }
        .buttonStyle(.bordered)
        .tint(isCustomSelected ? AppTheme.matrixGreen : Color.secondary)
        .controlSize(.small)
        .popover(isPresented: $showCustomPopover) {
            CustomDurationView(focus: focus, isPresented: $showCustomPopover)
        }
    }
    
    // MARK: - History Table Card
    private var historyTableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Completed Focus Sessions (\(focus.sessionHistory.count))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                if !focus.sessionHistory.isEmpty {
                    Button("Clear History") {
                        focus.clearAllHistory()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            
            if focus.sessionHistory.isEmpty {
                Text("No sessions completed yet. Start your first focus block to build your streak.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .smartCard()
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(focus.sessionHistory) { record in
                            HStack {
                                Circle()
                                    .fill(record.mode == .focus ? AppTheme.matrixGreen : AppTheme.electricCyan)
                                    .frame(width: 6, height: 6)
                                
                                Text(record.mode.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                Text("• \(record.startTime.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textTertiary)
                                
                                Spacer()
                                
                                Text(Formatters.duration(record.durationSeconds))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.electricCyan)
                                
                                Button {
                                    focus.deleteRecord(id: record.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.dangerRed)
                                }
                                .buttonStyle(.plain)
                                .help("Delete session")
                                .accessibilityLabel("Delete session")
                            }
                            .padding(8)
                            .background(AppTheme.cardBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(14)
        .smartCard()
    }
    
    // MARK: - Helpers
    private var formattedCountdown: String {
        let total = Int(focus.remainingSeconds)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
    
    private func metricCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .smartCard()
    }
}

// MARK: - Custom Duration Popover View
struct CustomDurationView: View {
    @ObservedObject var focus: FocusTimerService
    @Binding var isPresented: Bool
    
    @State private var hours: Int = 0
    @State private var minutes: Int = 25
    @State private var seconds: Int = 0
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(AppTheme.matrixGreen)
                Text("Custom Focus Duration")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            Text("Set any duration between 10 seconds and 12 hours.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
            
            HStack(spacing: 12) {
                timeField(title: "Hours", value: $hours, max: 12)
                timeField(title: "Minutes", value: $minutes, max: 59)
                timeField(title: "Seconds", value: $seconds, max: 59)
            }
            .padding(10)
            .background(AppTheme.insetBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            
            // Quick preset chips
            HStack(spacing: 6) {
                Text("Quick:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                quickChip(title: "1m", h: 0, m: 1, s: 0)
                quickChip(title: "2m", h: 0, m: 2, s: 0)
                quickChip(title: "10m", h: 0, m: 10, s: 0)
                quickChip(title: "30m", h: 0, m: 30, s: 0)
                quickChip(title: "90m", h: 1, m: 30, s: 0)
            }
            
            if let err = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(AppTheme.dangerRed)
                    Text(err)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.dangerRed)
                }
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("Apply Duration") {
                    let result = focus.applyCustomDuration(hours: hours, minutes: minutes, seconds: seconds)
                    switch result {
                    case .success:
                        isPresented = false
                    case .failure(let err):
                        errorMessage = err.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.successFill)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(AppTheme.cardBackground)
        .onAppear {
            let total = Int(round(focus.focusDurationSeconds))
            hours = total / 3600
            minutes = (total % 3600) / 60
            seconds = total % 60
        }
    }
    
    private func timeField(title: String, value: Binding<Int>, max: Int) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            
            HStack(spacing: 2) {
                TextField("", value: value, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                
                Stepper("", value: value, in: 0...max)
                    .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func quickChip(title: String, h: Int, m: Int, s: Int) -> some View {
        Button(title) {
            hours = h
            minutes = m
            seconds = s
            errorMessage = nil
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }
}
