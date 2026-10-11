//
//  FocusPomodoroView.swift
//  Borno Pulse
//

import Charts
import SwiftUI

public struct FocusPomodoroView: View {
    @ObservedObject var focus = FocusTimerService.shared
    @ObservedObject var screenTime = ScreenTimeTrackerService.shared
    
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
                .help("Reset Timer")
                
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
                
                // Skip
                Button {
                    focus.skipToNextMode()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .help("Skip to next cycle")
            }
            
            // Presets
            if !focus.isRunning && focus.currentMode == .focus {
                HStack(spacing: 8) {
                    presetButton(minutes: 25)
                    presetButton(minutes: 45)
                    presetButton(minutes: 50)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .smartCard()
    }
    
    // MARK: - History Table Card
    private var historyTableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Completed Focus Sessions (\(focus.sessionHistory.count))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            
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
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func presetButton(minutes: Int) -> some View {
        let isSelected = focus.focusMinutes == minutes
        return Button {
            focus.setFocusDuration(minutes: minutes)
        } label: {
            Text("\(minutes)m")
                .fontWeight(isSelected ? .bold : .regular)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? AppTheme.successGreen : Color.secondary)
        .controlSize(.small)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
