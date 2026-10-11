//
//  NetworkDetailView.swift
//  Naem Smart Tool
//

import SwiftUI

public struct NetworkDetailView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Network & Bandwidth")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Real-time network interface telemetry and packet counters")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Label(Formatters.speed(monitor.snapshot.network.downloadSpeedBytesPerSec), systemImage: "arrow.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.successGreen)
                        Label(Formatters.speed(monitor.snapshot.network.uploadSpeedBytesPerSec), systemImage: "arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.electricBlueLight)
                    }
                }
                
                // Live Throughput Charts
                VStack(alignment: .leading, spacing: 14) {
                    Text("Download Throughput History")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    LiveMetricChart(
                        data: monitor.snapshot.network.historicalDownload,
                        title: "Inbound Speed (getifaddrs)",
                        unit: " B/s",
                        gradient: AppTheme.greenGradient,
                        lineColor: AppTheme.successGreen,
                        maxValue: max(1024 * 1024, (monitor.snapshot.network.historicalDownload.max() ?? 1024)),
                        height: 90
                    )
                    
                    Divider().opacity(0.15)
                    
                    Text("Upload Throughput History")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    LiveMetricChart(
                        data: monitor.snapshot.network.historicalUpload,
                        title: "Outbound Speed (getifaddrs)",
                        unit: " B/s",
                        gradient: AppTheme.blueGradient,
                        lineColor: AppTheme.electricBlue,
                        maxValue: max(512 * 1024, (monitor.snapshot.network.historicalUpload.max() ?? 512)),
                        height: 90
                    )
                }
                .smartCard()
                
                // Lifetime Transfer Totals
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cumulative Data Counters (Since Boot)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    StatRow(label: "Total Bytes Received", value: Formatters.bytes(monitor.snapshot.network.totalReceivedBytes), icon: "arrow.down.circle.fill")
                    StatRow(label: "Total Bytes Transmitted", value: Formatters.bytes(monitor.snapshot.network.totalSentBytes), icon: "arrow.up.circle.fill")
                }
                .smartCard()
                
                // Network Interfaces List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Network Interfaces (\(monitor.snapshot.network.activeInterfaces.count))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    ForEach(monitor.snapshot.network.activeInterfaces) { iface in
                        HStack {
                            Image(systemName: iface.isWiFi ? "wifi" : "cable.connector")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.electricBlue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(iface.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(iface.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            
                            Spacer()
                            
                            if let ip = iface.ipAddress {
                                Text(ip)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            
                            StatusBadge(text: iface.isUp ? "Active" : "Down", color: iface.isUp ? AppTheme.successGreen : AppTheme.dangerRed)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .smartCard()
            }
            .padding(20)
        }
    }
}
