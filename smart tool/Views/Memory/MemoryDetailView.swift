//
//  MemoryDetailView.swift
//  Borno Pulse
//

import SwiftUI

public struct MemoryDetailView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                AdaptivePageHeader(
                    title: "Unified Memory (RAM)",
                    subtitle: "Total Physical Capacity: \(Formatters.bytes(monitor.snapshot.memory.totalBytes))"
                ) {
                    Text(Formatters.percentage(monitor.snapshot.memory.usagePercentage))
                        .font(AppTypography.monospaced(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.electricCyan)
                }
                
                // Timeline Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Memory Consumption Timeline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    LiveMetricChart(
                        data: monitor.snapshot.memory.historicalUsage,
                        title: "RAM Utilization (host_statistics64)",
                        unit: "%",
                        gradient: LinearGradient(colors: [AppTheme.electricCyan, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing),
                        lineColor: AppTheme.electricCyan,
                        maxValue: 100.0,
                        height: 120
                    )
                }
                .smartCard()
                
                // Memory Breakdown Visualizer
                VStack(alignment: .leading, spacing: 14) {
                    Text("Memory Distribution Breakdown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    // Segmented Bar
                    GeometryReader { geo in
                        let total = max(Double(monitor.snapshot.memory.totalBytes), 1.0)
                        let appW = geo.size.width * CGFloat(Double(monitor.snapshot.memory.activeBytes + monitor.snapshot.memory.inactiveBytes) / total)
                        let wiredW = geo.size.width * CGFloat(Double(monitor.snapshot.memory.wiredBytes) / total)
                        let compW = geo.size.width * CGFloat(Double(monitor.snapshot.memory.compressedBytes) / total)
                        let freeW = geo.size.width * CGFloat(Double(monitor.snapshot.memory.freeBytes) / total)
                        
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3).fill(AppTheme.electricBlue).frame(width: max(appW, 2))
                            RoundedRectangle(cornerRadius: 3).fill(AppTheme.dangerRed).frame(width: max(wiredW, 2))
                            RoundedRectangle(cornerRadius: 3).fill(AppTheme.warningAmber).frame(width: max(compW, 2))
                            RoundedRectangle(cornerRadius: 3).fill(AppTheme.successGreen).frame(width: max(freeW, 2))
                        }
                    }
                    .frame(height: 14)
                    
                    // Legend Grid
                    let grid = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: grid, alignment: .leading, spacing: 12) {
                        legendItem(color: AppTheme.electricBlue, name: "App Memory (Active/Inactive)", value: Formatters.bytes(monitor.snapshot.memory.activeBytes + monitor.snapshot.memory.inactiveBytes), desc: "Memory actively used by running applications.")
                        legendItem(color: AppTheme.dangerRed, name: "Wired Memory", value: Formatters.bytes(monitor.snapshot.memory.wiredBytes), desc: "Operating system kernel memory that cannot be paged out.")
                        legendItem(color: AppTheme.warningAmber, name: "Compressed Memory", value: Formatters.bytes(monitor.snapshot.memory.compressedBytes), desc: "Data stored in RAM in compressed form to avoid swap disk I/O.")
                        legendItem(color: AppTheme.successGreen, name: "Free / Available", value: Formatters.bytes(monitor.snapshot.memory.availableBytes), desc: "Memory currently ready for immediate allocation.")
                    }
                }
                .smartCard()
                
                // Swap & Pressure Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Memory Pressure & Virtual Memory Swap")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    StatRow(
                        label: "Memory Pressure State",
                        value: monitor.snapshot.memory.pressureLevel.rawValue,
                        icon: "gauge.with.dots.needle.bottom.50percent"
                    )
                    StatRow(
                        label: "Swap Space Used",
                        value: Formatters.bytes(monitor.snapshot.memory.swapUsedBytes),
                        icon: "arrow.triangle.swap"
                    )
                    StatRow(
                        label: "Total Allocated Swap",
                        value: Formatters.bytes(monitor.snapshot.memory.swapTotalBytes),
                        icon: "externaldrive.fill"
                    )
                    StatRow(
                        label: "Page Size",
                        value: "\(getpagesize() / 1024) KB (macOS Standard)",
                        icon: "doc.plaintext.fill"
                    )
                }
                .smartCard()
            }
            .padding(20)
        }
    }
    
    private func legendItem(color: Color, name: String, value: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
                Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
                Text(desc).font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
            }
        }
    }
}
