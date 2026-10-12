//
//  MenuBarPopoverView.swift
//  Borno Pulse
//
//  Premium, compact, native macOS menu bar utility popover.
//  Content-driven adaptive sizing, balanced spacing, and refined macOS aesthetics.
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
    @ObservedObject var widgetPrefs = MenuBarWidgetPreferences.shared
    @ObservedObject var quickActionsRegistry = QuickActionRegistry.shared

    @State private var selectedCategory: MenuBarCategory
    @State private var hasAvailableUpdate: Bool = false
    @State private var updateDismissed: Bool = false

    public var onOpenDashboard: () -> Void
    public var onOpenSettings: () -> Void
    public var onQuickCleanup: () -> Void
    public var onQuit: () -> Void
    public var onCategoryChange: ((MenuBarCategory, CGFloat) -> Void)?

    public init(
        initialCategory: MenuBarCategory = .audio,
        onOpenDashboard: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onQuickCleanup: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {},
        onCategoryChange: ((MenuBarCategory, CGFloat) -> Void)? = nil
    ) {
        self._selectedCategory = State(initialValue: initialCategory)
        self.onOpenDashboard = onOpenDashboard
        self.onOpenSettings = onOpenSettings
        self.onQuickCleanup = onQuickCleanup
        self.onQuit = onQuit
        self.onCategoryChange = onCategoryChange
    }

    // MARK: - Static Height Computation Helpers
    public static func contentHeight(
        for category: MenuBarCategory,
        runningAudioAppsCount: Int = 0,
        hasBattery: Bool = true,
        activeMetricsCount: Int = 5,
        layoutStyle: WidgetLayoutStyle = .balanced
    ) -> CGFloat {
        switch category {
        case .audio:
            // Audio Output card (~102) + spacing (8) + Microphone Input card (~102) = ~212
            // If active media applications exist, add compact media card (~30 header + apps * 30, max 110) + spacing (8)
            if runningAudioAppsCount > 0 {
                let appSectionHeight = CGFloat(28 + min(runningAudioAppsCount, 3) * 28)
                return 218 + appSectionHeight
            } else {
                return 218
            }
        case .battery:
            // Compact battery card: header (24) + gauge bar (4) + details (18) + divider (5) + power rows (38) + trend chart (30) + card padding (18) = ~137
            // plus container padding (20) = ~157
            return hasBattery ? 184 : 76
        case .hardware:
            // Header (22) + metrics + padding (16)
            switch layoutStyle {
            case .compact:
                let rows = (min(activeMetricsCount, 8) + 1) / 2
                return CGFloat(28 + rows * 28 + 16)
            case .balanced:
                return CGFloat(28 + min(activeMetricsCount, 6) * 34 + 16)
            case .detailed:
                return CGFloat(28 + min(activeMetricsCount, 6) * 40 + 16)
            }
        case .quickActions:
            let actionCount = QuickActionRegistry.shared.enabledActionIds.count
            let rows = max(1, (actionCount + 3) / 4)
            return min(360, CGFloat(24 + rows * 72 + 20))
        }
    }

    public static func preferredContentHeight(
        for category: MenuBarCategory,
        hasUpdate: Bool = false,
        runningAudioAppsCount: Int = 0,
        hasBattery: Bool = true,
        activeMetricsCount: Int = 5,
        layoutStyle: WidgetLayoutStyle = .balanced
    ) -> CGFloat {
        let headerHeight: CGFloat = 33
        let updateBannerHeight: CGFloat = hasUpdate ? 28 : 0
        let divider1: CGFloat = 1
        let tabNavHeight: CGFloat = 36
        let divider2: CGFloat = 1
        let contentHeight = contentHeight(
            for: category,
            runningAudioAppsCount: runningAudioAppsCount,
            hasBattery: hasBattery,
            activeMetricsCount: activeMetricsCount,
            layoutStyle: layoutStyle
        )
        let divider3: CGFloat = 1
        let bottomToolbarHeight: CGFloat = 36

        return headerHeight + updateBannerHeight + divider1 + tabNavHeight + divider2 + contentHeight + divider3 + bottomToolbarHeight
    }

    private var currentContentHeight: CGFloat {
        Self.contentHeight(
            for: selectedCategory,
            runningAudioAppsCount: audioService.runningAudioApps.count,
            hasBattery: monitor.snapshot.battery.hasBattery,
            activeMetricsCount: widgetPrefs.activeOrderedMetrics.count,
            layoutStyle: widgetPrefs.layoutStyle
        )
    }

    private func notifyHeightChange(for category: MenuBarCategory) {
        let totalH = Self.preferredContentHeight(
            for: category,
            hasUpdate: hasAvailableUpdate && !updateDismissed,
            runningAudioAppsCount: audioService.runningAudioApps.count,
            hasBattery: monitor.snapshot.battery.hasBattery,
            activeMetricsCount: widgetPrefs.activeOrderedMetrics.count,
            layoutStyle: widgetPrefs.layoutStyle
        )
        onCategoryChange?(category, totalH)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Refined, Native Header
            popoverHeader

            // Optional genuine update notification banner
            if hasAvailableUpdate && !updateDismissed {
                updateNotificationBanner
            }

            Divider().opacity(0.12)

            // 2. Category Navigation Bar
            categoryNavigationBar
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            Divider().opacity(0.10)

            // 3. Category Content Area (Content-driven adaptive height)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
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
                .padding(10)
            }
            .frame(height: min(currentContentHeight, 370))

            Divider().opacity(0.12)

            // 4. Bottom Actions Toolbar
            bottomActionToolbar
        }
        .frame(width: 360)
        .background(AppTheme.elevatedCardBackground)
        .onAppear {
            audioService.refreshAll()
            notifyHeightChange(for: selectedCategory)
        }
    }

    // MARK: - 1. Popover Header
    private var popoverHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.electricBlue)

            Text("Borno Pulse")
                .font(AppTypography.font(size: 11.5, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            // Visually quiet, appropriately sized health badge
            HStack(spacing: 4) {
                Circle()
                    .fill(healthColor(monitor.snapshot.healthScore))
                    .frame(width: 5, height: 5)

                Text(monitor.snapshot.healthStatusText)
                    .font(AppTypography.font(size: 9.5, weight: .medium))
                    .foregroundStyle(healthColor(monitor.snapshot.healthScore))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(healthColor(monitor.snapshot.healthScore).opacity(0.10))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
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
                .font(.system(size: 10.5))
            Text("Update Available")
                .font(AppTypography.font(size: 10.5, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Button {
                updateDismissed = true
                notifyHeightChange(for: selectedCategory)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Dismiss Notification")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(AppTheme.electricBlue.opacity(0.1))
    }

    // MARK: - 2. Category Navigation Bar
    private var categoryNavigationBar: some View {
        HStack(spacing: 3) {
            ForEach(MenuBarCategory.allCases) { category in
                let isSelected = selectedCategory == category
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedCategory = category
                    }
                    notifyHeightChange(for: category)
                } label: {
                    HStack(spacing: 4.5) {
                        Image(systemName: category.icon)
                            .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                            .frame(width: 13, height: 13, alignment: .center)
                            .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textTertiary)

                        Text(category.rawValue)
                            .font(AppTypography.font(size: 10.5, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        isSelected
                            ? Color(nsColor: .controlBackgroundColor).opacity(0.85)
                            : Color.clear
                    )
                    .foregroundStyle(
                        isSelected
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isSelected ? Color.primary.opacity(0.08) : Color.clear, lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(isSelected ? 0.06 : 0), radius: 1, x: 0, y: 0.5)
                }
                .buttonStyle(.plain)
                .help(category.tooltip)
                .accessibilityLabel(category.rawValue)
            }
        }
        .padding(2.5)
        .background(AppTheme.cardBackgroundSecondary.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    // MARK: - 3A. Volume Mixer Section
    private var audioMixerSection: some View {
        VStack(spacing: 8) {
            // Output Device Card
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    compactSectionHeader(title: "Audio Output", icon: "speaker.wave.3.fill", color: AppTheme.electricBlue)
                    Spacer()
                    Text(audioService.isOutputMuted ? "Muted" : "\(Int(audioService.outputVolume * 100))%")
                        .font(AppTypography.monospaced(size: 10, weight: .semibold))
                        .foregroundStyle(audioService.isOutputMuted ? AppTheme.dangerRed : AppTheme.textSecondary)
                }

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
                    sliderColor: AppTheme.electricBlue,
                    muteIcon: "speaker.slash.fill",
                    unmuteIcon: "speaker.wave.2.fill",
                    onToggleMute: { audioService.setOutputMute(!audioService.isOutputMuted) }
                )
            }
            .padding(8.5)
            .background(AppTheme.cardBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))

            // Microphone Input Card
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    compactSectionHeader(title: "Microphone Input", icon: "mic.fill", color: AppTheme.purpleAccent)
                    Spacer()
                    Text(audioService.isInputMuted ? "Muted" : "\(Int(audioService.inputLevel * 100))%")
                        .font(AppTypography.monospaced(size: 10, weight: .semibold))
                        .foregroundStyle(audioService.isInputMuted ? AppTheme.dangerRed : AppTheme.textSecondary)
                }

                deviceSelectionRow(
                    devices: audioService.inputDevices,
                    selectedID: audioService.defaultInputDeviceID,
                    icon: "mic.fill",
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
                    unmuteIcon: "mic.fill",
                    onToggleMute: { audioService.setInputMute(!audioService.isInputMuted) }
                )
            }
            .padding(8.5)
            .background(AppTheme.cardBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))

            // Application Audio Rows (Clean & Compact)
            if !audioService.runningAudioApps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        compactSectionHeader(title: "Application Audio", icon: "app.connected.to.app.below.fill", color: AppTheme.electricCyan)
                        Spacer()
                        Text("\(audioService.runningAudioApps.count) Active")
                            .font(AppTypography.font(size: 9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                    }

                    VStack(spacing: 5) {
                        ForEach(audioService.runningAudioApps) { app in
                            applicationAudioRow(app)
                        }
                    }
                }
                .padding(8.5)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
        }
    }

    private func applicationAudioRow(_ app: RunningAudioAppItem) -> some View {
        HStack(spacing: 7) {
            // App Icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.electricBlue)
                    .frame(width: 16, height: 16)
            }

            // Name
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(AppTypography.font(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(app.name)
                Text(app.routingDescription)
                    .font(AppTypography.font(size: 8.5))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Status Badge
            Text(app.isScriptable ? "Scriptable" : "System Route")
                .font(AppTypography.font(size: 8.5, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
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
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 16, height: 16)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 2)
    }

    // MARK: - 3B. Battery & Power Section
    private var batteryPowerSection: some View {
        VStack(spacing: 8) {
            if monitor.snapshot.battery.hasBattery {
                let b = monitor.snapshot.battery
                let statusColor: Color = {
                    if b.isCharging { return AppTheme.successGreen }
                    if b.percentage <= 10 { return AppTheme.dangerRed }
                    if b.percentage <= 20 { return AppTheme.warningAmber }
                    return AppTheme.textPrimary
                }()

                VStack(alignment: .leading, spacing: 7) {
                    // Header: Level & State Badge
                    HStack(spacing: 8) {
                        Image(systemName: b.isCharging ? "bolt.batteryblock.fill" : (b.isPluggedIn ? "powerplug.fill" : "battery.100"))
                            .font(.system(size: 13))
                            .foregroundStyle(statusColor)

                        Text("Battery")
                            .font(AppTypography.font(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        Spacer()

                        Text("\(b.percentage)%")
                            .font(AppTypography.font(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(batteryStateBadgeText(b))
                            .font(AppTypography.font(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.12))
                            .foregroundStyle(statusColor)
                            .clipShape(Capsule())
                    }

                    // Progress Gauge Bar
                    GaugeBar(
                        value: Double(b.percentage) / 100.0,
                        gradient: LinearGradient(
                            colors: [statusColor, statusColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        height: 3.5
                    )

                    // Remaining Duration & Health
                    HStack(spacing: 6) {
                        Image(systemName: b.isCharging ? "bolt.fill" : (b.isPluggedIn ? "powerplug" : "clock"))
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(b.formattedTimeRemaining)
                            .font(AppTypography.font(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        if let health = b.healthPercentage {
                            Text("Health: \(health)%")
                                .font(AppTypography.font(size: 9.5, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        if let cycles = b.cycleCount {
                            Text("• \(cycles) cycles")
                                .font(AppTypography.font(size: 9.5, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }

                    Divider().opacity(0.12)

                    // Live Electrical Watts Grid
                    VStack(spacing: 3.5) {
                        // Battery Power Row
                        HStack {
                            Text(b.isCharging ? "Charging Power:" : "Discharging Power:")
                                .font(AppTypography.font(size: 10.5))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            if let chargeWatts = b.chargingWatts {
                                Text(String(format: "%.1f W", chargeWatts))
                                    .font(AppTypography.monospaced(size: 10.5, weight: .bold))
                                    .foregroundStyle(chargeWatts > 0.05 ? AppTheme.successGreen : AppTheme.textSecondary)
                            } else if let dischargeWatts = b.dischargingWatts {
                                Text(String(format: "%.1f W", dischargeWatts))
                                    .font(AppTypography.monospaced(size: 10.5, weight: .bold))
                                    .foregroundStyle(AppTheme.electricCyan)
                            } else if b.isPluggedIn {
                                Text("0.0 W (Holding)")
                                    .font(AppTypography.monospaced(size: 10.5, weight: .medium))
                                    .foregroundStyle(AppTheme.textTertiary)
                            } else {
                                Text("Unavailable on this Mac")
                                    .font(AppTypography.font(size: 9.5, weight: .medium))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }

                        // System Power Row
                        if let sysW = b.systemPowerWatts {
                            HStack {
                                Text("System Load:")
                                    .font(AppTypography.font(size: 10.5))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f W", sysW))
                                    .font(AppTypography.monospaced(size: 10.5, weight: .semibold))
                                    .foregroundStyle(AppTheme.purpleAccent)
                            }
                        }

                        // Adapter Rated Power
                        if let rated = b.adapterRatedWatts {
                            HStack {
                                Text("Power Adapter:")
                                    .font(AppTypography.font(size: 10.5))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                                if let inWatts = b.adapterInputWatts {
                                    Text(String(format: "%.1f W / %d W", inWatts, rated))
                                        .font(AppTypography.monospaced(size: 10.5, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                } else {
                                    Text("\(rated) W Rated")
                                        .font(AppTypography.monospaced(size: 10.5, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                        }
                    }

                    // Compact Power Sparkline (Last 5 Minutes)
                    let samples = powerService.samples(for: 300)
                    if samples.count >= 2 {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("Recent Power Trend (W)")
                                .font(AppTypography.font(size: 8.5, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)

                            Chart(samples) { item in
                                if let c = item.chargingWatts {
                                    LineMark(
                                        x: .value("Time", item.timestamp),
                                        y: .value("Watts", c)
                                    )
                                    .foregroundStyle(AppTheme.successGreen)
                                    .lineStyle(StrokeStyle(lineWidth: 1.2))
                                } else if let d = item.dischargingWatts {
                                    LineMark(
                                        x: .value("Time", item.timestamp),
                                        y: .value("Watts", d)
                                    )
                                    .foregroundStyle(AppTheme.electricCyan)
                                    .lineStyle(StrokeStyle(lineWidth: 1.2))
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .frame(height: 28)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(9)
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
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.electricBlue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("Continuous AC Power")
                    .font(AppTypography.font(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Desktop Mac without battery constraints")
                    .font(AppTypography.font(size: 8.5))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
            StatusBadge(text: "AC Supply", color: AppTheme.successGreen)
        }
        .padding(9)
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

    // MARK: - 3D. Quick Actions Section (Responsive Icon Grid)
    private var quickActionsSection: some View {
        QuickActionsGridView(
            onOpenDashboard: onOpenDashboard,
            onQuickCleanup: onQuickCleanup
        )
    }

    // MARK: - Reusable UI Primitives
    private func compactSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10.5))
                .foregroundStyle(color)
            Text(title)
                .font(AppTypography.font(size: 10.5, weight: .semibold))
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
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 14)
                Text(devices.first(where: { $0.id == selectedID })?.name ?? "Select Device")
                    .font(AppTypography.font(size: 10.5, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8.5))
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
        unmuteIcon: String = "speaker.wave.2.fill",
        onToggleMute: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                onToggleMute()
            } label: {
                Image(systemName: isMuted ? muteIcon : unmuteIcon)
                    .font(.system(size: 10.5))
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
                .font(AppTypography.monospaced(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - 4. Bottom Actions Toolbar
    private var bottomActionToolbar: some View {
        HStack(spacing: 8) {
            Button {
                onOpenDashboard()
            } label: {
                Label("Dashboard", systemImage: "macwindow")
                    .font(AppTypography.font(size: 10.5, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentFill)
            .controlSize(.small)

            Button {
                onQuickCleanup()
            } label: {
                Label("Clean", systemImage: "sparkles")
                    .font(AppTypography.font(size: 10.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(AppTheme.subtleFill.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Settings")

            Button {
                onQuit()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.dangerRed)
                    .frame(width: 22, height: 22)
                    .background(AppTheme.dangerRed.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Quit Borno Pulse")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AppTheme.cardBackgroundSecondary)
    }
}
