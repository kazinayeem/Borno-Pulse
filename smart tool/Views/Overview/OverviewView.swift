//
//  OverviewView.swift
//  Borno Pulse
//

import SwiftUI

public struct OverviewView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var settings = AppSettings.shared
    
    public init() {}
    
    private let columns = [
        GridItem(.adaptive(minimum: 330, maximum: 480), spacing: 14)
    ]
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Banner
                headerBanner
                
                // Top Glanceable Summary Bar
                topSummaryBar
                
                // Grid of Core Hardware Cards
                LazyVGrid(columns: columns, spacing: 14) {
                    cpuCard
                    gpuCard
                    memoryCard
                    sensorsCard
                    storageCard
                    networkCard
                    batteryCard
                }
            }
            .padding(18)
        }
    }
    
    // MARK: - Header Banner
    private var headerBanner: some View {
        AdaptivePageHeader(
            title: "System Overview",
            subtitle: "\(monitor.snapshot.cpu.modelName) • \(monitor.snapshot.cpu.architecture) • \(monitor.snapshot.cpu.logicalCoreCount) Logical Cores",
            leadingExtra: {
                StatusBadge(
                    text: monitor.snapshot.healthStatusText,
                    color: healthColor(monitor.snapshot.healthScore)
                )
            }
        ) {
            Button {
                monitor.refreshNow()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(AppTypography.font(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    // MARK: - Top Summary Chips
    private var topSummaryBar: some View {
        AdaptiveCardGrid(minColumnWidth: 105, spacing: 10) {
            summaryTile(
                title: "CPU",
                value: Formatters.percentage(monitor.snapshot.cpu.totalUsage),
                icon: "cpu",
                color: AppTheme.electricBlue
            )
            
            summaryTile(
                title: "Memory",
                value: "\(Formatters.percentage(monitor.snapshot.memory.usagePercentage))",
                icon: "memorychip",
                color: AppTheme.electricCyan
            )
            
            if let gpu = monitor.snapshot.gpu.deviceUtilization {
                summaryTile(
                    title: "GPU",
                    value: Formatters.percentage(gpu),
                    icon: "circle.grid.cross",
                    color: AppTheme.purpleAccent
                )
            }
            
            summaryTile(
                title: "Storage Free",
                value: Formatters.bytes(monitor.snapshot.storage.availableCapacityBytes),
                icon: "internaldrive",
                color: AppTheme.warningAmber
            )
            
            summaryTile(
                title: "Network",
                value: Formatters.speed(monitor.snapshot.network.downloadSpeedBytesPerSec),
                icon: "arrow.down.circle",
                color: AppTheme.successGreen
            )
            
            if monitor.snapshot.battery.hasBattery {
                summaryTile(
                    title: "Battery",
                    value: "\(monitor.snapshot.battery.percentage)%",
                    icon: monitor.snapshot.battery.isCharging ? "bolt.batteryblock.fill" : "battery.100",
                    color: monitor.snapshot.battery.percentage <= 20 ? AppTheme.warningAmber : AppTheme.successGreen
                )
            } else {
                summaryTile(
                    title: "Power",
                    value: "AC Desktop",
                    icon: "powerplug",
                    color: AppTheme.successGreen
                )
            }
        }
    }
    
    private func summaryTile(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
    }
    
    private func healthColor(_ score: Int) -> Color {
        if score >= 90 { return AppTheme.successGreen }
        if score >= 70 { return AppTheme.electricBlue }
        if score >= 50 { return AppTheme.warningAmber }
        return AppTheme.dangerRed
    }
    
    // MARK: - CPU Card
    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("CPU Utilization", systemImage: "cpu")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.electricBlue)
                Spacer()
                Text("\(Formatters.percentage(monitor.snapshot.cpu.totalUsage))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            GaugeBar(
                value: monitor.snapshot.cpu.totalUsage / 100.0,
                gradient: cpuUsageGradient(monitor.snapshot.cpu.totalUsage),
                height: 5
            )
            
            LiveMetricChart(
                data: monitor.snapshot.cpu.historicalUsage,
                title: "Usage Trend (Last 60s)",
                unit: "%",
                gradient: AppTheme.blueGradient,
                lineColor: AppTheme.electricBlue,
                maxValue: 100.0,
                height: 55
            )
            
            Divider().opacity(0.15)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("User").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(Formatters.percentage(monitor.snapshot.cpu.userUsage)).font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("System").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(Formatters.percentage(monitor.snapshot.cpu.systemUsage)).font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Idle").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(Formatters.percentage(monitor.snapshot.cpu.idleUsage)).font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cores").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text("\(monitor.snapshot.cpu.logicalCoreCount)").font(.system(size: 12, weight: .semibold))
                }
            }
        }
        .smartCard()
    }
    
    // MARK: - GPU Card
    private var gpuCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("GPU & Metal", systemImage: "circle.grid.cross")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.purpleAccent)
                Spacer()
                if let util = monitor.snapshot.gpu.deviceUtilization {
                    Text(Formatters.percentage(util))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    StatusBadge(text: "Active", color: AppTheme.purpleAccent)
                }
            }
            
            if let util = monitor.snapshot.gpu.deviceUtilization {
                GaugeBar(
                    value: util / 100.0,
                    gradient: LinearGradient(colors: [AppTheme.purpleAccent, AppTheme.electricCyan], startPoint: .leading, endPoint: .trailing),
                    height: 5
                )
            }
            
            LiveMetricChart(
                data: monitor.snapshot.gpu.historicalUsage,
                title: "GPU Load Trend",
                unit: "%",
                gradient: LinearGradient(colors: [AppTheme.purpleAccent, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing),
                lineColor: AppTheme.purpleAccent,
                maxValue: 100.0,
                height: 55
            )
            
            Divider().opacity(0.15)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Device").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(monitor.snapshot.gpu.deviceName).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    if let inUse = monitor.snapshot.gpu.inUseMemoryBytes {
                        Text(Formatters.bytes(inUse)).font(.system(size: 12, weight: .semibold))
                    } else {
                        Text("Unified").font(.system(size: 12, weight: .semibold))
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Neural Engine").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(monitor.snapshot.gpu.neuralEngineAvailable ? "Online" : "N/A")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(monitor.snapshot.gpu.neuralEngineAvailable ? AppTheme.successGreen : AppTheme.textTertiary)
                }
            }
        }
        .smartCard()
    }
    
    // MARK: - Memory Card
    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.electricCyan)
                Spacer()
                Text(Formatters.bytes(monitor.snapshot.memory.usedBytes))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            GaugeBar(
                value: monitor.snapshot.memory.usagePercentage / 100.0,
                gradient: LinearGradient(colors: [AppTheme.electricCyan, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing),
                height: 5
            )
            
            LiveMetricChart(
                data: monitor.snapshot.memory.historicalUsage,
                title: "RAM (Cap: \(Formatters.bytes(monitor.snapshot.memory.totalBytes)))",
                unit: "%",
                gradient: LinearGradient(colors: [AppTheme.electricCyan, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing),
                lineColor: AppTheme.electricCyan,
                maxValue: 100.0,
                height: 55
            )
            
            Divider().opacity(0.15)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pressure").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(monitor.snapshot.memory.pressureLevel.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(memoryPressureColor(monitor.snapshot.memory.pressureLevel))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Available").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(Formatters.bytes(monitor.snapshot.memory.availableBytes)).font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Swap Used").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(Formatters.bytes(monitor.snapshot.memory.swapUsedBytes)).font(.system(size: 12, weight: .semibold))
                }
            }
        }
        .smartCard()
    }
    
    // MARK: - Sensors Card
    private var sensorsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Temperature & Fans", systemImage: "thermometer.medium")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.orangeAccent)
                Spacer()
                StatusBadge(
                    text: monitor.snapshot.sensors.thermalState.shortLabel,
                    color: thermalStateColor(monitor.snapshot.sensors.thermalState)
                )
            }
            
            ForEach([ThermalComponent.cpu, .gpu, .battery]) { component in
                ComponentTemperatureRow(
                    component: component,
                    sensors: monitor.snapshot.sensors,
                    unit: settings.temperatureUnit,
                    staleAfter: monitor.sensorStaleAfter
                )
            }
            
            StatRow(
                label: "Thermal State (Pressure)",
                value: monitor.snapshot.sensors.thermalStateDescription,
                icon: "waveform.path.ecg",
                hint: "macOS thermal pressure level. This is not a temperature."
            )
            
            if !monitor.snapshot.sensors.fanSpeeds.isEmpty {
                ForEach(monitor.snapshot.sensors.fanSpeeds) { fan in
                    StatRow(
                        label: fan.name,
                        value: Formatters.rpm(fan.speedRPM),
                        icon: "fanblades"
                    )
                }
            } else {
                StatRow(
                    label: "Fan Speed",
                    value: "Unavailable",
                    icon: "fanblades",
                    hint: monitor.snapshot.sensors.fansState.displayText
                )
            }
        }
        .smartCard()
    }
    
    // MARK: - Storage Card
    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Storage (APFS)", systemImage: "internaldrive")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.warningAmber)
                Spacer()
                Text(Formatters.bytes(monitor.snapshot.storage.availableCapacityBytes) + " Free")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            GaugeBar(
                value: monitor.snapshot.storage.usedPercentage / 100.0,
                gradient: LinearGradient(colors: [AppTheme.warningAmber, AppTheme.orangeAccent], startPoint: .leading, endPoint: .trailing),
                height: 5
            )
            
            HStack {
                Text("Used: \(Formatters.bytes(monitor.snapshot.storage.usedCapacityBytes)) (\(Formatters.percentage(monitor.snapshot.storage.usedPercentage)))")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("Total: \(Formatters.bytes(monitor.snapshot.storage.totalCapacityBytes))")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Divider().opacity(0.15)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Primary Volume").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(monitor.snapshot.storage.primaryVolume?.name ?? "Macintosh HD").font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Purgeable").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(Formatters.bytes(monitor.snapshot.storage.purgeableBytes)).font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Volumes").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text("\(monitor.snapshot.storage.volumes.count) Mounted").font(.system(size: 12, weight: .semibold))
                }
            }
        }
        .smartCard()
    }
    
    // MARK: - Network Card
    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Network Activity", systemImage: "network")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.electricBlueLight)
                Spacer()
                HStack(spacing: 8) {
                    Label(Formatters.speed(monitor.snapshot.network.downloadSpeedBytesPerSec), systemImage: "arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.successGreen)
                    Label(Formatters.speed(monitor.snapshot.network.uploadSpeedBytesPerSec), systemImage: "arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.electricBlueLight)
                }
            }
            
            LiveMetricChart(
                data: monitor.snapshot.network.historicalDownload,
                title: "Download Throughput",
                unit: " B/s",
                gradient: AppTheme.greenGradient,
                lineColor: AppTheme.successGreen,
                maxValue: max(1024 * 1024, (monitor.snapshot.network.historicalDownload.max() ?? 1024)),
                height: 55
            )
            
            Divider().opacity(0.15)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Received").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(Formatters.bytes(monitor.snapshot.network.totalReceivedBytes)).font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Sent").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(Formatters.bytes(monitor.snapshot.network.totalSentBytes)).font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interface").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(monitor.snapshot.network.activeInterfaces.first?.displayName ?? "en0").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                }
            }
        }
        .smartCard()
    }
    
    // MARK: - Battery Card
    private var batteryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Battery & Energy", systemImage: monitor.snapshot.battery.hasBattery ? (monitor.snapshot.battery.isCharging ? "battery.100.bolt" : "battery.100") : "powerplug")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.successGreen)
                Spacer()
                if monitor.snapshot.battery.hasBattery {
                    Text("\(monitor.snapshot.battery.percentage)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    StatusBadge(text: "AC Connected", color: AppTheme.successGreen)
                }
            }
            
            if monitor.snapshot.battery.hasBattery {
                GaugeBar(
                    value: Double(monitor.snapshot.battery.percentage) / 100.0,
                    gradient: LinearGradient(colors: [AppTheme.successGreen, AppTheme.electricCyan], startPoint: .leading, endPoint: .trailing),
                    height: 5
                )
            }
            
            StatRow(
                label: "Power Source",
                value: monitor.snapshot.battery.powerSource,
                icon: "powerplug"
            )
            
            if monitor.snapshot.battery.hasBattery {
                StatRow(
                    label: "Charging State",
                    value: monitor.snapshot.battery.isCharging ? "Charging" : (monitor.snapshot.battery.isPluggedIn ? "Fully Charged (AC)" : "On Battery Power"),
                    icon: "bolt"
                )
                
                if let cycles = monitor.snapshot.battery.cycleCount {
                    StatRow(
                        label: "Cycle Count",
                        value: "\(cycles)",
                        icon: "arrow.triangle.2.circlepath"
                    )
                }
                
                if let health = monitor.snapshot.battery.healthPercentage {
                    StatRow(
                        label: "Maximum Capacity",
                        value: "\(health)%",
                        icon: "heart.fill"
                    )
                }
            } else {
                StatRow(
                    label: "Architecture",
                    value: "Continuous Wall Power",
                    icon: "desktopcomputer"
                )
            }
        }
        .smartCard()
    }
    
    private func cpuUsageGradient(_ usage: Double) -> LinearGradient {
        if usage > 85 { return AppTheme.dangerGradient }
        if usage > 65 { return AppTheme.warningGradient }
        return AppTheme.blueGradient
    }
    
    private func memoryPressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return AppTheme.successGreen
        case .warning: return AppTheme.warningAmber
        case .critical: return AppTheme.dangerRed
        }
    }
}
