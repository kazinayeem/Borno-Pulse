//
//  MenuBarPopoverView.swift
//  Borno Pulse
//
//  Premium, compact, native macOS menu bar utility popover.
//

import AppKit
import Charts
import CoreAudio
import SwiftUI

// MARK: - Menu Bar Popover Categories
public enum MenuBarCategory: String, CaseIterable, Identifiable {
    case audio = "Audio"
    case battery = "Battery"
    case hardware = "Hardware"
    case quickActions = "Actions"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .audio: return "speaker.wave.2.fill"
        case .battery: return "bolt.batteryblock.fill"
        case .hardware: return "cpu"
        case .quickActions: return "sparkles"
        }
    }

    public var tooltip: String {
        switch self {
        case .audio: return "Volume Mixer & Audio Devices"
        case .battery: return "Battery Telemetry & Live Power"
        case .hardware: return "Hardware Load & Performance"
        case .quickActions: return "Quick Tools & Shortcuts"
        }
    }
}

public struct MenuBarPopoverView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var audioService = AudioDeviceService.shared
    @ObservedObject var powerService = BatteryPowerService.shared
    @ObservedObject var settings = AppSettings.shared

    @State private var selectedCategory: MenuBarCategory = .audio
    @State private var hasAvailableUpdate: Bool = false
    @State private var updateDismissed: Bool = false

    public var onOpenDashboard: () -> Void
    public var onOpenSettings: () -> Void
    public var onQuickCleanup: () -> Void
    public var onQuit: () -> Void

    public init(
        onOpenDashboard: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onQuickCleanup: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.onOpenDashboard = onOpenDashboard
        self.onOpenSettings = onOpenSettings
        self.onQuickCleanup = onQuickCleanup
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Refined Header
            popoverHeader

            // Optional genuine update notification banner
            if hasAvailableUpdate && !updateDismissed {
                updateNotificationBanner
            }

            Divider().opacity(0.15)

            // 2. Category Navigation Bar
            categoryNavigationBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider().opacity(0.12)

            // 3. Category Content Area (Natural scrolling when needed)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    switch selectedCategory {
                    case .audio:
                        audioMixerSection
                    case .battery:
                        batteryPowerSection
                    case .hardware:
                        hardwareOverviewSection
                    case .quickActions:
                        quickActionsSection
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 340)

            Divider().opacity(0.15)

            // 4. Bottom Actions Toolbar
            bottomActionToolbar
        }
        .frame(width: 330)
        .background(AppTheme.elevatedCardBackground)
        .onAppear {
            audioService.refreshAll()
        }
    }

    // MARK: - 1. Popover Header
    private var popoverHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.electricBlue)

            Text("Borno Pulse")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            StatusBadge(
                text: monitor.snapshot.healthStatusText,
                color: healthColor(monitor.snapshot.healthScore)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(AppTheme.cardBackgroundSecondary)
    }

    private func healthColor(_ score: Int) -> Color {
        if score >= 90 { return AppTheme.successGreen }
        if score >= 70 { return AppTheme.electricBlue }
        if score >= 50 { return AppTheme.warningAmber }
        return AppTheme.dangerRed
    }

    // Update Notification Banner (Only shown if a genuine update exists)
    private var updateNotificationBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .foregroundStyle(AppTheme.electricBlue)
                .font(.system(size: 11))
            Text("Update Available")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Button {
                updateDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Dismiss Notification")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.electricBlue.opacity(0.1))
    }

    // MARK: - 2. Category Navigation Bar
    private var categoryNavigationBar: some View {
        HStack(spacing: 6) {
            ForEach(MenuBarCategory.allCases) { category in
                let isSelected = selectedCategory == category
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedCategory = category
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        Text(category.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        isSelected
                            ? AppTheme.electricBlue.opacity(0.14)
                            : Color.clear
                    )
                    .foregroundStyle(
                        isSelected
                            ? AppTheme.electricBlue
                            : AppTheme.textSecondary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(category.tooltip)
                .accessibilityLabel(category.rawValue)
            }
        }
    }

    // MARK: - 3A. Volume Mixer Section
    private var audioMixerSection: some View {
        VStack(spacing: 10) {
            // Output Device Card
            VStack(alignment: .leading, spacing: 8) {
                compactSectionHeader(title: "Audio Output", icon: "speaker.wave.3.fill", color: AppTheme.electricBlue)

                // Device Picker
                deviceSelectionRow(
                    devices: audioService.outputDevices,
                    selectedID: audioService.defaultOutputDeviceID,
                    icon: "headphones",
                    onSelect: { audioService.setDefaultOutputDevice(id: $0) }
                )

                // Volume Slider
                compactVolumeSlider(
                    value: Binding(
                        get: { audioService.outputVolume },
                        set: { audioService.setOutputVolume($0) }
                    ),
                    isMuted: audioService.isOutputMuted,
                    onToggleMute: { audioService.setOutputMute(!audioService.isOutputMuted) }
                )
            }
            .padding(10)
            .background(AppTheme.cardBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))

            // Microphone Input Card
            VStack(alignment: .leading, spacing: 8) {
                compactSectionHeader(title: "Microphone Input", icon: "mic.fill", color: AppTheme.purpleAccent)

                deviceSelectionRow(
                    devices: audioService.inputDevices,
                    selectedID: audioService.defaultInputDeviceID,
                    icon: "mic",
                    onSelect: { audioService.setDefaultInputDevice(id: $0) }
                )

                compactVolumeSlider(
                    value: Binding(
                        get: { audioService.inputLevel },
                        set: { audioService.setInputVolume($0) }
                    ),
                    isMuted: audioService.isInputMuted,
                    sliderColor: AppTheme.purpleAccent,
                    muteIcon: "mic.slash.fill",
                    onToggleMute: { audioService.setInputMute(!audioService.isInputMuted) }
                )
            }
            .padding(10)
            .background(AppTheme.cardBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))

            // Application Audio Rows
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    compactSectionHeader(title: "Application Audio", icon: "app.connected.to.app.below.fill", color: AppTheme.electricCyan)
                    Spacer()
                    Text("\(audioService.runningAudioApps.count) Active")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                if audioService.runningAudioApps.isEmpty {
                    Text("No media applications currently active.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(audioService.runningAudioApps) { app in
                            applicationAudioRow(app)
                        }
                    }
                }

                // Native API explanation
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(.top, 1)
                    Text("macOS routes application audio to the default output device. Dedicated per-app volume sliders operate via supported scripting or system sound routing.")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(.top, 4)
            }
            .padding(10)
            .background(AppTheme.cardBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
        }
    }

    private func applicationAudioRow(_ app: RunningAudioAppItem) -> some View {
        HStack(spacing: 8) {
            // App Icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.electricBlue)
                    .frame(width: 18, height: 18)
            }

            // Name
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(app.name)
                Text(app.routingDescription)
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Status Badge
            Text(app.isScriptable ? "Scriptable" : "System Route")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(AppTheme.electricBlue.opacity(0.1))
                .foregroundStyle(AppTheme.electricBlue)
                .clipShape(Capsule())

            // Context Action Menu
            Menu {
                Button("Open System Sound Settings") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefPane"))
                }
                Button("Activate \(app.name)") {
                    NSRunningApplication(processIdentifier: app.pid)?.activate()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 16, height: 16)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 3)
    }

    // MARK: - 3B. Battery & Power Section
    private var batteryPowerSection: some View {
        VStack(spacing: 10) {
            if monitor.snapshot.battery.hasBattery {
                let b = monitor.snapshot.battery
                let statusColor: Color = {
                    if b.isCharging { return AppTheme.successGreen }
                    if b.percentage <= 10 { return AppTheme.dangerRed }
                    if b.percentage <= 20 { return AppTheme.warningAmber }
                    return AppTheme.textPrimary
                }()

                VStack(alignment: .leading, spacing: 8) {
                    // Header: Level & State Badge
                    HStack(spacing: 8) {
                        Image(systemName: b.isCharging ? "bolt.batteryblock.fill" : (b.isPluggedIn ? "powerplug.fill" : "battery.100"))
                            .font(.system(size: 14))
                            .foregroundStyle(statusColor)

                        Text("Battery Level")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        Spacer()

                        Text("\(b.percentage)%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(batteryStateBadgeText(b))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.12))
                            .foregroundStyle(statusColor)
                            .clipShape(Capsule())
                    }

                    // Remaining Duration & Health
                    HStack(spacing: 6) {
                        Image(systemName: b.isCharging ? "bolt.fill" : "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(b.formattedTimeRemaining)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        if let health = b.healthPercentage {
                            Text("Health: \(health)%")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        if let cycles = b.cycleCount {
                            Text("• \(cycles) cycles")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }

                    Divider().opacity(0.15)

                    // Live Electrical Watts Grid
                    VStack(spacing: 4) {
                        // Battery Power Row
                        HStack {
                            Text(b.isCharging ? "Charging Power:" : "Discharging Power:")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            if let chargeWatts = b.chargingWatts {
                                Text(String(format: "%.1f W", chargeWatts))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(chargeWatts > 0.05 ? AppTheme.successGreen : AppTheme.textSecondary)
                            } else if let dischargeWatts = b.dischargingWatts {
                                Text(String(format: "%.1f W", dischargeWatts))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.electricCyan)
                            } else if b.isPluggedIn {
                                Text("0.0 W (Holding)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AppTheme.textTertiary)
                            } else {
                                Text("Unavailable on this Mac")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }

                        // System Power Row
                        if let sysW = b.systemPowerWatts {
                            HStack {
                                Text("System Load:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f W", sysW))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AppTheme.purpleAccent)
                            }
                        }

                        // Adapter Rated Power
                        if let rated = b.adapterRatedWatts {
                            HStack {
                                Text("Power Adapter:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                                if let inWatts = b.adapterInputWatts {
                                    Text(String(format: "%.1f W / %d W", inWatts, rated))
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(AppTheme.textPrimary)
                                } else {
                                    Text("\(rated) W Rated")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                        }
                    }

                    // Compact Power Sparkline (Last 5 Minutes)
                    let samples = powerService.samples(for: 300)
                    if samples.count >= 2 {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Recent Power Trend (W)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)

                            Chart(samples) { item in
                                if let c = item.chargingWatts {
                                    LineMark(
                                        x: .value("Time", item.timestamp),
                                        y: .value("Watts", c)
                                    )
                                    .foregroundStyle(AppTheme.successGreen)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                                } else if let d = item.dischargingWatts {
                                    LineMark(
                                        x: .value("Time", item.timestamp),
                                        y: .value("Watts", d)
                                    )
                                    .foregroundStyle(AppTheme.electricCyan)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .frame(height: 36)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(10)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            } else {
                // Desktop Mac
                desktopPowerCard
            }
        }
    }

    private var desktopPowerCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.electricBlue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("Continuous AC Power")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Desktop Mac without battery constraints")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
            StatusBadge(text: "AC Supply", color: AppTheme.successGreen)
        }
        .padding(10)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }

    private func batteryStateBadgeText(_ b: BatteryMetrics) -> String {
        if b.isFullyCharged { return "Fully Charged" }
        if b.isCharging { return "Charging" }
        if b.isPluggedIn { return "On AC" }
        return "Discharging"
    }

    // MARK: - 3C. Hardware Overview Section (Customizable Mini Dashboard)
    private var hardwareOverviewSection: some View {
        CustomizableWidgetView(
            onNavigateToSection: { section in
                MenuBarCoordinator.shared.openMainWindow(navigatingTo: section)
            },
            onQuickAction: { action in
                handleQuickAction(action)
            }
        )
    }

    private func handleQuickAction(_ action: WidgetQuickActionId) {
        switch action {
        case .openDashboard:
            MenuBarCoordinator.shared.openMainWindow(navigatingTo: .overview)
        case .openSystemMonitor:
            MenuBarCoordinator.shared.openMainWindow(navigatingTo: .cpu)
        case .openBattery:
            MenuBarCoordinator.shared.openMainWindow(navigatingTo: .battery)
        case .openStorage:
            MenuBarCoordinator.shared.openMainWindow(navigatingTo: .storageAnalytics)
        case .openNetwork:
            MenuBarCoordinator.shared.openMainWindow(navigatingTo: .network)
        case .openFocus:
            MenuBarCoordinator.shared.openMainWindow(navigatingTo: .focusPomodoro)
        case .openCleaner:
            MenuBarCoordinator.shared.openMainWindow(navigatingTo: .cleaner)
        case .openSettings:
            MenuBarCoordinator.shared.openMainWindow(navigatingTo: .settings)
        case .refreshMetrics:
            monitor.refreshNow()
        case .quit:
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - 3D. Quick Actions Section
    private var quickActionsSection: some View {
        VStack(spacing: 8) {
            // Clean Cache Shortcut
            Button {
                onQuickCleanup()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.electricBlue)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.electricBlue.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Scan & Clean Cache")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Free up disk space safely")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(8)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Open Sound Preferences
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefPane"))
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.3")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.purpleAccent)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.purpleAccent.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("macOS Sound Settings")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Configure external routing & spatial audio")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(8)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Open Activity Monitor
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.successGreen)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.successGreen.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Activity Monitor")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Inspect running system processes")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(8)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Reusable UI Primitives
    private func compactSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private func deviceSelectionRow(
        devices: [AudioDeviceItem],
        selectedID: AudioDeviceID,
        icon: String,
        onSelect: @escaping (AudioDeviceID) -> Void
    ) -> some View {
        Menu {
            ForEach(devices) { dev in
                Button {
                    onSelect(dev.id)
                } label: {
                    HStack {
                        Text(dev.name)
                        if dev.id == selectedID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(devices.first(where: { $0.id == selectedID })?.name ?? "Select Device")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
        }
        .menuStyle(.borderlessButton)
    }

    private func compactVolumeSlider(
        value: Binding<Float>,
        isMuted: Bool,
        sliderColor: Color = AppTheme.electricBlue,
        muteIcon: String = "speaker.slash.fill",
        onToggleMute: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                onToggleMute()
            } label: {
                Image(systemName: isMuted ? muteIcon : "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(isMuted ? AppTheme.dangerRed : sliderColor)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .help(isMuted ? "Unmute" : "Mute")

            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Float($0) }
                ),
                in: 0.0...1.0
            )
            .tint(sliderColor)

            Text("\(Int(value.wrappedValue * 100))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func miniMetricRow(
        title: String,
        icon: String,
        color: Color,
        value: String,
        progress: Double,
        sparkline: [Double]?
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            if let sparkline = sparkline, sparkline.count > 1 {
                Chart {
                    ForEach(Array(sparkline.suffix(20).enumerated()), id: \.offset) { index, val in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Value", val)
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 14)
            } else {
                GaugeBar(
                    value: progress,
                    gradient: LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                    height: 4
                )
            }
        }
        .padding(8)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }

    // MARK: - 4. Bottom Actions Toolbar
    private var bottomActionToolbar: some View {
        HStack(spacing: 8) {
            Button {
                onOpenDashboard()
            } label: {
                Label("Dashboard", systemImage: "macwindow")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.electricBlue)
            .controlSize(.small)

            Button {
                onQuickCleanup()
            } label: {
                Label("Clean", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textSecondary)
            .help("Settings")

            Button {
                onQuit()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.dangerRed)
            .help("Quit Borno Pulse")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackgroundSecondary)
    }
}
