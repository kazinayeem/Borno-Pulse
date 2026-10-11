//
//  MenuBarPopoverView.swift
//  Naem Smart Tool
//

import AppKit
import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var settings = AppSettings.shared
    public var onOpenDashboard: () -> Void
    public var onOpenSettings: () -> Void
    public var onQuickCleanup: () -> Void
    public var onQuit: () -> Void
    
    public init(
        onOpenDashboard: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onQuickCleanup: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.onOpenDashboard = onOpenDashboard
        self.onOpenSettings = onOpenSettings
        self.onQuickCleanup = onQuickCleanup
        self.onQuit = onQuit
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar
            
            Divider().opacity(0.15)
            
            // Metrics List
            ScrollView {
                VStack(spacing: 10) {
                    // CPU Row
                    miniMetricRow(
                        title: "CPU Load",
                        icon: "cpu",
                        color: AppTheme.electricBlue,
                        value: Formatters.percentage(monitor.snapshot.cpu.totalUsage),
                        progress: monitor.snapshot.cpu.totalUsage / 100.0,
                        sparkline: monitor.snapshot.cpu.historicalUsage
                    )
                    
                    // Memory Row
                    miniMetricRow(
                        title: "Memory",
                        icon: "memorychip",
                        color: AppTheme.electricCyan,
                        value: Formatters.bytes(monitor.snapshot.memory.usedBytes),
                        progress: monitor.snapshot.memory.usagePercentage / 100.0,
                        sparkline: monitor.snapshot.memory.historicalUsage
                    )
                    
                    // GPU Row (if available)
                    if let util = monitor.snapshot.gpu.deviceUtilization {
                        miniMetricRow(
                            title: "GPU Load",
                            icon: "circle.grid.cross",
                            color: AppTheme.purpleAccent,
                            value: Formatters.percentage(util),
                            progress: util / 100.0,
                            sparkline: monitor.snapshot.gpu.historicalUsage
                        )
                    }
                    
                    // Storage Row
                    miniMetricRow(
                        title: "Storage Free",
                        icon: "internaldrive",
                        color: AppTheme.warningAmber,
                        value: Formatters.bytes(monitor.snapshot.storage.availableCapacityBytes),
                        progress: monitor.snapshot.storage.usedPercentage / 100.0,
                        sparkline: nil
                    )
                    
                    // Network Row
                    HStack(spacing: 8) {
                        Image(systemName: "network")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.successGreen)
                            .frame(width: 20)
                        Text("Network")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Label(Formatters.speed(monitor.snapshot.network.downloadSpeedBytesPerSec), systemImage: "arrow.down")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.successGreen)
                        Label(Formatters.speed(monitor.snapshot.network.uploadSpeedBytesPerSec), systemImage: "arrow.up")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.electricBlueLight)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    // Battery Row (if laptop)
                    if monitor.snapshot.battery.hasBattery {
                        HStack(spacing: 8) {
                            Image(systemName: monitor.snapshot.battery.isCharging ? "bolt.batteryblock.fill" : "battery.100")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.successGreen)
                                .frame(width: 20)
                            Text("Battery")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text("\(monitor.snapshot.battery.percentage)% (\(monitor.snapshot.battery.powerSource))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    
                    // Thermal Row
                    HStack(spacing: 8) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.orangeAccent)
                            .frame(width: 20)
                        Text("Thermal State")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        StatusBadge(
                            text: monitor.snapshot.sensors.thermalStateDescription.components(separatedBy: " ").first ?? "Nominal",
                            color: monitor.snapshot.sensors.thermalState == .nominal ? AppTheme.successGreen : AppTheme.warningAmber
                        )
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(14)
            }
            .frame(maxHeight: 330)
            
            Divider().opacity(0.15)
            
            // Bottom Quick Actions
            bottomActionToolbar
        }
        .frame(width: 320)
        .background(AppTheme.cardBackground)
        .preferredColorScheme(settings.appearanceMode.colorScheme)
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                    .foregroundStyle(AppTheme.electricBlue)
                Text("Naem Smart Tool")
                    .font(.system(size: 13, weight: .bold))
            }
            Spacer()
            StatusBadge(
                text: monitor.snapshot.healthStatusText,
                color: healthColor(monitor.snapshot.healthScore)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.15))
    }
    
    private func healthColor(_ score: Int) -> Color {
        if score >= 90 { return AppTheme.successGreen }
        if score >= 70 { return AppTheme.electricBlue }
        if score >= 50 { return AppTheme.warningAmber }
        return AppTheme.dangerRed
    }
    
    // MARK: - Mini Metric Row
    private func miniMetricRow(
        title: String,
        icon: String,
        color: Color,
        value: String,
        progress: Double,
        sparkline: [Double]?
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            GaugeBar(value: progress, gradient: LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing), height: 4)
        }
        .padding(8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    // MARK: - Bottom Actions
    private var bottomActionToolbar: some View {
        HStack(spacing: 8) {
            Button {
                onOpenDashboard()
            } label: {
                Label("Dashboard", systemImage: "macwindow")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.electricBlue)
            .controlSize(.small)
            
            Button {
                onQuickCleanup()
            } label: {
                Label("Clean", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Spacer()
            
            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textSecondary)
            .help("Preferences")
            
            Button {
                onQuit()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.dangerRed)
            .help("Quit Application")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2))
    }
}
