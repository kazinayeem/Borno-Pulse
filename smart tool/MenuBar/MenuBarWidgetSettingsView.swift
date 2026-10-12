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
    @ObservedObject var quickActionRegistry = QuickActionRegistry.shared
    
    @State private var selectedCategoryTab: WidgetMetricCategory = .cpu
    @State private var metricSearchQuery: String = ""
    @State private var showResetConfirmation: Bool = false
    
    public init() {}
    
    public var body: some View {
        AdaptiveTwoColumnLayout(spacing: 20, rightWidth: 360) {
            // Left Settings Column
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
        } right: {
            // Right Column: Live Widget & Menu Bar Indicator Preview
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
            .smartCard()
        }
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
    
    // MARK: - 1. Menu Bar Status Item (Multi-Metric)
    private var menuBarIndicatorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Menu Bar Status Item", icon: "gauge.with.dots.needle.bottom.100percent", color: AppTheme.electricBlue)

            // Max-visible stepper
            HStack(spacing: 8) {
                Image(systemName: "number.circle.fill")
                    .foregroundStyle(AppTheme.electricBlue)
                    .font(.system(size: 13))
                Text("Max visible metrics")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Stepper("\(settings.menuBarMaxVisible)", value: $settings.menuBarMaxVisible, in: 1...4)
                    .labelsHidden()
                Text("\(settings.menuBarMaxVisible)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.electricBlue)
                    .frame(width: 18)
            }

            Divider().opacity(0.15)

            // Selected metrics (reorderable)
            if settings.menuBarStatusMetrics.isEmpty {
                Text("No metrics selected. Add one below.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(settings.menuBarStatusMetrics.enumerated()), id: \.element.id) { index, metric in
                        HStack(spacing: 8) {
                            // Rank badge
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.textTertiary)
                                .frame(width: 16)

                            Image(systemName: metric.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.electricBlue)
                                .frame(width: 16)

                            Text(metric.displayName)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            // Up
                            Button {
                                settings.moveMenuBarMetric(from: index, to: max(0, index - 1))
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10))
                                    .foregroundStyle(index == 0 ? AppTheme.textTertiary : AppTheme.electricBlue)
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)

                            // Down
                            Button {
                                settings.moveMenuBarMetric(from: index, to: min(settings.menuBarStatusMetrics.count - 1, index + 1))
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(index == settings.menuBarStatusMetrics.count - 1 ? AppTheme.textTertiary : AppTheme.electricBlue)
                            }
                            .buttonStyle(.plain)
                            .disabled(index == settings.menuBarStatusMetrics.count - 1)

                            // Remove
                            Button {
                                settings.removeMenuBarMetric(metric)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.dangerRed.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.cardBackgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }
            }

            Divider().opacity(0.15)

            // Add metrics grid
            let canAdd = settings.menuBarStatusMetrics.count < 4
            Text("Add metric" + (canAdd ? " (\(4 - settings.menuBarStatusMetrics.count) slot(s) free)" : " — maximum 4 reached"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(canAdd ? AppTheme.textSecondary : AppTheme.warningAmber)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(MenuBarStatusMetric.allCases) { metric in
                    let isSelected = settings.menuBarStatusMetrics.contains(metric)
                    let availability = metric.availability(in: monitor.snapshot)
                    Button {
                        if isSelected {
                            settings.removeMenuBarMetric(metric)
                        } else if settings.menuBarStatusMetrics.count < 4 {
                            settings.addMenuBarMetric(metric)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textTertiary)
                            Text(metric.displayName)
                                .font(.system(size: 10))
                                .lineLimit(1)
                            Spacer()
                            if !availability.isAvailable {
                                Text("N/A")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(AppTheme.warningAmber)
                                    .help(availability.displayText)
                            }
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(isSelected ? AppTheme.electricBlue : (canAdd ? AppTheme.matrixGreen : AppTheme.textTertiary))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(isSelected ? AppTheme.electricBlue.opacity(0.12) : AppTheme.cardBackgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .opacity((!isSelected && !canAdd) ? 0.45 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSelected && !canAdd)
                }
            }

            Divider().opacity(0.15)

            // Reset defaults
            Button("Reset to Default Metrics") {
                settings.resetMenuBarMetrics()
            }
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.dangerRed)
            .buttonStyle(.plain)

            Text("Controls what metrics appear simultaneously in your macOS top menu bar.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .smartCard()
    }
    
    // MARK: - Simulated Menu Bar Preview (multi-metric)
    private var simulatedMenuBarPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Menu Bar Status Item Preview")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            let snap = monitor.snapshot
            let metrics = settings.menuBarStatusMetrics
            let maxVisible = settings.menuBarMaxVisible

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // App icon
                    Image(systemName: settings.menuBarIconSymbol.symbolName)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textPrimary)

                    let tokens: [String] = Array(metrics.prefix(max(1, maxVisible))).compactMap {
                        $0.menuBarText(from: snap, temperatureUnit: settings.temperatureUnit, staleAfter: monitor.sensorStaleAfter)
                    }

                    if tokens.isEmpty {
                        // Icon-only or battery-status
                        EmptyView()
                    } else {
                        ForEach(Array(tokens.enumerated()), id: \.offset) { idx, tok in
                            if idx > 0 {
                                Text("|")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            Text(tok)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.subtleFillStrong)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
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
                        .background(AppTheme.selectableFill(preferences.layoutStyle == style))
                        .foregroundStyle(AppTheme.selectableForeground(preferences.layoutStyle == style))
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
                            .background(AppTheme.selectableFill(selectedCategoryTab == cat))
                            .foregroundStyle(AppTheme.selectableForeground(selectedCategoryTab == cat))
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
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Quick System Actions (Widget Grid)", icon: "sparkles", color: AppTheme.purpleAccent)
            
            Text("Customize which tools and shortcuts appear in the menu bar widget's Actions grid, and their display order.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
            
            HStack {
                Button("Restore Default Actions") {
                    quickActionRegistry.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Text("\(quickActionRegistry.enabledActionIds.count) of \(QuickActionId.allCases.count) Active")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            VStack(spacing: 6) {
                ForEach(quickActionRegistry.actionOrder) { id in
                    if let item = quickActionRegistry.action(for: id) {
                        let isEnabled = quickActionRegistry.enabledActionIds.contains(id)
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(isEnabled ? AppTheme.electricBlue : AppTheme.textTertiary)
                                .frame(width: 22)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    if !item.isSupported {
                                        Text("Guide")
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(AppTheme.warningAmber.opacity(0.12))
                                            .foregroundStyle(AppTheme.warningAmber)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(item.description)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Reorder buttons
                            Button {
                                moveQuickAction(id: id, direction: -1)
                            } label: {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(quickActionRegistry.actionOrder.first == id)
                            
                            Button {
                                moveQuickAction(id: id, direction: 1)
                            } label: {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(quickActionRegistry.actionOrder.last == id)
                            
                            Toggle("", isOn: Binding(
                                get: { isEnabled },
                                set: { val in
                                    if val {
                                        if !quickActionRegistry.enabledActionIds.contains(id) {
                                            quickActionRegistry.enabledActionIds.append(id)
                                        }
                                    } else {
                                        quickActionRegistry.enabledActionIds.removeAll { $0 == id }
                                    }
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isEnabled ? AppTheme.cardBackgroundSecondary : AppTheme.cardBackgroundSecondary.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            .frame(maxHeight: 280)
            .clipped()
        }
        .smartCard()
    }

    private func moveQuickAction(id: QuickActionId, direction: Int) {
        guard let idx = quickActionRegistry.actionOrder.firstIndex(of: id) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0 && newIdx < quickActionRegistry.actionOrder.count else { return }
        var updated = quickActionRegistry.actionOrder
        updated.swapAt(idx, newIdx)
        quickActionRegistry.actionOrder = updated
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
                
                // Thermal Alerts (one per component, each using only that component's sensors)
                temperatureAlertRow(
                    title: "Alert on High CPU Temperature",
                    component: .cpu,
                    isEnabled: $alertService.enableCPUTemperatureAlert,
                    threshold: $alertService.cpuTemperatureThresholdCelsius,
                    range: WidgetAlertService.cpuTemperatureThresholdRange
                )
                temperatureAlertRow(
                    title: "Alert on High GPU Temperature",
                    component: .gpu,
                    isEnabled: $alertService.enableGPUTemperatureAlert,
                    threshold: $alertService.gpuTemperatureThresholdCelsius,
                    range: WidgetAlertService.gpuTemperatureThresholdRange
                )
                temperatureAlertRow(
                    title: "Alert on High Battery Temperature",
                    component: .battery,
                    isEnabled: $alertService.enableBatteryTemperatureAlert,
                    threshold: $alertService.batteryTemperatureThresholdCelsius,
                    range: WidgetAlertService.batteryTemperatureThresholdRange
                )
                
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
    @ViewBuilder
    private func temperatureAlertRow(
        title: String,
        component: ThermalComponent,
        isEnabled: Binding<Bool>,
        threshold: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        Toggle(title, isOn: isEnabled)
        if isEnabled.wrappedValue {
            HStack {
                Text("Threshold: \(Formatters.temperature(threshold.wrappedValue, unit: settings.temperatureUnit))")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Slider(value: threshold, in: range, step: 1)
            }
            if case .unavailable(let reason) = monitor.snapshot.sensors.state(for: component) {
                Text("No \(component.displayName) sensor reading on this Mac, so this alert cannot fire. \(reason)")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.warningAmber)
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}
