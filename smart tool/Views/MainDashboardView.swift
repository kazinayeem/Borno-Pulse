//
//  MainDashboardView.swift
//  Naem Smart Tool
//

import SwiftUI

public enum NavigationSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case cpu = "CPU"
    case gpu = "GPU & Neural Engine"
    case memory = "Memory"
    case sensors = "Temperature & Fans"
    case storage = "Storage"
    case network = "Network"
    case battery = "Battery & Energy"
    case processes = "Processes"
    case cleaner = "Cache Cleaner"
    case fileTools = "File Tools"
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
        case .processes: return "list.bullet.rectangle.portrait"
        case .cleaner: return "sparkles"
        case .fileTools: return "folder.badge.gearshape"
        case .diagnostics: return "waveform.path.ecg.rectangle"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainDashboardView: View {
    @State private var selectedSection: NavigationSection? = .overview
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var monitor = SystemMonitor.shared
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .frame(minWidth: 950, minHeight: 620)
    }
    
    // MARK: - Sidebar
    private var sidebarContent: some View {
        List(selection: $selectedSection) {
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
            
            Section("File Tools") {
                sidebarItem(.fileTools)
            }
            
            Section("System Utilities") {
                sidebarItem(.processes)
                sidebarItem(.cleaner)
                sidebarItem(.diagnostics)
                sidebarItem(.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }
    
    private func sidebarItem(_ section: NavigationSection) -> some View {
        NavigationLink(value: section) {
            Label {
                Text(section.rawValue)
                    .font(.system(size: 13, weight: .medium))
            } icon: {
                Image(systemName: section.icon)
                    .foregroundStyle(iconColor(for: section))
            }
        }
    }
    
    private func iconColor(for section: NavigationSection) -> Color {
        switch section {
        case .overview: return AppTheme.electricBlue
        case .cpu: return AppTheme.electricBlue
        case .gpu: return AppTheme.purpleAccent
        case .memory: return AppTheme.electricCyan
        case .sensors: return AppTheme.orangeAccent
        case .storage: return AppTheme.warningAmber
        case .network: return AppTheme.successGreen
        case .battery: return AppTheme.successGreen
        case .processes: return AppTheme.electricBlueLight
        case .cleaner: return AppTheme.electricCyan
        case .fileTools: return AppTheme.neonCyan
        case .diagnostics: return AppTheme.electricBlue
        case .settings: return AppTheme.textSecondary
        }
    }
    
    private var sidebarFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(monitor.isMonitoring ? AppTheme.successGreen : AppTheme.dangerRed)
                .frame(width: 8, height: 8)
            
            Text(monitor.isMonitoring ? "Engine Active (\(String(format: "%.1fs", settings.refreshIntervalSeconds)))" : "Engine Paused")
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.15))
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
        case .processes:
            ProcessMonitorView()
        case .cleaner:
            CacheCleanerView()
        case .fileTools:
            FileToolsDashboardView()
        case .diagnostics:
            DiagnosticsView()
        case .settings:
            SettingsView()
        }
    }
}
