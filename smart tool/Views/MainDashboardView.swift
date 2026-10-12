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
    case clamshellMode = "Clamshell Mode"
    
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
        case .clamshellMode: return "laptopcomputer.and.arrow.down"
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
    @State private var showingOnboardingSheet: Bool = false
    @State private var showingAboutDeveloperSheet: Bool = false
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
            ToolbarItem(placement: .automatic) {
                Button {
                    showingAboutDeveloperSheet = true
                } label: {
                    Label("About Developer", systemImage: "person.crop.circle")
                }
                .help("About Borno Pulse & Developer Profile")
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
        .sheet(isPresented: $showingAboutDeveloperSheet) {
            AboutDeveloperView()
        }
        .sheet(isPresented: $showingOnboardingSheet) {
            FirstLaunchPermissionsView {
                showingOnboardingSheet = false
            }
        }
        .onAppear {
            if !settings.hasCompletedOnboarding && !CommandLine.arguments.contains("--capture-all-screenshots") && !CommandLine.arguments.contains("--run-tests") {
                showingOnboardingSheet = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showOnboardingSetup"))) { _ in
            showingOnboardingSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAboutDeveloper)) { _ in
            showingAboutDeveloperSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSection)) { notification in
            if let section = notification.object as? NavigationSection {
                selectedSection = section
            }
        }
        .background(
            WindowAccessor { window in
                MainWindowRouter.shared.register(window: window)
            }
        )
        .onAppear {
            MainWindowRouter.shared.register(openWindow: openWindow)
            if CommandLine.arguments.contains("--settings") {
                selectedSection = .settings
            } else if CommandLine.arguments.contains("--port-manager") {
                selectedSection = .portManager
            } else if CommandLine.arguments.contains("--clamshell") {
                selectedSection = .clamshellMode
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
                            .font(AppTypography.font(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Smart Mac Utilities & System Monitor")
                            .font(AppTypography.font(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Button {
                        showingAboutDeveloperSheet = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.electricBlue)
                    }
                    .buttonStyle(.plain)
                    .help("About Borno Pulse & Developer Profile")
                }
                .padding(.vertical, 4)
            }
            
            Section(header: sidebarSectionHeader("Hardware & Monitoring")) {
                sidebarItem(.overview)
                sidebarItem(.cpu)
                sidebarItem(.gpu)
                sidebarItem(.memory)
                sidebarItem(.sensors)
                sidebarItem(.storage)
                sidebarItem(.network)
                sidebarItem(.battery)
            }
            
            Section(header: sidebarSectionHeader("Developer & Network")) {
                sidebarItem(.developerToolbox)
                sidebarItem(.networkToolkit)
                sidebarItem(.portManager)
                sidebarItem(.clamshellMode)
            }
            
            Section(header: sidebarSectionHeader("Productivity & Files")) {
                sidebarItem(.clipboard)
                sidebarItem(.focusPomodoro)
                sidebarItem(.batchConverter)
                sidebarItem(.pdfStudio)
                sidebarItem(.fileTools)
            }
            
            Section(header: sidebarSectionHeader("Privacy & Safety")) {
                sidebarItem(.privacySecurity)
                sidebarItem(.localBackup)
            }
            
            Section(header: sidebarSectionHeader("System Utilities")) {
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

    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.font(size: 10.5, weight: .bold))
            .foregroundStyle(AppTheme.textSecondary)
            .textCase(.uppercase)
    }
    
    @ViewBuilder
    private func sidebarItem(_ section: NavigationSection) -> some View {
        let isSelected = selectedSection == section
        NavigationLink(value: section) {
            HStack(spacing: 9) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.electricBlue.opacity(0.85))
                    .frame(width: 18, alignment: .center)
                
                Text(section.rawValue)
                    .font(AppTypography.font(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
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
        case .clamshellMode:
            ClamshellModeView()
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
            SystemCleanerView()
        case .diagnostics:
            DiagnosticsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Window Accessor Helper
private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onWindow(window)
            }
        }
    }
}
