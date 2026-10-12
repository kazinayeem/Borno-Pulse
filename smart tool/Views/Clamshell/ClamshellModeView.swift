//
//  ClamshellModeView.swift
//  Borno Pulse
//
//  Lid-Closed Operation & Clamshell Mode Management Interface.
//  Provides duration controls, hardware readiness audits, honest support reporting,
//  thermal & safety warnings, and live background workload verification.
//

import AppKit
import SwiftUI

public struct ClamshellModeView: View {
    @ObservedObject var manager = ClamshellManager.shared
    @ObservedObject var keepAwake = KeepAwakeService.shared
    @ObservedObject var settings = AppSettings.shared

    @State private var selectedTab: ClamshellViewTab = .controls
    @State private var customHoursInput: Int = 1
    @State private var customMinutesInput: Int = 30
    @State private var showThermalInfoModal: Bool = false
    @State private var isRefreshingWorkload: Bool = false

    public enum ClamshellViewTab: String, CaseIterable, Identifiable {
        case controls = "Operation & Timers"
        case workloads = "Workload Verification"
        case readiness = "Hardware Readiness"
        case safety = "Thermal & Safety"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .controls: return "timer"
            case .workloads: return "cpu"
            case .readiness: return "checkmark.shield.fill"
            case .safety: return "thermometer.sun.fill"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Adaptive Page Header
            AdaptivePageHeader(
                title: "Lid-Closed Operation & Clamshell Mode",
                icon: "laptopcomputer.and.arrow.down",
                iconColor: manager.isActive ? AppTheme.warningAmber : AppTheme.electricBlue
            ) {
                // Tab switcher
                HStack(spacing: 4) {
                    ForEach(ClamshellViewTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedTab == tab ? AppTheme.selectionBackground : Color.clear)
                            .foregroundStyle(AppTheme.selectableForeground(selectedTab == tab))
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.toolbarBackground)

            Divider()

            // Main Tab Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Status Overview Hero Card
                    statusHeroBanner

                    // Tab Content Switcher
                    switch selectedTab {
                    case .controls:
                        controlsSection
                    case .workloads:
                        workloadVerificationSection
                    case .readiness:
                        hardwareReadinessSection
                    case .safety:
                        thermalSafetySection
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.graphiteCanvas)
        .onAppear {
            manager.refreshHardwareTelemetry()
            Task {
                await manager.verifyWorkloads()
            }
        }
    }

    // MARK: - 1. Status Overview Hero Card
    private var statusHeroBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                // Animated Status Pulse Icon
                ZStack {
                    Circle()
                        .fill((manager.statusState.isPositive ? AppTheme.warningAmber : (manager.isBatteryLow ? AppTheme.dangerRed : AppTheme.textTertiary)).opacity(0.12))
                        .frame(width: 56, height: 56)

                    Circle()
                        .stroke((manager.statusState.isPositive ? AppTheme.warningAmber : (manager.isBatteryLow ? AppTheme.dangerRed : AppTheme.cardBorder)), lineWidth: 1.5)
                        .frame(width: 56, height: 56)

                    Image(systemName: manager.isActive ? (manager.isOfficialClamshellSupported ? "bolt.shield.fill" : "display.trianglebadge.exclamationmark") : (manager.isBatteryLow ? "battery.25" : "laptopcomputer.slash"))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(manager.statusState.isPositive ? AppTheme.warningAmber : (manager.isBatteryLow ? AppTheme.dangerRed : AppTheme.textSecondary))
                }

                // Info Column
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(manager.statusState.rawValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        // Mode Badge
                        Text(manager.isActive ? manager.activeMode.rawValue : (manager.isOfficialClamshellSupported ? "Clamshell Ready" : "Battery Mode"))
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(
                                (manager.isActive
                                    ? AppTheme.warningAmber
                                    : (manager.isOfficialClamshellSupported ? AppTheme.successGreen : AppTheme.electricBlue)
                                ).opacity(0.15)
                            )
                            .foregroundStyle(
                                manager.isActive
                                    ? AppTheme.warningAmber
                                    : (manager.isOfficialClamshellSupported ? AppTheme.successGreen : AppTheme.electricBlue)
                            )
                            .clipShape(Capsule())
                    }

                    if manager.isActive {
                        HStack(spacing: 12) {
                            HStack(spacing: 5) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("Remaining: \(manager.formattedRemainingTime)")
                                    .font(AppTypography.monospaced(size: 12, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }

                            if let started = manager.startedAt {
                                Text("Started: \(DateFormatter.localizedString(from: started, dateStyle: .none, timeStyle: .medium))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    } else {
                        Text(manager.isOfficialClamshellSupported
                            ? "AC power and external display detected. Supported clamshell mode will keep your Mac running when lid is closed."
                            : "On battery power without external monitor: macOS firmware forces sleep on lid close. Use Display-Off Awake with lid open/ajar."
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                    }
                }

                Spacer()

                // Action Buttons
                HStack(spacing: 8) {
                    if manager.isActive && !manager.isOfficialClamshellSupported {
                        Button {
                            manager.triggerDisplaySleep()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "display")
                                    .font(.system(size: 11))
                                Text("Sleep Display")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(AppTheme.cardBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .help("Turns off display immediately while keeping Mac and background workloads awake")
                    }

                    Button {
                        if manager.isActive {
                            manager.stop()
                        } else {
                            manager.startSession()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: manager.isActive ? "stop.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(manager.isActive ? "Stop Session" : "Start Session")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(manager.isActive ? AppTheme.dangerRed : AppTheme.electricBlue)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: (manager.isActive ? AppTheme.dangerRed : AppTheme.electricBlue).opacity(0.3), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Battery Impact Telemetry Strip (When on battery or active)
            if !manager.isACPowerConnected || manager.batteryLevel < 100 {
                Divider().opacity(0.15)

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: manager.isACPowerConnected ? "battery.100.bolt" : (manager.isBatteryLow ? "battery.25" : "battery.75"))
                            .foregroundStyle(manager.isBatteryLow ? AppTheme.dangerRed : (manager.isACPowerConnected ? AppTheme.successGreen : AppTheme.warningAmber))
                        Text("Battery: \(manager.batteryLevel)%")
                            .font(AppTypography.font(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    if let watts = manager.batteryPowerWatts {
                        HStack(spacing: 4) {
                            Text("Draw:")
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(String(format: "%.1f W", watts))
                                .font(AppTypography.monospaced(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .font(AppTypography.font(size: 11))
                    }

                    if let drain = manager.estimatedBatteryDrainPerHour {
                        HStack(spacing: 4) {
                            Text("Impact:")
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(String(format: "~%.0f%% / hr (approx.)", drain))
                                .font(AppTypography.monospaced(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.warningAmber)
                        }
                        .font(AppTypography.font(size: 11))
                    }

                    if let runtime = manager.approximateBatteryRuntime {
                        HStack(spacing: 4) {
                            Text("Est. Runtime:")
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("~\(runtime) (approx.)")
                                .font(AppTypography.monospaced(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .font(AppTypography.font(size: 11))
                    }

                    Spacer()

                    if manager.isBatteryLow {
                        Text("⚠️ Low Battery Alert")
                            .font(AppTypography.font(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.dangerRed)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(manager.isActive ? AppTheme.warningAmber.opacity(0.4) : AppTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - 2. Controls & Duration Section
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Duration Presets Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "hourglass")
                        .foregroundStyle(AppTheme.electricBlue)
                    Text("Session Duration")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Text("Selected: \(manager.selectedDuration.label)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                // Preset Buttons Grid
                HStack(spacing: 10) {
                    durationButton(duration: .oneHour, label: "1 Hour", icon: "1.circle")
                    durationButton(duration: .twoHours, label: "2 Hours", icon: "2.circle")
                    durationButton(duration: .threeHours, label: "3 Hours", icon: "3.circle")
                    durationButton(duration: .untilStopped, label: "Until Stopped", icon: "infinity")
                }

                Divider().opacity(0.15)

                // Custom Duration Row
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Duration")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    HStack(spacing: 16) {
                        // Hours Stepper
                        HStack(spacing: 6) {
                            Text("Hours:")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)

                            Stepper("\(customHoursInput) h", value: $customHoursInput, in: 0...24)
                                .labelsHidden()

                            Text("\(customHoursInput)h")
                                .font(AppTypography.monospaced(size: 12, weight: .semibold))
                                .frame(width: 32, alignment: .leading)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.cardBackgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Minutes Stepper
                        HStack(spacing: 6) {
                            Text("Minutes:")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)

                            Stepper("\(customMinutesInput) m", value: $customMinutesInput, in: 0...59, step: 5)
                                .labelsHidden()

                            Text("\(customMinutesInput)m")
                                .font(AppTypography.monospaced(size: 12, weight: .semibold))
                                .frame(width: 36, alignment: .leading)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.cardBackgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button("Apply Custom") {
                            let custom = ClamshellDuration.custom(hours: customHoursInput, minutes: customMinutesInput)
                            manager.selectedDuration = custom
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 0.5))

            // Honest Limitation & Operating Mode Explanation
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: manager.isOfficialClamshellSupported ? "checkmark.circle.fill" : "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(manager.isOfficialClamshellSupported ? AppTheme.successGreen : AppTheme.electricBlue)

                    Text(manager.isOfficialClamshellSupported ? "Supported Operation Mode: Official Clamshell" : "Supported Alternative: Display-Off Background Awake")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                if manager.isOfficialClamshellSupported {
                    Text("Your Mac is connected to AC power and an external display. When you start the session and close the lid, macOS will maintain full operation and run all background Docker containers, local servers, and scripts on the external monitor.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text("Apple Silicon MacBooks enforce a hardware sleep trigger when the lid is shut while running on battery or without an external monitor. To prevent data corruption, third-party apps cannot override this without root kernel extensions (blocked by SIP).")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.warningAmber)
                        Text("Recommended Alternative: Keep the lid open or slightly ajar. Borno Pulse will prevent idle sleep so your development workloads continue running, while your display can safely turn off to conserve energy.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(10)
                    .background(AppTheme.warningAmber.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 0.5))

            // Sleep Interruption Alert if occurred
            if manager.wasSleepInterrupted, let msg = manager.sleepInterruptionMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.dangerRed)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Sleep Event Detected")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(AppTheme.dangerRed.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.dangerRed.opacity(0.3), lineWidth: 0.5))
            }
        }
    }

    private func durationButton(duration: ClamshellDuration, label: String, icon: String) -> some View {
        let isSelected = manager.selectedDuration == duration
        return Button {
            manager.selectedDuration = duration
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textSecondary)
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.selectionBackground : AppTheme.cardBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Hardware Readiness Section
    private var hardwareReadinessSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(AppTheme.electricBlue)
                Text("Official Apple Clamshell Readiness Audit")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Refresh Audit") {
                    manager.refreshHardwareTelemetry()
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
            }

            VStack(spacing: 8) {
                ForEach(manager.readinessItems) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.isMet ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(item.isMet ? AppTheme.successGreen : (item.isCriticalForClamshell ? AppTheme.dangerRed : AppTheme.warningAmber))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(item.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        Text(item.isMet ? "Met" : "Missing")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(item.isMet ? AppTheme.successGreen : AppTheme.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((item.isMet ? AppTheme.successGreen : AppTheme.subtleFill).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(12)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // External Display Details if connected
            if !manager.externalDisplayNames.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Detected External Monitors:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    ForEach(manager.externalDisplayNames, id: \.self) { name in
                        HStack(spacing: 6) {
                            Image(systemName: "display")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.electricBlue)
                            Text(name)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }

    // MARK: - 4. Background Workload Verification Section
    private var workloadVerificationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .foregroundStyle(AppTheme.purpleAccent)
                Text("Independent Workload Diagnostic Panel")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button {
                    Task {
                        await manager.verifyWorkloads()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("Verify Now")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Do not assume workloads continue running simply because an app shows an awake indicator. This panel verifies running processes, active network server ports, and Docker containers directly from macOS.")
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.textSecondary)

            // Diagnostic Checklist Cards
            VStack(spacing: 10) {
                // 1. macOS Awake State
                workloadRow(
                    title: "macOS System Awake Status",
                    statusText: manager.isActive ? "Awake (Assertion #\(manager.workloadReport.assertionID))" : "Normal Idle Policies",
                    icon: "power",
                    isGood: manager.isActive,
                    details: "System uptime: \(manager.workloadReport.systemUptimeFormatted)"
                )

                // 2. Local Dev Servers
                let ports = manager.workloadReport.listeningServerPorts
                workloadRow(
                    title: "Active Local Server Ports",
                    statusText: ports.isEmpty ? "No active dev servers" : "\(ports.count) listening port(s)",
                    icon: "server.rack",
                    isGood: !ports.isEmpty,
                    details: ports.isEmpty ? "Check servers on 3000, 5173, 8000, 8080" : "Ports: " + ports.prefix(6).map { ":\($0)" }.joined(separator: ", ")
                )

                // 3. Docker Containers
                let dockerAvail = manager.workloadReport.isDockerAvailable
                let containerCount = manager.workloadReport.runningContainersCount
                workloadRow(
                    title: "Docker Background Workloads",
                    statusText: !dockerAvail ? "Docker Daemon Stopped / Not Installed" : "\(containerCount) container(s) running",
                    icon: "shippingbox.fill",
                    isGood: dockerAvail && containerCount > 0,
                    details: dockerAvail ? "Daemon active and responding" : "CLI or Docker socket unreachable"
                )

                // 4. Detected Dev Processes
                let procs = manager.workloadReport.devProcesses
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.electricCyan)
                        Text("Active Developer Processes (\(procs.count))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                    }

                    if procs.isEmpty {
                        Text("No running development runtimes (Node, Python, Go, Java, Docker) detected.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(procs.prefix(6)) { p in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(AppTheme.successGreen)
                                    .frame(width: 6, height: 6)
                                Text(p.name)
                                    .font(AppTypography.monospaced(size: 11, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Text("PID: \(p.pid)")
                                    .font(AppTypography.monospaced(size: 10))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(p.memoryFormatted)
                                    .font(AppTypography.monospaced(size: 10))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(12)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }

    private func workloadRow(title: String, statusText: String, icon: String, isGood: Bool, details: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(isGood ? AppTheme.successGreen : AppTheme.textSecondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(details)
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isGood ? AppTheme.successGreen : AppTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background((isGood ? AppTheme.successGreen : AppTheme.textSecondary).opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(10)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 5. Thermal & Safety Guidelines Section
    private var thermalSafetySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(AppTheme.dangerRed)
                Text("Thermal Safety & Apple Hardware Boundaries")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 10) {
                safetyBullet(
                    title: "Hinge Ventilation & Airflow",
                    body: "MacBook cooling exhausts and draws airflow through vents located along the hinge beneath the display. Operating under heavy CPU/GPU loads with the lid closed increases thermal resistance and may cause fans to ramp up or processors to throttle."
                )

                safetyBullet(
                    title: "Never Run Closed in Bags or Sleeves",
                    body: "Never close your MacBook and place it into a backpack, sleeve, or enclosed container while running intensive workloads. Heat buildup can cause battery degradation and system emergency shutdowns."
                )

                safetyBullet(
                    title: "No Insecure Hacks or SIP Bypassing",
                    body: "Borno Pulse does not install third-party kernel extensions, simulate phantom HID keystrokes, or bypass macOS System Integrity Protection (SIP). Power assertions are managed strictly through Apple's official IOKit IOPMLib."
                )

                safetyBullet(
                    title: "Safest Configuration for Headless Operation",
                    body: "If an external monitor is not connected, Borno Pulse strongly recommends keeping the lid open or slightly ajar with the display set to sleep. This provides unhindered airflow and zero risk of unexpected sleep interruptions."
                )
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }

    private func safetyBullet(title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.electricBlue)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(body)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(10)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
