//
//  MenuBarWidgetSettingsView.swift
//  Borno Pulse
//
//  Dedicated configuration studio for the customizable menu bar widget,
//  metric selection, ordering, layout style, indicator preview, and alert thresholds.
//

import AppKit
import SwiftUI

public struct MenuBarWidgetSettingsView: View {
    @ObservedObject var preferences = MenuBarWidgetPreferences.shared
    @ObservedObject var alertService = WidgetAlertService.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var monitor = SystemMonitor.shared
    
    @State private var selectedCategoryTab: WidgetMetricCategory = .cpu
    @State private var metricSearchQuery: String = ""
    @State private var showResetConfirmation: Bool = false
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Left Settings Column
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    settingsHeader
                    
                    // 1. Menu Bar Status Indicator
                    menuBarIndicatorSection
                    
                    // 2. Widget Layout & Appearance
                    layoutStyleSection
                    
                    // 3. Metric Selection by Category
                    metricSelectionSection
                    
                    // 4. Metric Ordering
                    metricOrderingSection
                    
                    // 5. Monitored Storage Volume
                    storageVolumeSection
                    
                    // 6. Quick Action Shortcuts
                    quickActionsSection
                    
                    // 7. Refresh Rate & Performance
                    refreshRateSection
                    
                    // 8. Alerts & Thresholds
                    alertThresholdsSection
                    
                    // Reset Button
                    resetDefaultsBar
                }
                .padding(20)
            }
            .frame(minWidth: 500)
            
            // Right Column: Live Widget & Menu Bar Indicator Preview
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundStyle(AppTheme.electricBlue)
                        Text("Live Widget Preview")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("Real Time")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.matrixGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.matrixGreen.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    // Live Menu Bar Simulated Preview
                    simulatedMenuBarPreview
                    
                    Divider().opacity(0.15)
                    
                    // Live Interactive Popover Widget Preview
                    CustomizableWidgetView(
                        onNavigateToSection: { _ in },
                        onQuickAction: { _ in }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                    
                    Text("This preview reflects your active metric choices, layout style, spacing, and quick actions immediately.")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .frame(minWidth: 320, maxWidth: 380)
            .background(AppTheme.sidebarBackground)
        }
        .background(AppTheme.background)
        .alert("Reset Widget Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset to Defaults", role: .destructive) {
                preferences.resetToDefaults()
            }
        } message: {
            Text("This will restore default metric selections, balanced layout, and shortcuts. Your monitoring history and other settings will remain unchanged.")
        }
    }
    
    // MARK: - Header
    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Menu Bar & Widget Studio")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Customize visible metrics, layout density, status item indicators, and threshold alerts")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
    
    // MARK: - 1. Menu Bar Indicator Section
    private var menuBarIndicatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Menu Bar Status Item", icon: "gauge.with.dots.needle.bottom.100percent", color: AppTheme.electricBlue)
            
            Picker("Display Mode", selection: $settings.menuBarDisplay) {
                ForEach(MenuBarMetricDisplay.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            
            Text("Controls what appears directly in your macOS top menu bar status item.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .smartCard()
    }
    
    // MARK: - Simulated Menu Bar Item Preview
    private var simulatedMenuBarPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Menu Bar Status Item Preview")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            
            HStack(spacing: 6) {
                Image(systemName: iconForMenuBarMode(settings.menuBarDisplay))
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textPrimary)
                
                let text = textForMenuBarMode(settings.menuBarDisplay)
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 0.5))
        }
    }
    
    // MARK: - 2. Layout Style Section
    private var layoutStyleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Widget Layout & Density", icon: "square.grid.2x2", color: AppTheme.electricCyan)
            
            HStack(spacing: 10) {
                ForEach(WidgetLayoutStyle.allCases) { style in
                    Button {
                        preferences.layoutStyle = style
                    } label: {
                        VStack(spacing: 4) {
                            Text(style.rawValue)
                                .font(.system(size: 12, weight: .bold))
                            Text(style.description)
                                .font(.system(size: 9))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(8)
                        .background(preferences.layoutStyle == style ? AppTheme.electricBlue.opacity(0.18) : Color.white.opacity(0.04))
                        .foregroundStyle(preferences.layoutStyle == style ? AppTheme.electricBlue : AppTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(preferences.layoutStyle == style ? AppTheme.electricBlue : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider().opacity(0.15)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                Toggle("Compact Spacing", isOn: $preferences.compactSpacing)
                Toggle("Show Category Icons", isOn: $preferences.showIcons)
                Toggle("Show Metric Labels", isOn: $preferences.showLabels)
                Toggle("Show Progress Bars", isOn: $preferences.showProgressBars)
                Toggle("Show Trend Sparklines", isOn: $preferences.showTrendCharts)
                Toggle("Display Percentages", isOn: $preferences.usePercentages)
            }
            .font(.system(size: 11))
            
            HStack {
                Text("Max Visible Metric Rows: \(preferences.maxVisibleRows)")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Stepper("", value: $preferences.maxVisibleRows, in: 4...25)
            }
        }
        .smartCard()
    }
    
    // MARK: - 3. Metric Selection Section
    private var metricSelectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Select Visible Metrics", icon: "checklist", color: AppTheme.matrixGreen)
            
            // Category Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(WidgetMetricCategory.allCases) { cat in
                        Button {
                            selectedCategoryTab = cat
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedCategoryTab == cat ? AppTheme.electricBlue.opacity(0.18) : Color.white.opacity(0.04))
                            .foregroundStyle(selectedCategoryTab == cat ? AppTheme.electricBlue : AppTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider().opacity(0.15)
            
            // Metrics in selected category
            let categoryMetrics = WidgetMetricId.allCases.filter { $0.category == selectedCategoryTab }
            
            VStack(spacing: 8) {
                ForEach(categoryMetrics) { metric in
                    let isEnabled = preferences.isMetricEnabled(metric)
                    let extracted = preferences.extract(metric: metric, from: monitor.snapshot)
                    
                    HStack(spacing: 10) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(isEnabled ? AppTheme.electricBlue : AppTheme.textTertiary)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            if let note = extracted.availabilityNote {
                                Text(note)
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.warningAmber)
                            } else {
                                Text("Sample: \(extracted.formattedValue)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { isEnabled },
                            set: { preferences.setMetricEnabled(metric, enabled: $0) }
                        ))
                        .labelsHidden()
                    }
                    .padding(8)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .smartCard()
    }
    
    // MARK: - 4. Metric Ordering Section
    private var metricOrderingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Metric Display Order", icon: "arrow.up.arrow.down", color: AppTheme.orangeAccent)
            
            Text("Metrics appear in this sequence inside the widget. Use the buttons to adjust priority.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
            
            let active = preferences.activeOrderedMetrics
            
            VStack(spacing: 4) {
                ForEach(Array(active.enumerated()), id: \.element.id) { index, metric in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(width: 18)
                        
                        Image(systemName: metric.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.electricBlue)
                            .frame(width: 14)
                        
                        Text(metric.title)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Spacer()
                        
                        Button {
                            preferences.moveMetric(fromIndex: index, toIndex: max(0, index - 1))
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(index == 0)
                        
                        Button {
                            preferences.moveMetric(fromIndex: index, toIndex: min(active.count - 1, index + 1))
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(index == active.count - 1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .smartCard()
    }
    
    // MARK: - 5. Monitored Storage Volume
    private var storageVolumeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Monitored Storage Volume", icon: "internaldrive", color: AppTheme.warningAmber)
            
            Picker("Volume for Storage Metrics", selection: $preferences.selectedVolumePath) {
                ForEach(monitor.snapshot.storage.volumes) { vol in
                    Text("\(vol.name) (\(vol.mountPoint)) — \(Formatters.bytes(vol.freeBytes)) Free").tag(vol.mountPoint)
                }
            }
            .pickerStyle(.menu)
        }
        .smartCard()
    }
    
    // MARK: - 6. Quick Action Shortcuts Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Widget Footer Shortcuts", icon: "sparkles", color: AppTheme.purpleAccent)
            
            Text("Select which utility buttons appear at the bottom of the popover widget.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(WidgetQuickActionId.allCases) { action in
                    let isEnabled = preferences.enabledQuickActions.contains(action)
                    Button {
                        if isEnabled {
                            preferences.enabledQuickActions.removeAll { $0 == action }
                        } else {
                            preferences.enabledQuickActions.append(action)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(isEnabled ? AppTheme.electricBlue : AppTheme.textTertiary)
                            Text(action.title)
                                .font(.system(size: 11))
                            Spacer()
                            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(isEnabled ? AppTheme.electricBlue : Color.gray.opacity(0.4))
                        }
                        .padding(8)
                        .background(isEnabled ? AppTheme.electricBlue.opacity(0.12) : AppTheme.cardBackgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .smartCard()
    }
    
    // MARK: - 7. Refresh Rate & Performance
    private var refreshRateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Refresh Interval & Power Optimization", icon: "bolt.badge.clock.fill", color: AppTheme.electricBlue)
            
            Picker("Refresh Frequency", selection: $settings.refreshIntervalSeconds) {
                Text("0.5 Seconds (High Fidelity)").tag(0.5)
                Text("1.0 Second (Default Balanced)").tag(1.0)
                Text("2.0 Seconds (Energy Saving)").tag(2.0)
                Text("5.0 Seconds (Maximum Battery Life)").tag(5.0)
            }
            .pickerStyle(.menu)
            
            Text("Higher sampling intervals reduce system polling load and extend MacBook battery duration.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .smartCard()
    }
    
    // MARK: - 8. Alerts & Thresholds Section
    private var alertThresholdsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Real Metric Alerts & Cooldown", icon: "bell.badge.fill", color: AppTheme.dangerRed)
            
            VStack(alignment: .leading, spacing: 10) {
                // CPU Alert
                Toggle("Alert on High CPU Load", isOn: $alertService.enableCPUAlert)
                if alertService.enableCPUAlert {
                    HStack {
                        Text("Threshold: \(Int(alertService.cpuThreshold))%")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                        Slider(value: $alertService.cpuThreshold, in: 50...99, step: 1)
                    }
                }
                
                Divider().opacity(0.15)
                
                // Memory Alert
                Toggle("Alert on High Memory Pressure", isOn: $alertService.enableMemoryAlert)
                if alertService.enableMemoryAlert {
                    HStack {
                        Text("Threshold: \(Int(alertService.memoryThreshold))%")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                        Slider(value: $alertService.memoryThreshold, in: 60...99, step: 1)
                    }
                }
                
                Divider().opacity(0.15)
                
                // Disk Alert
                Toggle("Alert on Low Disk Space", isOn: $alertService.enableDiskAlert)
                if alertService.enableDiskAlert {
                    HStack {
                        Text("Threshold: \(Int(alertService.diskThresholdGB)) GB free")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                        Slider(value: $alertService.diskThresholdGB, in: 5...80, step: 1)
                    }
                }
                
                Divider().opacity(0.15)
                
                // Battery Alert
                Toggle("Alert on Low Battery", isOn: $alertService.enableBatteryAlert)
                if alertService.enableBatteryAlert {
                    HStack {
                        Text("Threshold: \(alertService.batteryThresholdPercent)%")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                        Slider(value: Binding(
                            get: { Double(alertService.batteryThresholdPercent) },
                            set: { alertService.batteryThresholdPercent = Int($0) }
                        ), in: 5...40, step: 1)
                    }
                }
                
                Divider().opacity(0.15)
                
                // Thermal Alert
                Toggle("Alert on High Temperature (When Measured)", isOn: $alertService.enableTemperatureAlert)
                if alertService.enableTemperatureAlert {
                    HStack {
                        Text("Threshold: \(Int(alertService.temperatureThresholdCelsius)) °C")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                        Slider(value: $alertService.temperatureThresholdCelsius, in: 70...100, step: 1)
                    }
                }
                
                Divider().opacity(0.15)
                
                // Network Alert
                Toggle("Alert when All Network Interfaces Disconnect", isOn: $alertService.enableNetworkDisconnectAlert)
            }
            .font(.system(size: 11))
            
            Text("Alerts enforce a strict 5-minute cooldown per trigger to prevent notification fatigue.")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .smartCard()
    }
    
    // MARK: - Reset Bar
    private var resetDefaultsBar: some View {
        HStack {
            Spacer()
            Button("Reset Widget Preferences to Defaults") {
                showResetConfirmation = true
            }
            .foregroundStyle(AppTheme.dangerRed)
            .controlSize(.small)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Helper Views
    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
    
    private func iconForMenuBarMode(_ mode: MenuBarMetricDisplay) -> String {
        switch mode {
        case .iconOnly: return "gauge.with.dots.needle.bottom.100percent"
        case .cpuPercentage: return "cpu"
        case .memoryPercentage: return "memorychip"
        case .networkSpeed: return "arrow.down"
        case .cpuAndMemory, .cpuAndNetwork: return "gauge.with.dots.needle.bottom.100percent"
        case .batteryPercentage, .batteryPercentAndTime: return "battery.100.bolt"
        case .batteryTimeRemaining: return "clock"
        case .batteryWatts: return "bolt.fill"
        case .batteryStatus: return "battery.100"
        }
    }
    
    private func textForMenuBarMode(_ mode: MenuBarMetricDisplay) -> String {
        let snap = monitor.snapshot
        switch mode {
        case .iconOnly: return ""
        case .cpuPercentage: return String(format: "%.0f%%", snap.cpu.totalUsage)
        case .memoryPercentage: return String(format: "%.0f%%", snap.memory.usagePercentage)
        case .networkSpeed: return Formatters.speed(snap.network.downloadSpeedBytesPerSec)
        case .cpuAndMemory: return String(format: "CPU: %.0f%% | RAM: %.0f%%", snap.cpu.totalUsage, snap.memory.usagePercentage)
        case .cpuAndNetwork: return String(format: "%.0f%% | %@", snap.cpu.totalUsage, Formatters.speed(snap.network.downloadSpeedBytesPerSec))
        case .batteryPercentage: return snap.battery.hasBattery ? "\(snap.battery.percentage)%" : "AC"
        case .batteryTimeRemaining: return snap.battery.hasBattery ? snap.battery.formattedTimeRemaining : "AC Power"
        case .batteryPercentAndTime: return snap.battery.hasBattery ? "\(snap.battery.percentage)% (\(snap.battery.formattedTimeRemaining))" : "100% (AC)"
        case .batteryWatts:
            if let w = snap.battery.chargingWatts ?? snap.battery.dischargingWatts {
                return String(format: "%.1fW", w)
            }
            return "0.0W"
        case .batteryStatus: return ""
        }
    }
}
