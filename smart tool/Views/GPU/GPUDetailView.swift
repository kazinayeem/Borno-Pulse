//
//  GPUDetailView.swift
//  Borno Pulse
//

import SwiftUI

public struct GPUDetailView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var settings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                AdaptivePageHeader(
                    title: "GPU & Neural Engine",
                    subtitle: monitor.snapshot.gpu.deviceName
                ) {
                    if let util = monitor.snapshot.gpu.deviceUtilization {
                        Text(Formatters.percentage(util))
                            .font(AppTypography.monospaced(size: 28, weight: .bold))
                            .foregroundStyle(AppTheme.purpleAccent)
                    } else {
                        StatusBadge(text: "Metal Ready", color: AppTheme.purpleAccent)
                    }
                }
                
                // Timeline Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("GPU Utilization Timeline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    LiveMetricChart(
                        data: monitor.snapshot.gpu.historicalUsage,
                        title: "Hardware Utilization (IOAccelerator)",
                        unit: "%",
                        gradient: LinearGradient(colors: [AppTheme.purpleAccent, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing),
                        lineColor: AppTheme.purpleAccent,
                        maxValue: 100.0,
                        height: 120
                    )
                }
                .smartCard()
                
                // Apple Neural Engine Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Apple Neural Engine (ANE)", systemImage: "brain.head.profile")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.purpleAccent)
                        Spacer()
                        StatusBadge(
                            text: monitor.snapshot.gpu.neuralEngineAvailable ? "Available" : "Not Detected",
                            color: monitor.snapshot.gpu.neuralEngineAvailable ? AppTheme.successGreen : AppTheme.textTertiary
                        )
                    }
                    
                    Text(monitor.snapshot.gpu.neuralEngineDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    StatRow(
                        label: "Architecture Role",
                        value: "Dedicated Machine Learning Hardware Acceleration",
                        icon: "bolt.badge.automatic"
                    )
                    StatRow(
                        label: "Integration",
                        value: "Direct Unified Memory Fabric access",
                        icon: "point.3.connected.trianglepath.dotted"
                    )
                }
                .smartCard()
                
                // Metal & GPU Technical Specs
                VStack(alignment: .leading, spacing: 10) {
                    Text("Metal Device Specifications")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    StatRow(label: "Device Name", value: monitor.snapshot.gpu.deviceName, icon: "display")
                    StatRow(label: "Unified Memory Architecture", value: monitor.snapshot.gpu.hasUnifiedMemory ? "Yes (Shared RAM)" : "Discrete VRAM", icon: "memorychip")
                    StatRow(label: "Recommended Max Working Set", value: Formatters.bytes(monitor.snapshot.gpu.recommendedMaxWorkingSetSize), icon: "scalemass.fill")
                    StatRow(label: "Max Buffer Length", value: Formatters.bytes(monitor.snapshot.gpu.maxBufferLength), icon: "cylinder.split.1x2.fill")
                    if let inUse = monitor.snapshot.gpu.inUseMemoryBytes {
                        StatRow(label: "In-Use GPU System Memory", value: Formatters.bytes(inUse), icon: "chart.bar.fill")
                    }
                    if let renderer = monitor.snapshot.gpu.rendererUtilization {
                        StatRow(label: "Renderer Utilization", value: Formatters.percentage(renderer), icon: "paintbrush.fill")
                    }
                    if let tiler = monitor.snapshot.gpu.tilerUtilization {
                        StatRow(label: "Tiler Utilization", value: Formatters.percentage(tiler), icon: "square.grid.2x2.fill")
                    }
                    StatRow(label: "Low Power Device", value: monitor.snapshot.gpu.isLowPower ? "Yes" : "No", icon: "leaf.fill")
                    ComponentTemperatureRow(
                        component: .gpu,
                        sensors: monitor.snapshot.sensors,
                        unit: settings.temperatureUnit,
                        staleAfter: monitor.sensorStaleAfter
                    )
                    StatRow(label: "Registry ID", value: "\(monitor.snapshot.gpu.registryID)", icon: "tag.fill")
                }
                .smartCard()
            }
            .padding(20)
        }
    }
}
