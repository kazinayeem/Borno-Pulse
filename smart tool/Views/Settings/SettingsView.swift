//
//  SettingsView.swift
//  Borno Pulse
//

import SwiftUI

public enum SettingsSectionTab: String, CaseIterable, Identifiable {
    case appearanceTypography = "Appearance & Typography"
    case menuBarWidget = "Menu Bar & Widget"
    case general = "General & System"
    case clipboard = "Clipboard"
    case alerts = "Alerts & Exclusions"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .appearanceTypography: return "textformat.size"
        case .menuBarWidget: return "gauge.with.dots.needle.bottom.100percent"
        case .general: return "gearshape.fill"
        case .clipboard: return "doc.on.clipboard"
        case .alerts: return "bell.badge.fill"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var navigation = SettingsNavigation.shared
    @State private var selectedTab: SettingsSectionTab = .appearanceTypography
    @State private var newExclusionPath = ""
    @State private var testResults: (passed: Int, failed: Int, logs: [String])? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with Section Tabs
            AdaptivePageHeader(
                title: "Settings & Preferences",
                subtitle: "System appearance, custom typography, widget metrics, alerts, and exclusions",
                icon: "gearshape.fill",
                iconColor: AppTheme.electricBlue
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SettingsSectionTab.allCases) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 11))
                                    Text(tab.rawValue)
                                        .font(AppTypography.font(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.selectableFill(selectedTab == tab))
                                .foregroundStyle(AppTheme.selectableForeground(selectedTab == tab))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(selectedTab == tab ? AppTheme.electricBlue : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            Divider()
            
            // Tab Content
            switch selectedTab {
            case .appearanceTypography:
                appearanceTypographyContent
            case .menuBarWidget:
                MenuBarWidgetSettingsView()
            case .general:
                generalSettingsContent
            case .clipboard:
                ScrollView {
                    ClipboardSettingsView()
                        .padding(20)
                }
            case .alerts:
                alertsSettingsContent
            }
        }
        .background(AppTheme.background)
        .onAppear(perform: applyRequestedTab)
        .onChange(of: navigation.requestedTab) { _, _ in applyRequestedTab() }
    }

    private func applyRequestedTab() {
        guard let tab = navigation.requestedTab else { return }
        selectedTab = tab
        navigation.requestedTab = nil
    }
    
    // MARK: - Appearance & Typography Tab Content
    private var appearanceTypographyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                
                // 1. Appearance Section
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Appearance Mode")
                            .font(AppTypography.font(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Light Mode is the default for new installations. Supports Light, Dark, and System modes with instant live switching.")
                            .font(AppTypography.font(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    AdaptiveCardGrid(minColumnWidth: 160, spacing: 12) {
                        appearanceOptionTile(
                            title: "Light",
                            subtitle: "Crisp neutral white (Default)",
                            icon: "sun.max.fill",
                            mode: .light
                        )
                        appearanceOptionTile(
                            title: "Dark",
                            subtitle: "Deep graphite surfaces",
                            icon: "moon.fill",
                            mode: .dark
                        )
                        appearanceOptionTile(
                            title: "System",
                            subtitle: "Matches macOS appearance",
                            icon: "macbook.and.iphone",
                            mode: .system
                        )
                    }
                }
                .smartCard()
                
                // 2. Primary Typography System
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Primary Font Family")
                                .font(AppTypography.font(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Select application typography. If a selected third-party font is unavailable on your system, Borno Pulse gracefully falls back to native Apple SF Pro.")
                                .font(AppTypography.font(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(AppFontFamily.allCases) { family in
                            let isSelected = settings.appFontFamily == family
                            let isAvailable = family.isAvailableOnSystem
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    settings.appFontFamily = family
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textTertiary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            Text(family.displayName)
                                                .font(AppTypography.font(size: 13, weight: isSelected ? .semibold : .medium))
                                                .foregroundStyle(AppTheme.textPrimary)
                                            
                                            if !isAvailable {
                                                Text("Fallback to SF Pro")
                                                    .font(AppTypography.font(size: 10, weight: .medium))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(AppTheme.warningAmber.opacity(0.12))
                                                    .foregroundStyle(AppTheme.warningAmber)
                                                    .clipShape(Capsule())
                                            } else if family == .sfPro {
                                                Text("Default")
                                                    .font(AppTypography.font(size: 10, weight: .medium))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(AppTheme.electricBlue.opacity(0.12))
                                                    .foregroundStyle(AppTheme.electricBlue)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        
                                        Text(fontFamilyDescription(for: family))
                                            .font(AppTypography.font(size: 11))
                                            .foregroundStyle(AppTheme.textTertiary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Live font sample preview snippet
                                    Text("Aa 123")
                                        .font(sampleFont(for: family, size: 14))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(AppTheme.cardBackgroundSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                .padding(10)
                                .background(isSelected ? AppTheme.electricBlue.opacity(0.08) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .smartCard()
                
                // 3. Font Size Scaling & Base Weight
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Font Size Scaling & Base Weight")
                                .font(AppTypography.font(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Scale text from 85% to 120% without clipping or layout distortion. Respects accessibility scaling.")
                                .font(AppTypography.font(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        
                        Text("\(Int(round(settings.fontScale * 100)))%")
                            .font(AppTypography.monospaced(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.electricBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.electricBlue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    // Slider
                    HStack(spacing: 12) {
                        Text("85%")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                        
                        Slider(value: $settings.fontScale, in: 0.85...1.20, step: 0.05)
                        
                        Text("120%")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    
                    // Quick Preset Buttons
                    HStack(spacing: 8) {
                        fontScalePresetButton(title: "85% (Compact)", scale: 0.85)
                        fontScalePresetButton(title: "100% (Default)", scale: 1.0)
                        fontScalePresetButton(title: "110% (Comfortable)", scale: 1.10)
                        fontScalePresetButton(title: "120% (Large)", scale: 1.20)
                    }
                    
                    Divider().opacity(0.2)
                    
                    // Base Font Weight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base Typography Weight")
                            .font(AppTypography.font(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        HStack(spacing: 8) {
                            ForEach(AppFontWeight.allCases) { weight in
                                let isSelected = settings.baseFontWeight == weight
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        settings.baseFontWeight = weight
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        Text(weight.rawValue)
                                            .font(AppTypography.font(size: 12, weight: weight.fontWeight))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? AppTheme.electricBlue.opacity(0.15) : AppTheme.cardBackgroundSecondary)
                                    .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .smartCard()
                
                // 4. Monospaced Font for Technical Telemetry
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Monospaced Font (Technical Telemetry & Developer Tools)")
                            .font(AppTypography.font(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Applied to CPU metrics, memory allocations, disk bytes, network rates, and cryptographic hashes.")
                            .font(AppTypography.font(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    HStack(spacing: 10) {
                        ForEach(AppMonospacedFontFamily.allCases) { mono in
                            let isSelected = settings.monospacedFontFamily == mono
                            let isAvailable = mono.isAvailableOnSystem
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    settings.monospacedFontFamily = mono
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(mono.rawValue)
                                            .font(AppTypography.font(size: 12, weight: .semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(AppTheme.electricBlue)
                                        }
                                    }
                                    
                                    Text("128.4 MB/s")
                                        .font(monoFontSample(for: mono, size: 12))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    
                                    if !isAvailable {
                                        Text("Fallback Active")
                                            .font(AppTypography.font(size: 9))
                                            .foregroundStyle(AppTheme.warningAmber)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(isSelected ? AppTheme.electricBlue.opacity(0.08) : AppTheme.cardBackgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .smartCard()
                
                // 5. Menu Bar Status Item Symbol Selection
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Menu Bar Status Icon")
                            .font(AppTypography.font(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Monochrome template-style symbol that automatically adapts to light and dark macOS menu bars.")
                            .font(AppTypography.font(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(MenuBarIconSymbol.allCases) { symbol in
                            let isSelected = settings.menuBarIconSymbol == symbol
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    settings.menuBarIconSymbol = symbol
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: symbol.symbolName)
                                        .font(.system(size: 16))
                                        .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textPrimary)
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(symbol.rawValue)
                                            .font(AppTypography.font(size: 11, weight: isSelected ? .semibold : .medium))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        if symbol == .pulseWave {
                                            Text("Borno Motif")
                                                .font(AppTypography.font(size: 9, weight: .medium))
                                                .foregroundStyle(AppTheme.electricCyan)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(AppTheme.electricBlue)
                                    }
                                }
                                .padding(10)
                                .background(isSelected ? AppTheme.electricBlue.opacity(0.10) : AppTheme.cardBackgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .smartCard()
                
                // 6. Live Reactive Typography & Telemetry Preview Studio
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: "eye.fill")
                                    .foregroundStyle(AppTheme.electricBlue)
                                Text("Live Typography & Telemetry Preview")
                                    .font(AppTypography.font(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            Text("Real-time preview responding to active font family, scale factor, and monospaced choices.")
                                .font(AppTypography.font(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation {
                                settings.resetTypographyToDefaults()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset to Defaults")
                            }
                            .font(AppTypography.font(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    // The Live Preview Sandbox Canvas
                    VStack(alignment: .leading, spacing: 12) {
                        // Title Sample
                        HStack {
                            Text("Borno Pulse • Apple M-Series Telemetry")
                                .font(AppTypography.title)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text("Scale: \(Int(round(settings.fontScale * 100)))%")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        
                        // Body Sample
                        Text("High-performance native macOS system monitoring with zero background telemetry leaks, accurate hardware power measurement, and real-time disk analytics.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        // Telemetry Metric Chips (Monospaced)
                        HStack(spacing: 10) {
                            telemetryPreviewChip(label: "CPU", value: "14.8%", color: AppTheme.electricBlue)
                            telemetryPreviewChip(label: "RAM", value: "6.42 GB / 36 GB", color: AppTheme.purpleAccent)
                            telemetryPreviewChip(label: "NET", value: "↓ 84.2 MB/s", color: AppTheme.successGreen)
                            telemetryPreviewChip(
                                label: "CPU TEMP",
                                value: Formatters.temperature(SystemMonitor.shared.snapshot.sensors.cpuTemperature?.celsius, unit: settings.temperatureUnit),
                                color: AppTheme.orangeAccent
                            )
                        }
                        
                        // Developer / Hash Checksum Line
                        HStack(spacing: 8) {
                            Text("SHA-256")
                                .font(AppTypography.monospaced(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
                                .font(AppTypography.monospaced(size: 10))
                                .foregroundStyle(AppTheme.electricCyan)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.cardBackgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .padding(14)
                    .background(AppTheme.cardBackgroundSecondary.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                }
                .smartCard()
            }
            .padding(20)
        }
    }
    
    // MARK: - General Tab Content
    private var generalSettingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                
                // 1. Appearance & Typography Studio Shortcut
                HStack(spacing: 14) {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.electricBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Appearance & Typography Studio")
                            .font(AppTypography.font(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Customize font families (SF Pro, Avenir Next, Inter), font scaling (85%–120%), weights, and menu bar icon.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Button("Customize Typography") {
                        selectedTab = .appearanceTypography
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentFill)
                    .controlSize(.small)
                }
                .smartCard()
                
                // 2. Menu Bar & Widget Studio Shortcut
                HStack(spacing: 14) {
                    Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.electricBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Customizable Menu Bar Widget & Mini Dashboard")
                            .font(AppTypography.font(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Personalize visible metrics, layout style (Compact/Balanced/Detailed), metric order, and menu bar indicators.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Button("Customize Widget") {
                        selectedTab = .menuBarWidget
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .smartCard()
                
                // 3. General & Integration
                VStack(alignment: .leading, spacing: 14) {
                    Text("General & Integration")
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    LaunchAtLoginToggle(title: "Launch at Login (ServiceManagement)")
                    
                    Divider().opacity(0.2)

                    // Multi-metric menu bar status item preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Menu Bar Metrics")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        let snap = SystemMonitor.shared.snapshot
                        let tokens = settings.menuBarStatusMetrics.prefix(settings.menuBarMaxVisible)
                            .compactMap {
                                $0.menuBarText(from: snap, temperatureUnit: settings.temperatureUnit, staleAfter: SystemMonitor.shared.sensorStaleAfter)
                            }

                        if tokens.isEmpty {
                            Text("Icon only")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(AppTheme.textTertiary)
                        } else {
                            Text(tokens.joined(separator: "  |  "))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        Text("Configure in Menu Bar & Widget Studio")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.electricBlue)
                    }
                }
                .smartCard()
                
                // 4. Telemetry Refresh & Units
                VStack(alignment: .leading, spacing: 14) {
                    Text("Telemetry Refresh & Units")
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Picker("Telemetry Polling Interval", selection: $settings.refreshIntervalSeconds) {
                        Text("0.5 Seconds (High Fidelity)").tag(0.5)
                        Text("1.0 Second (Default Standard)").tag(1.0)
                        Text("2.0 Seconds (Balanced Power)").tag(2.0)
                        Text("5.0 Seconds (Maximum Energy Saving)").tag(5.0)
                    }
                    
                    Picker("Temperature Unit", selection: $settings.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Read Hardware Temperature & Fan Sensors", isOn: $settings.hardwareSensorAccessEnabled)
                        Text("Reads the SMC and IOHID thermal sensors through undocumented macOS interfaces. They are unavailable to sandboxed (Mac App Store) builds and may change in future macOS releases. When off, only the system thermal state and battery registry data are shown.")
                            .font(AppTypography.font(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    
                    Picker("Graph Historical Buffer", selection: $settings.historyDurationPoints) {
                        Text("30 Data Points").tag(30)
                        Text("60 Data Points (Default)").tag(60)
                        Text("120 Data Points").tag(120)
                    }
                }
                .smartCard()
                
                // 5. Unit Tests & Diagnostics
                unitTestRunnerCard
                
                // 6. About & Licenses
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.electricBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Borno Pulse")
                                .font(AppTypography.font(size: 15, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Smart Mac Utilities & System Monitor • Version 1.0.0 (Build 1)")
                                .font(AppTypography.font(size: 11))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    
                    Text("Your Mac. Fully Understood.\nEngineered with 100% native Swift 6, SwiftUI, Charts, Metal, and Darwin APIs. Built for Apple Silicon and Intel architecture Macs.")
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Text("Open Source Compatible • Zero Telemetry • Ad-Free")
                        .font(AppTypography.font(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.electricCyan)
                }
                .smartCard()
            }
            .padding(20)
        }
    }
    
    // MARK: - Alerts & Exclusions Tab Content
    private var alertsSettingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Alerts & Notification Thresholds
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Alerts & Notification Thresholds")
                                .font(AppTypography.font(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Receive native macOS notifications when system resources cross defined limits.")
                                .font(AppTypography.font(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Alert on High CPU Load", isOn: $settings.notifyHighCPU)
                        if settings.notifyHighCPU {
                            HStack {
                                Text("Threshold: \(Int(settings.cpuAlertThreshold))%")
                                    .font(AppTypography.font(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Slider(value: $settings.cpuAlertThreshold, in: 50...99, step: 1)
                            }
                        }
                    }
                    
                    Divider().opacity(0.15)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Alert on High Memory Pressure", isOn: $settings.notifyHighMemory)
                        if settings.notifyHighMemory {
                            HStack {
                                Text("Threshold: \(Int(settings.memoryAlertThreshold))%")
                                    .font(AppTypography.font(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Slider(value: $settings.memoryAlertThreshold, in: 60...99, step: 1)
                            }
                        }
                    }
                    
                    Divider().opacity(0.15)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Alert on Low Battery", isOn: $settings.notifyLowBattery)
                        if settings.notifyLowBattery {
                            HStack {
                                Text("Threshold: \(settings.batteryAlertThreshold)%")
                                    .font(AppTypography.font(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Slider(value: Binding(
                                    get: { Double(settings.batteryAlertThreshold) },
                                    set: { settings.batteryAlertThreshold = Int($0) }
                                ), in: 5...40, step: 1)
                            }
                        }
                    }
                }
                .smartCard()
                
                // 2. Widget Specific Threshold Alerts Shortcut
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Menu Bar Widget Alerts & Cooldowns")
                                .font(AppTypography.font(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Configure high temperature, low disk space, and network disconnect alerts in the widget studio.")
                                .font(AppTypography.font(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Button("Configure in Widget Studio") {
                            selectedTab = .menuBarWidget
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .smartCard()
                
                // 3. Cache Cleaner Exclusions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cache Cleaner Exclusions")
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("Folders and files specified here will never be touched by the cache cleaner.")
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    HStack {
                        TextField("e.g. ~/Library/Caches/com.myimportantapp", text: $newExclusionPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            if !newExclusionPath.isEmpty {
                                var current = settings.cleanupExclusions
                                current.append(newExclusionPath)
                                settings.cleanupExclusions = current
                                newExclusionPath = ""
                            }
                        }
                    }
                    
                    if !settings.cleanupExclusions.isEmpty {
                        ForEach(settings.cleanupExclusions, id: \.self) { path in
                            HStack {
                                Text(path)
                                    .font(AppTypography.font(size: 12))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Button {
                                    settings.cleanupExclusions.removeAll { $0 == path }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(AppTheme.dangerRed)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(6)
                            .background(AppTheme.cardBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                        }
                    }
                }
                .smartCard()
            }
            .padding(20)
        }
    }
    
    // MARK: - Helper Views & Builders
    private func appearanceOptionTile(title: String, subtitle: String, icon: String, mode: AppAppearanceMode) -> some View {
        let isSelected = settings.appearanceMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.appearanceMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textSecondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.electricBlue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.font(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AppTheme.electricBlue.opacity(0.08) : AppTheme.cardBackgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func fontScalePresetButton(title: String, scale: Double) -> some View {
        let isSelected = abs(settings.fontScale - scale) < 0.01
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.fontScale = scale
            }
        } label: {
            Text(title)
                .font(AppTypography.font(size: 11, weight: isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(isSelected ? AppTheme.electricBlue.opacity(0.15) : AppTheme.cardBackgroundSecondary)
                .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func telemetryPreviewChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTypography.font(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(AppTypography.monospaced(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
    }
    
    private func fontFamilyDescription(for family: AppFontFamily) -> String {
        switch family {
        case .sfPro:
            return "Native Apple system typography. Perfectly tuned for macOS."
        case .avenirNext:
            return "Geometric sans-serif with modern, open letterforms."
        case .helveticaNeue:
            return "Classic Swiss modernist neutral typography with crisp geometry."
        case .inter:
            return "Crafted specifically for computer screens and high UI readability."
        case .sfMono:
            return "Apple developer monospaced font applied across all user interface elements."
        }
    }
    
    private func sampleFont(for family: AppFontFamily, size: CGFloat) -> Font {
        if let ps = family.postScriptName, family.isAvailableOnSystem {
            return Font.custom(ps, size: size)
        }
        return Font.system(size: size)
    }
    
    private func monoFontSample(for mono: AppMonospacedFontFamily, size: CGFloat) -> Font {
        if let ps = mono.postScriptName, mono.isAvailableOnSystem {
            return Font.custom(ps, size: size)
        }
        return Font.system(size: size, design: .monospaced)
    }
    
    private var unitTestRunnerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Built-in Diagnostic & Unit Test Suite", systemImage: "checkmark.seal.fill")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.successGreen)
                Spacer()
                Button("Run Test Suite") {
                    testResults = SmartToolTests.runAllTests()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
                .controlSize(.small)
            }
            
            Text("Executes self-diagnostic unit tests verifying metric calculation bounds, mock providers, Intel/Apple Silicon handling, APFS purgeable algorithms, cleaner safety rules, and typography customization invariants.")
                .font(AppTypography.font(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
            
            if let res = testResults {
                HStack(spacing: 12) {
                    StatusBadge(text: "\(res.passed) Passed", color: AppTheme.successGreen)
                    if res.failed > 0 {
                        StatusBadge(text: "\(res.failed) Failed", color: AppTheme.dangerRed)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(res.logs, id: \.self) { log in
                        Text(log)
                            .font(AppTypography.monospaced(size: 10))
                            .foregroundStyle(log.contains("PASS") ? AppTheme.successGreen : AppTheme.dangerRed)
                    }
                }
                .padding(8)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
        }
        .smartCard()
    }
}
