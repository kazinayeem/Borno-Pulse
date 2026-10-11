//
//  SettingsView.swift
//  Naem Smart Tool
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var newExclusionPath = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings & Preferences")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Customize monitoring behavior, appearance, and alerts")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // General & System
                VStack(alignment: .leading, spacing: 14) {
                    Text("General & Integration")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Toggle("Launch at Login (ServiceManagement)", isOn: $settings.launchAtLogin)
                        .onChange(of: settings.launchAtLogin) { _, newValue in
                            LaunchAtLoginService.shared.setEnabled(newValue)
                        }
                    
                    Picker("Menu Bar Display Metric", selection: $settings.menuBarDisplay) {
                        ForEach(MenuBarMetricDisplay.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    Picker("Appearance Mode", selection: $settings.appearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                .smartCard()
                
                // Monitoring Engine
                VStack(alignment: .leading, spacing: 14) {
                    Text("Telemetry Refresh & Units")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
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
                    
                    Picker("Graph Historical Buffer", selection: $settings.historyDurationPoints) {
                        Text("30 Data Points").tag(30)
                        Text("60 Data Points (Default)").tag(60)
                        Text("120 Data Points").tag(120)
                    }
                }
                .smartCard()
                
                // Notification Thresholds
                VStack(alignment: .leading, spacing: 14) {
                    Text("Alerts & Notification Thresholds")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Alert on High CPU Load", isOn: $settings.notifyHighCPU)
                        if settings.notifyHighCPU {
                            HStack {
                                Text("Threshold: \(Int(settings.cpuAlertThreshold))%")
                                    .font(.system(size: 12))
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
                                    .font(.system(size: 12))
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
                                    .font(.system(size: 12))
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
                
                // Cleanup Exclusions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cache Cleaner Exclusions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Text("Folders and files specified here will never be touched by the cache cleaner.")
                        .font(.system(size: 11))
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
                                    .font(.system(size: 12))
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
                            .background(Color.white.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
                .smartCard()
                
                // Unit Tests & Quality Verification
                unitTestRunnerCard
                
                // About & Licenses
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.electricBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Naem Smart Tool")
                                .font(.system(size: 15, weight: .bold))
                            Text("Version 1.0.0 (Build 1)")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    
                    Text("Your Mac. Fully Understood.\nEngineered with 100% native Swift 6, SwiftUI, Charts, Metal, and Darwin APIs. Built for Apple Silicon and Intel architecture Macs.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Text("Open Source Compatible • Zero Telemetry • Ad-Free")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.electricCyan)
                }
                .smartCard()
            }
            .padding(20)
        }
    }
    
    @State private var testResults: (passed: Int, failed: Int, logs: [String])? = nil
    
    private var unitTestRunnerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Built-in Diagnostic & Unit Test Suite", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.successGreen)
                Spacer()
                Button("Run Test Suite") {
                    testResults = SmartToolTests.runAllTests()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.electricBlue)
                .controlSize(.small)
            }
            
            Text("Executes self-diagnostic unit tests verifying metric calculation bounds, mock providers, Intel/Apple Silicon handling, APFS purgeable algorithms, and cleaner safety rules.")
                .font(.system(size: 11))
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
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(log.contains("PASS") ? AppTheme.successGreen : AppTheme.dangerRed)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .smartCard()
    }
}

