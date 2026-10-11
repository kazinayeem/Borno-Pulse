//
//  CPUDetailView.swift
//  Borno Pulse
//

import SwiftUI

public struct CPUDetailView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CPU & Processor")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(monitor.snapshot.cpu.modelName) (\(monitor.snapshot.cpu.architecture))")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text(Formatters.percentage(monitor.snapshot.cpu.totalUsage))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.electricBlue)
                }
                
                // Historical Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total Utilization Timeline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    LiveMetricChart(
                        data: monitor.snapshot.cpu.historicalUsage,
                        title: "Live CPU Load (Mach host_processor_info)",
                        unit: "%",
                        gradient: AppTheme.blueGradient,
                        lineColor: AppTheme.electricBlue,
                        maxValue: 100.0,
                        height: 120
                    )
                }
                .smartCard()
                
                // Per Core Grid
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Per-Core Utilization (\(monitor.snapshot.cpu.perCoreUsage.count) Cores)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("Physical Cores: \(monitor.snapshot.cpu.physicalCoreCount)")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    
                    let grid = [GridItem(.adaptive(minimum: 140), spacing: 12)]
                    LazyVGrid(columns: grid, spacing: 12) {
                        ForEach(Array(monitor.snapshot.cpu.perCoreUsage.enumerated()), id: \.offset) { index, usage in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Core \(index + 1)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Spacer()
                                    Text(Formatters.percentage(usage, decimals: 0))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                GaugeBar(
                                    value: usage / 100.0,
                                    gradient: usage > 80 ? AppTheme.dangerGradient : AppTheme.blueGradient,
                                    height: 6
                                )
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .smartCard()
                
                // Technical Breakdown
                VStack(alignment: .leading, spacing: 10) {
                    Text("Processor Metrics Breakdown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    StatRow(label: "User Space Utilization", value: Formatters.percentage(monitor.snapshot.cpu.userUsage), icon: "person.fill")
                    StatRow(label: "System (Kernel) Utilization", value: Formatters.percentage(monitor.snapshot.cpu.systemUsage), icon: "gearshape.fill")
                    StatRow(label: "Idle Capacity", value: Formatters.percentage(monitor.snapshot.cpu.idleUsage), icon: "pause.fill")
                    StatRow(label: "Nice Priority Utilization", value: Formatters.percentage(monitor.snapshot.cpu.niceUsage), icon: "speedometer")
                    StatRow(label: "Hardware Architecture", value: monitor.snapshot.cpu.architecture, icon: "cpu")
                    StatRow(label: "Telemetry Source", value: "Darwin Mach Host Statistics (Kernel)", icon: "checkmark.shield.fill")
                }
                .smartCard()
            }
            .padding(20)
        }
    }
}
