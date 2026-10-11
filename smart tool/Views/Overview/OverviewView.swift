//
//  OverviewView.swift
//  Naem Smart Tool
//

import SwiftUI

public struct OverviewView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var settings = AppSettings.shared
    
    public init() {}
    
    private let columns = [
        GridItem(.adaptive(minimum: 360, maximum: 520), spacing: 16)
    ]
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Banner
                headerBanner
                
                // Grid of 7 core hardware cards
                LazyVGrid(columns: columns, spacing: 16) {
                    cpuCard
                    gpuCard
                    memoryCard
                    sensorsCard
                    storageCard
                    networkCard
                    batteryCard
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Header Banner
    private var headerBanner: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("System Overview")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    StatusBadge(
                        text: monitor.snapshot.healthStatusText,
                        color: healthColor(monitor.snapshot.healthScore)
                    )
                }
                
                Text("\(monitor.snapshot.cpu.modelName) • \(monitor.snapshot.cpu.architecture) • \(monitor.snapshot.cpu.logicalCoreCount) Logical Cores")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    monitor.refreshNow()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private func healthColor(_ score: Int) -> Color {
        if score >= 90 { return AppTheme.successGreen }
        if score >= 70 { return AppTheme.electricBlue }
        if score >= 50 { return AppTheme.warningAmber }
        return AppTheme.dangerRed
    }
    
    // MARK: - CPU Card
    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("CPU Utilization", systemImage: "cpu")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.electricBlue)
                Spacer()
                Text("\(Formatters.percentage(monitor.snapshot.cpu.totalUsage))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            GaugeBar(
                value: monitor.snapshot.cpu.totalUsage / 100.0,
                gradient: cpuUsageGradient(monitor.snapshot.cpu.totalUsage)
            )
            
            LiveMetricChart(
                data: monitor.snapshot.cpu.historicalUsage,
                title: "Usage Trend (Last 60s)",
                unit: "%",
                gradient: AppTheme.blueGradient,
                lineColor: AppTheme.electricBlue,
                maxValue: 100.0,
                height: 70
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("GPU & Metal", systemImage: "circle.grid.cross")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.purpleAccent)
                Spacer()
                if let util = monitor.snapshot.gpu.deviceUtilization {
                    Text(Formatters.percentage(util))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    StatusBadge(text: "Active", color: AppTheme.purpleAccent)
                }
            }
            
            if let util = monitor.snapshot.gpu.deviceUtilization {
                GaugeBar(
                    value: util / 100.0,
                    gradient: LinearGradient(colors: [AppTheme.purpleAccent, AppTheme.electricCyan], startPoint: .leading, endPoint: .trailing)
                )
            }
            
            LiveMetricChart(
                data: monitor.snapshot.gpu.historicalUsage,
                title: "GPU Load Trend",
                unit: "%",
                gradient: LinearGradient(colors: [AppTheme.purpleAccent, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing),
                lineColor: AppTheme.purpleAccent,
                maxValue: 100.0,
                height: 70
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.electricCyan)
                Spacer()
                Text(Formatters.bytes(monitor.snapshot.memory.usedBytes))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            GaugeBar(
                value: monitor.snapshot.memory.usagePercentage / 100.0,
                gradient: LinearGradient(colors: [AppTheme.electricCyan, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing)
            )
            
            LiveMetricChart(
                data: monitor.snapshot.memory.historicalUsage,
                title: "RAM Usage (Capacity: \(Formatters.bytes(monitor.snapshot.memory.totalBytes)))",
                unit: "%",
                gradient: LinearGradient(colors: [AppTheme.electricCyan, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing),
                lineColor: AppTheme.electricCyan,
                maxValue: 100.0,
                height: 70
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Thermals & Fans", systemImage: "thermometer.medium")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.orangeAccent)
                Spacer()
                StatusBadge(
                    text: monitor.snapshot.sensors.thermalStateDescription.components(separatedBy: " ").first ?? "Nominal",
                    color: thermalColor(monitor.snapshot.sensors.thermalState)
                )
            }
            
            StatRow(
                label: "Thermal State",
                value: monitor.snapshot.sensors.thermalStateDescription,
                icon: "waveform.path.ecg"
            )
            
            StatRow(
                label: "Thermal Throttling",
                value: monitor.snapshot.sensors.isThrottling ? "Active Throttling" : "None (Optimal)",
                icon: "bolt.shield.fill"
            )
            
            if let temp = monitor.snapshot.sensors.cpuTemperature {
                StatRow(
                    label: "CPU Temperature",
                    value: Formatters.temperature(temp, inFahrenheit: settings.temperatureUnit.isFahrenheit),
                    icon: "thermometer"
                )
            } else {
                StatRow(
                    label: "Direct Diode Access",
                    value: "Sandboxed (SoC Guarded)",
                    icon: "lock.shield",
                    hint: "Direct thermal diodes require kernel-level helper on Apple Silicon. Thermal pressure state is fully active."
                )
            }
            
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
                    label: "Cooling Architecture",
                    value: "Intelligent Fan / Silent",
                    icon: "fanblades",
                    hint: "Fan telemetry is managed by Apple Silicon SMC hardware controller."
                )
            }
        }
        .smartCard()
    }
    
    // MARK: - Storage Card
    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Storage (APFS)", systemImage: "internaldrive")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.warningAmber)
                Spacer()
                Text(Formatters.bytes(monitor.snapshot.storage.availableCapacityBytes) + " Free")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            GaugeBar(
                value: monitor.snapshot.storage.usedPercentage / 100.0,
                gradient: LinearGradient(colors: [AppTheme.warningAmber, AppTheme.orangeAccent], startPoint: .leading, endPoint: .trailing)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Network Activity", systemImage: "network")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.electricBlueLight)
                Spacer()
                HStack(spacing: 8) {
                    Label(Formatters.speed(monitor.snapshot.network.downloadSpeedBytesPerSec), systemImage: "arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.successGreen)
                    Label(Formatters.speed(monitor.snapshot.network.uploadSpeedBytesPerSec), systemImage: "arrow.up")
                        .font(.system(size: 12, weight: .semibold))
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
                height: 70
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
                    Text("Primary Interface").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                    Text(monitor.snapshot.network.activeInterfaces.first?.displayName ?? "en0").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                }
            }
        }
        .smartCard()
    }
    
    // MARK: - Battery Card
    private var batteryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Battery & Energy", systemImage: monitor.snapshot.battery.hasBattery ? (monitor.snapshot.battery.isCharging ? "battery.100.bolt" : "battery.100") : "powerplug")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.successGreen)
                Spacer()
                if monitor.snapshot.battery.hasBattery {
                    Text("\(monitor.snapshot.battery.percentage)%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    StatusBadge(text: "AC Connected", color: AppTheme.successGreen)
                }
            }
            
            if monitor.snapshot.battery.hasBattery {
                GaugeBar(
                    value: Double(monitor.snapshot.battery.percentage) / 100.0,
                    gradient: LinearGradient(colors: [AppTheme.successGreen, AppTheme.electricCyan], startPoint: .leading, endPoint: .trailing)
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
    
    private func thermalColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: return AppTheme.successGreen
        case .fair: return AppTheme.warningAmber
        case .serious, .critical: return AppTheme.dangerRed
        @unknown default: return AppTheme.textSecondary
        }
    }
}
