//
//  MainDashboardView.swift
//  Borno Pulse
//

import SwiftUI

public enum NavigationSection: String, CaseIterable, Identifiable, Sendable {
    // Hardware & Monitoring
    case overview = "Overview"
    case cpu = "CPU"
    case gpu = "GPU & Neural Engine"
    case memory = "Memory"
    case sensors = "Temperature & Fans"
    case storage = "Storage"
    case network = "Network"
    case battery = "Battery & Energy"
    
    // Developer & Network Toolkit
    case developerToolbox = "Developer Toolbox"
    case networkToolkit = "Network Toolkit"
    case portManager = "Port Manager"
    
    // Productivity & Utilities
    case clipboard = "Clipboard Manager"
    case focusPomodoro = "Focus & Pomodoro"
    case batchConverter = "Batch File Converter"
    case pdfStudio = "PDF Studio"
    case fileTools = "File Tools"
    
    // Privacy & Backup
    case privacySecurity = "Privacy & Security"
    case localBackup = "Local Backup Helper"
    
    // System Utilities
    case screenTime = "Screen Time"
    case storageAnalytics = "Storage Analytics"
    case processes = "Processes"
    case cleaner = "Cache Cleaner"
    case diagnostics = "Diagnostics"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .cpu: return "cpu"
        case .gpu: return "circle.grid.cross.fill"
        case .memory: return "memorychip.fill"
        case .sensors: return "thermometer.medium"
        case .storage: return "internaldrive.fill"
        case .network: return "network"
        case .battery: return "battery.100.bolt"
        case .developerToolbox: return "wrench.and.screwdriver.fill"
        case .networkToolkit: return "antenna.radiowaves.left.and.right"
        case .portManager: return "server.rack"
        case .clipboard: return "doc.on.clipboard"
        case .focusPomodoro: return "timer"
        case .batchConverter: return "arrow.triangle.2.circlepath"
        case .pdfStudio: return "doc.richtext.fill"
        case .fileTools: return "folder.badge.gearshape"
        case .privacySecurity: return "shield.lefthalf.filled"
        case .localBackup: return "externaldrive.badge.timemachine"
        case .screenTime: return "clock.badge.checkmark"
        case .storageAnalytics: return "chart.pie.fill"
        case .processes: return "list.bullet.rectangle.portrait"
        case .cleaner: return "sparkles"
        case .diagnostics: return "waveform.path.ecg.rectangle"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainDashboardView: View {
    @State private var selectedSection: NavigationSection? = .overview
    @State private var showingQuickLauncher: Bool = false
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var monitor = SystemMonitor.shared
    @Environment(\.openWindow) private var openWindow
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.contentBackground)
        }
        .frame(minWidth: 960, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    showingQuickLauncher = true
                } label: {
                    Label("Command Palette", systemImage: "command")
                }
                .help("Quick Launcher (⌘K)")
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
        .sheet(isPresented: $showingQuickLauncher) {
            QuickLauncherView(
                onSelect: { section in
                    selectedSection = section
                    showingQuickLauncher = false
                },
                onDismiss: {
                    showingQuickLauncher = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSection)) { notification in
            if let section = notification.object as? NavigationSection {
                selectedSection = section
            }
        }
        .onAppear {
            MainWindowRouter.shared.register(openWindow: openWindow)
            if CommandLine.arguments.contains("--settings") {
                selectedSection = .settings
            } else if CommandLine.arguments.contains("--port-manager") {
                selectedSection = .portManager
            } else if let section = MainWindowRouter.shared.consumePendingSection() {
                selectedSection = section
            }
        }
    }
    
    // MARK: - Sidebar
    private var sidebarContent: some View {
        List(selection: $selectedSection) {
            // App Brand Header
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.electricBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Borno Pulse")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Smart Mac Utilities & System Monitor")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Hardware & Monitoring") {
                sidebarItem(.overview)
                sidebarItem(.cpu)
                sidebarItem(.gpu)
                sidebarItem(.memory)
                sidebarItem(.sensors)
                sidebarItem(.storage)
                sidebarItem(.network)
                sidebarItem(.battery)
            }
            
            Section("Developer & Network") {
                sidebarItem(.developerToolbox)
                sidebarItem(.networkToolkit)
                sidebarItem(.portManager)
            }
            
            Section("Productivity & Files") {
                sidebarItem(.clipboard)
                sidebarItem(.focusPomodoro)
                sidebarItem(.batchConverter)
                sidebarItem(.pdfStudio)
                sidebarItem(.fileTools)
            }
            
            Section("Privacy & Safety") {
                sidebarItem(.privacySecurity)
                sidebarItem(.localBackup)
            }
            
            Section("System Utilities") {
                sidebarItem(.screenTime)
                sidebarItem(.storageAnalytics)
                sidebarItem(.processes)
                sidebarItem(.cleaner)
                sidebarItem(.diagnostics)
                sidebarItem(.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }
    
    private func sidebarItem(_ section: NavigationSection) -> some View {
        // Colors are left to the native sidebar so the selected row gets its own
        // high-contrast foreground on the accent highlight in both appearances.
        NavigationLink(value: section) {
            Label {
                Text(section.rawValue)
                    .font(.system(size: 13, weight: selectedSection == section ? .semibold : .regular))
            } icon: {
                Image(systemName: section.icon)
                    .font(.system(size: 13))
            }
        }
    }
    
    private var sidebarFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.isMonitoring ? AppTheme.successGreen : AppTheme.dangerRed)
                    .frame(width: 7, height: 7)
                
                Text(monitor.isMonitoring ? "Engine (\(String(format: "%.1fs", settings.refreshIntervalSeconds)))" : "Engine Paused")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                
                Spacer()
                
                Button {
                    if monitor.isPaused {
                        monitor.resumeMonitoring()
                    } else {
                        monitor.pauseMonitoring()
                    }
                } label: {
                    Image(systemName: monitor.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textSecondary)
                .help(monitor.isPaused ? "Resume live polling" : "Pause live polling")
            }
            
            Button {
                showingQuickLauncher = true
            } label: {
                HStack {
                    Image(systemName: "command")
                        .font(.system(size: 11))
                    Text("Quick Launcher")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("⌘K")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .themedInputField()
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(AppTheme.cardBorder),
            alignment: .top
        )
    }
    
    // MARK: - Detail Content
    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection ?? .overview {
        case .overview:
            OverviewView()
        case .cpu:
            CPUDetailView()
        case .gpu:
            GPUDetailView()
        case .memory:
            MemoryDetailView()
        case .sensors:
            SensorsDetailView()
        case .storage:
            StorageDetailView()
        case .network:
            NetworkDetailView()
        case .battery:
            BatteryDetailView()
        case .developerToolbox:
            DeveloperToolboxView()
        case .networkToolkit:
            NetworkToolkitView()
        case .portManager:
            PortManagerView()
        case .clipboard:
            ClipboardManagerView()
        case .focusPomodoro:
            FocusPomodoroView()
        case .batchConverter:
            BatchConverterView()
        case .pdfStudio:
            PDFStudioWorkspaceView()
        case .fileTools:
            FileToolsDashboardView()
        case .privacySecurity:
            PrivacySecurityWorkspaceView()
        case .localBackup:
            LocalBackupHelperView()
        case .screenTime:
            ScreenTimeDashboardView()
        case .storageAnalytics:
            StorageAnalyticsDashboardView()
        case .processes:
            ProcessMonitorView()
        case .cleaner:
            CacheCleanerView()
        case .diagnostics:
            DiagnosticsView()
        case .settings:
            SettingsView()
        }
    }
}
