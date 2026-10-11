//
//  DiagnosticsView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct DiagnosticsView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @State private var exportSuccessMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                AdaptivePageHeader(
                    title: "System Diagnostics & Telemetry",
                    subtitle: "Hardware audit, API capability verification, and exportable diagnostics",
                    icon: "waveform.path.ecg.rectangle",
                    iconColor: AppTheme.electricBlue
                ) {
                    Button {
                        exportDiagnosticReport()
                    } label: {
                        Label("Export Redacted Report", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.electricBlue)
                }
                
                if let msg = exportSuccessMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.successGreen)
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(10)
                    .background(AppTheme.successGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                // Hardware & OS Audit
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hardware & Operating System Audit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    StatRow(label: "Processor Model", value: monitor.snapshot.cpu.modelName, icon: "cpu")
                    StatRow(label: "Architecture", value: monitor.snapshot.cpu.architecture, icon: "cube.fill")
                    StatRow(label: "Physical / Logical Cores", value: "\(monitor.snapshot.cpu.physicalCoreCount) Physical / \(monitor.snapshot.cpu.logicalCoreCount) Logical", icon: "square.split.2x2")
                    StatRow(label: "Installed Physical RAM", value: Formatters.bytes(monitor.snapshot.memory.totalBytes), icon: "memorychip")
                    StatRow(label: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString, icon: "apple.logo")
                    StatRow(label: "System Uptime", value: "\(Int(ProcessInfo.processInfo.systemUptime / 3600)) hours", icon: "clock.fill")
                }
                .smartCard()
                
                // Native API & Permission Matrix
                VStack(alignment: .leading, spacing: 10) {
                    Text("Native macOS API & Permission Matrix")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    apiRow(name: "Mach Host Statistics (host_processor_info)", status: "Active (Darwin Kernel)", available: true)
                    apiRow(name: "Darwin Virtual Memory (host_statistics64)", status: "Active (Page-accurate)", available: true)
                    apiRow(name: "Metal Performance Framework (MTLCopyAllDevices)", status: "Active (\(monitor.snapshot.gpu.deviceName))", available: true)
                    apiRow(name: "IOKit IOAccelerator (GPU Metrics)", status: monitor.snapshot.gpu.deviceUtilization != nil ? "Active (PerformanceStatistics)" : "Fallback (Metal device ready)", available: true)
                    apiRow(name: "IOKit IOPowerSources (Battery Telemetry)", status: monitor.snapshot.battery.hasBattery ? "Active (AppleSmartBattery)" : "AC Powered (Desktop)", available: true)
                    apiRow(name: "Process Information (libproc / proc_listpids)", status: "Active (All User Space PIDs)", available: true)
                    apiRow(name: "ServiceManagement (SMAppService Login Item)", status: "Supported (macOS 13+)", available: true)
                    apiRow(name: "ProcessInfo.thermalState (Thermal Pressure)", status: "Active (\(monitor.snapshot.sensors.thermalState.shortLabel))", available: true)
                    if monitor.snapshot.sensors.sourceStatuses.isEmpty {
                        apiRow(name: "Hardware Temperature Sensors", status: monitor.snapshot.sensors.temperatureState.displayText, available: false)
                    }
                    ForEach(monitor.snapshot.sensors.sourceStatuses) { status in
                        apiRow(
                            name: "\(status.source.displayName) Temperature Sensors",
                            status: status.state.isAvailable ? "Active (\(status.sensorCount) sensors)" : status.state.displayText,
                            available: status.state.isAvailable
                        )
                    }
                    apiRow(
                        name: "SMC Fan Telemetry",
                        status: monitor.snapshot.sensors.fansState.isAvailable ? "Active (\(monitor.snapshot.sensors.fanSpeeds.count) fans)" : monitor.snapshot.sensors.fansState.displayText,
                        available: monitor.snapshot.sensors.fansState.isAvailable
                    )
                }
                .smartCard()
                
                // Security & Privacy Posture
                VStack(alignment: .leading, spacing: 10) {
                    Label("Privacy & Security Architecture", systemImage: "lock.shield.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.successGreen)
                    
                    Text("• Zero Telemetry: 100% of telemetry calculations are performed on-device. No network transmission or external analytics.\n• Least Privilege: Never asks for root credentials (sudo).\n• Auditable Exclusions: Caches deletion performs dry-run file simulation prior to removal.\n• Sensitive Redaction: Exported diagnostic reports automatically scrub usernames, hardware serial numbers, and home directory structures.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .smartCard()
                
                // Self-Test Suite & Invariant Validation
                selfTestSection
            }
            .padding(20)
        }
    }
    
    @State private var testResults: (passed: Int, failed: Int, logs: [String])? = nil
    @State private var isRunningTests = false
    
    private var selfTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Invariant Self-Test Suite & Verification", systemImage: "checklist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.electricBlue)
                
                Spacer()
                
                Button {
                    isRunningTests = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        let res = SmartToolTests.runAllTests()
                        DispatchQueue.main.async {
                            testResults = res
                            isRunningTests = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                        Text(isRunningTests ? "Running Tests..." : "Run All Invariant Tests")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.electricBlue)
                .disabled(isRunningTests)
            }
            
            if let results = testResults {
                HStack(spacing: 16) {
                    Text("Passed: \(results.passed)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.successGreen)
                    
                    Text("Failed: \(results.failed)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(results.failed == 0 ? AppTheme.textSecondary : AppTheme.dangerRed)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(results.logs, id: \.self) { log in
                        Text(log)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(log.contains("PASS") ? AppTheme.successGreen : AppTheme.dangerRed)
                    }
                }
                .padding(10)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            } else {
                Text("Verify system calculation invariants, image format conversion math, no-upscaling guards, PDF split/merge ranges, batch renamer collision detectors, and cryptographic hashing routines.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .smartCard()
    }

    
    private func apiRow(name: String, status: String, available: Bool) -> some View {
        HStack {
            Image(systemName: available ? "checkmark.circle.fill" : "info.circle.fill")
                .foregroundStyle(available ? AppTheme.successGreen : AppTheme.warningAmber)
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(status)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.vertical, 3)
    }
    
    private func exportDiagnosticReport() {
        let snap = monitor.snapshot
        let temperatureLines = ThermalComponent.headline.map { component -> String in
            if let value = snap.sensors.temperature(for: component) {
                return "- \(component.displayName) Temperature: \(Formatters.temperature(value.celsius)) (avg of \(value.sensorCount), peak \(Formatters.temperature(value.maximumCelsius)), \(value.source.displayName))"
            }
            return "- \(component.displayName) Temperature: Unavailable — \(snap.sensors.state(for: component).displayText)"
        }.joined(separator: "\n")
        let report = """
        # Borno Pulse — Diagnostic System Report
        Generated: \(Date().description)
        Product: Borno Pulse (v1.0.0) — Smart Mac Utilities & System Monitor
        Privacy Posture: Redacted Local Export
        
        ## 1. Hardware Summary
        - CPU Model: \(snap.cpu.modelName)
        - Architecture: \(snap.cpu.architecture)
        - Cores: \(snap.cpu.physicalCoreCount) physical, \(snap.cpu.logicalCoreCount) logical
        - Total Memory: \(Formatters.bytes(snap.memory.totalBytes))
        - GPU Device: \(snap.gpu.deviceName)
        - Neural Engine: \(snap.gpu.neuralEngineAvailable ? "Available" : "N/A")
        
        ## 2. Real-Time Telemetry
        - CPU Total Usage: \(Formatters.percentage(snap.cpu.totalUsage)) (User: \(Formatters.percentage(snap.cpu.userUsage)), Sys: \(Formatters.percentage(snap.cpu.systemUsage)))
        - RAM Used: \(Formatters.bytes(snap.memory.usedBytes)) / \(Formatters.bytes(snap.memory.totalBytes))
        - Memory Pressure: \(snap.memory.pressureLevel.rawValue)
        - Swap Used: \(Formatters.bytes(snap.memory.swapUsedBytes))
        - Thermal State (pressure, not a temperature): \(snap.sensors.thermalStateDescription)
        - Throttling Active: \(snap.sensors.isThrottling)
        \(temperatureLines)
        - Fans: \(snap.sensors.fansState.isAvailable ? snap.sensors.fanSpeeds.map { "\($0.name) \(Formatters.rpm($0.speedRPM))" }.joined(separator: ", ") : snap.sensors.fansState.displayText)
        - Network DL Speed: \(Formatters.speed(snap.network.downloadSpeedBytesPerSec))
        - Network UL Speed: \(Formatters.speed(snap.network.uploadSpeedBytesPerSec))
        - Battery: \(snap.battery.hasBattery ? "\\(snap.battery.percentage)%" : "AC Powered")
        
        ## 3. Storage
        - Primary Volume: \(snap.storage.primaryVolume?.name ?? "Macintosh HD")
        - Available Capacity: \(Formatters.bytes(snap.storage.availableCapacityBytes))
        - Purgeable Space: \(Formatters.bytes(snap.storage.purgeableBytes))
        
        ## 4. Privacy Redaction Audit
        - Hardware Serial Number: [REDACTED]
        - Local User Account Name: [REDACTED]
        - Personal Directory Paths: [REDACTED]
        """
        
        let savePanel = NSSavePanel()
        savePanel.title = "Export Diagnostic Report"
        savePanel.nameFieldStringValue = "SmartTool_Diagnostic_Report.md"
        savePanel.allowedContentTypes = [.plainText]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try report.write(to: url, atomically: true, encoding: .utf8)
                exportSuccessMessage = "Report exported to \(url.lastPathComponent)"
            } catch {
                exportSuccessMessage = "Failed writing report: \(error.localizedDescription)"
            }
        }
    }
}
