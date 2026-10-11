//
//  PortManagerView.swift
//  Borno Pulse
//
//  Complete Port Manager and Local Development Server Monitor interface.
//

import AppKit
import SwiftUI

public struct PortManagerView: View {
    @ObservedObject var service = PortScannerService.shared
    
    // Termination workflow state
    @State private var itemToTerminate: PortItem? = nil
    @State private var showTerminationDialog: Bool = false
    @State private var terminationStep: TerminationStep = .confirmGraceful
    @State private var terminationStatusMessage: String? = nil
    @State private var isTerminating: Bool = false
    
    // Docker container termination state
    @State private var containerToStop: DockerPortMapping? = nil
    @State private var showStopContainerDialog: Bool = false
    
    // Toast notification
    @State private var toastMessage: String? = nil
    @State private var showToast: Bool = false
    
    private enum TerminationStep {
        case confirmGraceful
        case offerForceKill(message: String)
    }
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Top Page Header
                headerSection
                
                // 2. Summary KPI Cards
                summaryCardsSection
                
                // 3. Port Conflicts Banner (if any)
                if !service.conflicts.isEmpty {
                    conflictBannerSection
                }
                
                // 4. Filters, Presets & Controls
                filterToolbarSection
                
                // 5. Main Content: Table & Detail Inspector
                tableAndInspectorSection
            }
            .padding(20)
        }
        .background(AppTheme.contentBackground)
        .sheet(isPresented: $showTerminationDialog) {
            terminationSheet
        }
        .sheet(isPresented: $showStopContainerDialog) {
            stopContainerSheet
        }
        .overlay(alignment: .bottom) {
            if showToast, let msg = toastMessage {
                toastView(msg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - 1. Page Header
    private var headerSection: some View {
        AdaptivePageHeader(
            title: "Port Manager",
            subtitle: "Inspect active listening sockets, recognize local dev servers, and resolve port conflicts",
            icon: "server.rack",
            iconColor: AppTheme.electricBlue
        ) {
            HStack(spacing: 10) {
                // Pause / Resume
                Button {
                    if service.isPaused {
                        service.resumeMonitoring()
                        showFeedbackToast("Resumed port monitoring")
                    } else {
                        service.pauseMonitoring()
                        showFeedbackToast("Paused port monitoring")
                    }
                } label: {
                    Label(service.isPaused ? "Resume" : "Pause", systemImage: service.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .help(service.isPaused ? "Resume background port scans" : "Pause background port scans")
                
                // Auto Refresh Interval Menu
                Menu {
                    Button("Manual Only (Off)") { service.updateInterval(0) }
                    Button("Every 2 seconds") { service.updateInterval(2.0) }
                    Button("Every 5 seconds (Default)") { service.updateInterval(5.0) }
                    Button("Every 10 seconds") { service.updateInterval(10.0) }
                    Button("Every 30 seconds") { service.updateInterval(30.0) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text(service.autoRefreshInterval == 0 ? "Refresh: Off" : "\(Int(service.autoRefreshInterval))s")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .help("Configurable background scan interval")
                
                // Manual Refresh
                Button {
                    service.refresh()
                    showFeedbackToast("Scanning listening ports…")
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(service.isLoading ? 360 : 0))
                            .animation(service.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: service.isLoading)
                        Text("Refresh")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .disabled(service.isLoading)
                .help("Rescan all local TCP listening sockets immediately")
                
                // Export CSV
                Button {
                    exportResultsToCSV()
                } label: {
                    Label("Export CSV", systemImage: "arrow.down.doc")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .help("Export currently filtered listening ports to CSV")
            }
        }
    }
    
    // MARK: - 2. Summary Cards
    private var summaryCardsSection: some View {
        HStack(spacing: 14) {
            summaryCard(
                title: "Listening Ports",
                value: "\(service.ports.count)",
                subtitle: "Active TCP sockets",
                icon: "network",
                accent: AppTheme.electricBlue
            )
            
            let devCount = service.ports.filter { $0.category == .userDevelopment || $0.devServerType != nil }.count
            summaryCard(
                title: "Dev Servers",
                value: "\(devCount)",
                subtitle: "Vite, Next, APIs & DBs",
                icon: "laptopcomputer",
                accent: AppTheme.electricCyan
            )
            
            summaryCard(
                title: "Port Conflicts",
                value: "\(service.conflicts.count)",
                subtitle: service.conflicts.isEmpty ? "No collisions detected" : "Overlapping sockets found",
                icon: service.conflicts.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                accent: service.conflicts.isEmpty ? AppTheme.successGreen : AppTheme.dangerRed
            )
            
            summaryCard(
                title: "Docker Ports",
                value: "\(service.dockerPublishedCount)",
                subtitle: service.dockerAvailable ? "Docker engine connected" : "Docker unavailable",
                icon: "shippingbox.fill",
                accent: service.dockerAvailable ? AppTheme.purpleAccent : AppTheme.textTertiary
            )
        }
    }
    
    private func summaryCard(title: String, value: String, subtitle: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            
            Text(subtitle)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 3. Conflict Banner
    private var conflictBannerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.dangerRed)
                    .font(.system(size: 14))
                
                Text("Development Port Conflicts Detected (\(service.conflicts.count))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.dangerRed)
                
                Spacer()
            }
            
            ForEach(service.conflicts) { conflict in
                HStack(alignment: .top, spacing: 8) {
                    Text("Port \(conflict.port):")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(conflict.reason)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Spacer()
                    
                    if let first = conflict.processes.first {
                        Button("Inspect First") {
                            service.selectedPortItem = first
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(AppTheme.dangerRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.dangerRed.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - 4. Filter Toolbar
    private var filterToolbarSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Search Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    TextField("Search port, PID, process name, framework, or path…", text: $service.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    
                    if !service.searchText.isEmpty {
                        Button {
                            service.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .themedInputField(cornerRadius: AppTheme.Radius.small)
                .frame(minWidth: 260, maxWidth: 380)
                
                Spacer()
                
                // Privacy Toggle
                Toggle("Hide Command Lines", isOn: $service.hideCommandLines)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .help("Redacts all command-line arguments across the interface for security")
            }
            
            // Presets Switcher Bar
            HStack(spacing: 6) {
                ForEach(PortFilterPreset.allCases) { preset in
                    Button {
                        service.activePreset = preset
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 10))
                            Text(preset.rawValue)
                                .font(.system(size: 11, weight: service.activePreset == preset ? .semibold : .regular))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(service.activePreset == preset ? AppTheme.selectionBackground : Color.clear)
                        .foregroundStyle(AppTheme.selectableForeground(service.activePreset == preset))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                
                if service.activePreset == .custom {
                    HStack(spacing: 6) {
                        Text("Ports:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        TextField("3000, 5173, 8000", text: $service.customPortString)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 160)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .themedInputField(cornerRadius: 4)
                    }
                    .padding(.leading, 8)
                }
                
                Spacer()
                
                // Result Count
                Text("\(service.filteredPorts.count) of \(service.ports.count) ports")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
    
    // MARK: - 5. Table & Detail Inspector
    private var tableAndInspectorSection: some View {
        AdaptiveTwoColumnLayout(spacing: 16, rightWidth: service.selectedPortItem != nil ? 340 : nil) {
            // Left Column: Ports Table
            portsTableCard
        } right: {
            // Right Column: Detail Inspector (if selected)
            if let selected = service.selectedPortItem {
                portDetailInspectorCard(selected)
            }
        }
    }
    
    // MARK: - Ports Table Card
    private var portsTableCard: some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 10) {
                sortableHeader("Port", column: .port, width: 85, alignment: .leading)
                sortableHeader("Process", column: .name, width: 140, alignment: .leading)
                sortableHeader("PID", column: .pid, width: 65, alignment: .trailing)
                sortableHeader("Address", column: .address, width: 110, alignment: .leading)
                sortableHeader("User", column: .user, width: 80, alignment: .leading)
                Text("Status")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 80, alignment: .center)
                Spacer()
                Text("Actions")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 90, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(AppTheme.cardBackgroundSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(AppTheme.cardBorder),
                alignment: .bottom
            )
            
            // Rows
            if service.filteredPorts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No listening sockets match current criteria")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    if !service.searchText.isEmpty || service.activePreset != .all {
                        Button("Reset Filters") {
                            service.searchText = ""
                            service.activePreset = .all
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(service.filteredPorts.enumerated()), id: \.element.id) { index, item in
                        portRow(item: item, isEven: index % 2 == 0)
                    }
                }
            }
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
    
    private func sortableHeader(_ title: String, column: PortSortColumn, width: CGFloat, alignment: Alignment) -> some View {
        Button {
            if service.sortColumn == column {
                service.sortAscending.toggle()
            } else {
                service.sortColumn = column
                service.sortAscending = true
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                if service.sortColumn == column {
                    Image(systemName: service.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .foregroundStyle(service.sortColumn == column ? AppTheme.electricBlue : AppTheme.textTertiary)
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Row View
    private func portRow(item: PortItem, isEven: Bool) -> some View {
        let isSelected = service.selectedPortItem?.id == item.id
        
        return HStack(spacing: 10) {
            // Port
            HStack(spacing: 5) {
                Text("\(item.port)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                
                if let dev = item.devServerType {
                    Image(systemName: dev.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.electricCyan)
                        .help(dev.name)
                }
            }
            .frame(width: 85, alignment: .leading)
            
            // Process
            VStack(alignment: .leading, spacing: 2) {
                Text(item.processName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                
                if let dev = item.devServerType {
                    Text(dev.framework)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.electricCyan)
                        .lineLimit(1)
                } else if item.isDockerPublished, let d = item.dockerMapping {
                    Text("Docker: \(d.containerName)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.purpleAccent)
                        .lineLimit(1)
                }
            }
            .frame(width: 140, alignment: .leading)
            
            // PID
            Text("\(item.pid)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 65, alignment: .trailing)
            
            // Address
            Text(item.localAddress)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
            
            // User
            HStack(spacing: 4) {
                Text(item.user)
                    .font(.system(size: 11))
                    .foregroundStyle(item.uid == 0 ? AppTheme.warningAmber : AppTheme.textSecondary)
                    .lineLimit(1)
                if item.uid == 0 {
                    Text("root")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(AppTheme.warningAmber.opacity(0.15))
                        .foregroundStyle(AppTheme.warningAmber)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(width: 80, alignment: .leading)
            
            // Status
            HStack(spacing: 4) {
                Circle()
                    .fill(AppTheme.successGreen)
                    .frame(width: 6, height: 6)
                Text("Listen")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.successGreen)
            }
            .frame(width: 80, alignment: .center)
            
            Spacer()
            
            // Actions
            HStack(spacing: 4) {
                Button {
                    service.selectedPortItem = isSelected ? nil : item
                } label: {
                    Image(systemName: isSelected ? "chevron.right.circle.fill" : "info.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.electricBlue)
                .help("Inspect full process metadata and sockets")
                
                Button {
                    startTerminationFlow(for: item)
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.dangerRed)
                .help("Stop process listening on port \(item.port)")
            }
            .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            isSelected
                ? AppTheme.selectionBackground
                : (isEven ? Color.clear : AppTheme.tableRowAlternate)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            service.selectedPortItem = isSelected ? nil : item
        }
        .contextMenu {
            Button("Copy Port (\(item.port))") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(item.port)", forType: .string)
                showFeedbackToast("Copied port \(item.port)")
            }
            
            Button("Copy PID (\(item.pid))") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(item.pid)", forType: .string)
                showFeedbackToast("Copied PID \(item.pid)")
            }
            
            Button("Copy Local URL (\(item.formattedURLString))") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.formattedURLString, forType: .string)
                showFeedbackToast("Copied \(item.formattedURLString)")
            }
            
            Button("Open in Browser") {
                if let url = URL(string: item.formattedURLString) {
                    NSWorkspace.shared.open(url)
                }
            }
            
            Divider()
            
            Button("Copy Executable Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.executablePath, forType: .string)
                showFeedbackToast("Copied executable path")
            }
            
            Button("Copy Command Line") {
                let cmd = service.hideCommandLines ? item.redactedCommandLine : item.commandLine
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(cmd, forType: .string)
                showFeedbackToast("Copied command line")
            }
            
            Divider()
            
            Button("Inspect Details") {
                service.selectedPortItem = item
            }
            
            Button("Stop Process…", role: .destructive) {
                startTerminationFlow(for: item)
            }
        }
    }
    
    // MARK: - Detail Inspector Card
    private func portDetailInspectorCard(_ item: PortItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Port \(item.port)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text(item.protocolType)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(AppTheme.electricBlue.opacity(0.15))
                            .foregroundStyle(AppTheme.electricBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    
                    Text(item.processName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Button {
                    service.selectedPortItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Classification & Framework
            HStack(spacing: 8) {
                Label(item.category.rawValue, systemImage: item.category.icon)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                if let dev = item.devServerType {
                    Label(dev.name, systemImage: dev.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.electricCyan.opacity(0.12))
                        .foregroundStyle(AppTheme.electricCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            // Metadata Key-Value List
            VStack(spacing: 8) {
                inspectorRow("PID", value: "\(item.pid)")
                if let ppid = item.ppid {
                    inspectorRow("Parent PID", value: "\(ppid)")
                }
                inspectorRow("Local Address", value: item.localAddress)
                inspectorRow("Owner", value: "\(item.user) (UID: \(item.uid))")
                if !item.startTimeString.isEmpty {
                    inspectorRow("Started", value: item.startTimeString)
                }
                if item.associatedPorts.count > 1 {
                    inspectorRow("All Ports", value: item.associatedPorts.map { String($0) }.joined(separator: ", "))
                }
            }
            
            // Executable Path
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Executable Path")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.textTertiary)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.executablePath, forType: .string)
                        showFeedbackToast("Copied executable path")
                    }
                    .font(.system(size: 9))
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.electricBlue)
                }
                
                Text(item.executablePath.isEmpty ? "Not available / Restricted" : item.executablePath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            // Command Line (with Redaction)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Command Line Arguments")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.textTertiary)
                    Spacer()
                    Button("Copy") {
                        let cmd = service.hideCommandLines ? item.redactedCommandLine : item.commandLine
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                        showFeedbackToast("Copied command line")
                    }
                    .font(.system(size: 9))
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.electricBlue)
                }
                
                let displayCommand = service.hideCommandLines ? item.redactedCommandLine : (item.redactedCommandLine.isEmpty ? item.commandLine : item.redactedCommandLine)
                Text(displayCommand.isEmpty ? "(None)" : displayCommand)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(4)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            // Docker Container Section (if applicable)
            if let d = item.dockerMapping {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Docker Container Details")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.purpleAccent)
                    
                    VStack(spacing: 4) {
                        inspectorRow("Container", value: d.containerName)
                        inspectorRow("Image", value: d.image)
                        inspectorRow("Container Port", value: "\(d.containerPort)")
                        inspectorRow("Status", value: d.status)
                    }
                    
                    Button(role: .destructive) {
                        containerToStop = d
                        showStopContainerDialog = true
                    } label: {
                        Label("Stop Docker Container", systemImage: "shippingbox.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(AppTheme.purpleAccent.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            Spacer()
            
            // Danger Zone: Stop Process
            Button(role: .destructive) {
                startTerminationFlow(for: item)
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("Stop Process (PID: \(item.pid))")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.dangerRed)
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
    
    private func inspectorRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
    }
    
    // MARK: - Termination Flow
    private func startTerminationFlow(for item: PortItem) {
        itemToTerminate = item
        terminationStep = .confirmGraceful
        terminationStatusMessage = nil
        isTerminating = false
        showTerminationDialog = true
    }
    
    private var terminationSheet: some View {
        VStack(spacing: 16) {
            if let item = itemToTerminate {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.dangerRed)
                
                Text("Stop \(item.processName)?")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                VStack(spacing: 6) {
                    Text("This process is listening on port \(item.port) with PID \(item.pid).")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Text("Stopping it may interrupt a development server, database, or background worker.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                
                if let msg = terminationStatusMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.dangerRed)
                        .padding(8)
                        .background(AppTheme.dangerRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                switch terminationStep {
                case .confirmGraceful:
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            showTerminationDialog = false
                        }
                        .keyboardShortcut(.cancelAction)
                        
                        Button {
                            performGracefulTermination(item)
                        } label: {
                            if isTerminating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Stop Gracefully (SIGTERM)")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.dangerRed)
                        .disabled(isTerminating)
                    }
                    
                case .offerForceKill(let reason):
                    VStack(spacing: 12) {
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.warningAmber)
                        
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                showTerminationDialog = false
                            }
                            
                            Button("Force Terminate (SIGKILL)") {
                                performForceTermination(item)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.dangerRed)
                            .disabled(isTerminating)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 420)
    }
    
    private func performGracefulTermination(_ item: PortItem) {
        isTerminating = true
        Task {
            let res = await ProcessTerminationService.shared.terminateGracefully(item: item)
            await MainActor.run {
                isTerminating = false
                switch res {
                case .success(let msg):
                    showTerminationDialog = false
                    showFeedbackToast(msg)
                    service.refresh()
                case .requiresForceKill(let reason):
                    terminationStep = .offerForceKill(message: reason)
                case .failed(let reason):
                    terminationStatusMessage = reason
                }
            }
        }
    }
    
    private func performForceTermination(_ item: PortItem) {
        isTerminating = true
        Task {
            let res = await ProcessTerminationService.shared.forceTerminate(item: item)
            await MainActor.run {
                isTerminating = false
                switch res {
                case .success(let msg):
                    showTerminationDialog = false
                    showFeedbackToast(msg)
                    service.refresh()
                case .requiresForceKill:
                    break
                case .failed(let reason):
                    terminationStatusMessage = reason
                }
            }
        }
    }
    
    // MARK: - Stop Container Sheet
    private var stopContainerSheet: some View {
        VStack(spacing: 16) {
            if let d = containerToStop {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.purpleAccent)
                
                Text("Stop Docker Container?")
                    .font(.system(size: 16, weight: .bold))
                
                Text("Are you sure you want to stop '\(d.containerName)' (Image: \(d.image))?")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showStopContainerDialog = false
                    }
                    
                    Button("Stop Container") {
                        let id = d.containerID
                        showStopContainerDialog = false
                        Task {
                            let res = await ProcessTerminationService.shared.stopDockerContainer(containerID: id)
                            await MainActor.run {
                                switch res {
                                case .success(let msg):
                                    showFeedbackToast(msg)
                                    service.refresh()
                                case .requiresForceKill(let reason), .failed(let reason):
                                    showFeedbackToast(reason)
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.purpleAccent)
                }
            }
        }
        .padding(24)
        .frame(width: 380)
    }
    
    // MARK: - CSV Export
    private func exportResultsToCSV() {
        let csv = service.exportCSV()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(csv, forType: .string)
        showFeedbackToast("Exported \(service.filteredPorts.count) ports to clipboard (CSV format)")
    }
    
    // MARK: - Feedback Toast
    private func showFeedbackToast(_ text: String) {
        toastMessage = text
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showToast = false
        }
    }
    
    private func toastView(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.successGreen)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.elevatedCardBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}
