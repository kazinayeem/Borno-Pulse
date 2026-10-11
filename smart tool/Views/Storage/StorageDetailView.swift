//
//  StorageDetailView.swift
//  Naem Smart Tool
//

import SwiftUI

public struct StorageDetailView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Storage & APFS Volumes")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Apple File System containers and disk space allocation")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text(Formatters.bytes(monitor.snapshot.storage.availableCapacityBytes) + " Free")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.warningAmber)
                }
                
                // Primary Volume Overview Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(monitor.snapshot.storage.primaryVolume?.name ?? "Macintosh HD", systemImage: "internaldrive.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        StatusBadge(text: "APFS Container", color: AppTheme.warningAmber)
                    }
                    
                    GaugeBar(
                        value: monitor.snapshot.storage.usedPercentage / 100.0,
                        gradient: LinearGradient(colors: [AppTheme.warningAmber, AppTheme.orangeAccent], startPoint: .leading, endPoint: .trailing),
                        height: 12
                    )
                    
                    HStack {
                        Text("Used: \(Formatters.bytes(monitor.snapshot.storage.usedCapacityBytes)) (\(Formatters.percentage(monitor.snapshot.storage.usedPercentage)))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("Total: \(Formatters.bytes(monitor.snapshot.storage.totalCapacityBytes))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    Divider().opacity(0.15)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Purgeable by APFS").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                            Text(Formatters.bytes(monitor.snapshot.storage.purgeableBytes)).font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Available for Important Usage").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                            Text(Formatters.bytes(monitor.snapshot.storage.availableCapacityBytes + monitor.snapshot.storage.purgeableBytes)).font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                    }
                }
                .smartCard()
                
                // Volume Breakdown List
                VStack(alignment: .leading, spacing: 14) {
                    Text("Mounted Volumes & File Systems (\(monitor.snapshot.storage.volumes.count))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    ForEach(monitor.snapshot.storage.volumes) { volume in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: volume.isSystem ? "internaldrive" : "externaldrive")
                                    .foregroundStyle(volume.isSystem ? AppTheme.warningAmber : AppTheme.electricBlue)
                                Text(volume.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Text("\(volume.fileSystem) • \(volume.mountPoint)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            
                            GaugeBar(
                                value: volume.usedPercentage / 100.0,
                                gradient: LinearGradient(colors: [AppTheme.warningAmber, AppTheme.orangeAccent], startPoint: .leading, endPoint: .trailing),
                                height: 6
                            )
                            
                            HStack {
                                Text("\(Formatters.bytes(volume.usedBytes)) used of \(Formatters.bytes(volume.totalBytes))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                                Text("\(Formatters.bytes(volume.freeBytes)) available")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.successGreen)
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .smartCard()
                
                // Deep Storage Analytics Call-to-Action
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Deep Storage Analytics & Visual Treemap")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Inspect interactive squarified treemaps, largest folders, ranked files, and category distributions.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        NavigationLink(value: NavigationSection.storageAnalytics) {
                            HStack(spacing: 6) {
                                Image(systemName: "chart.pie.fill")
                                Text("Open Storage Analytics")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(AppTheme.electricBlue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .smartCard()
            }
            .padding(20)
        }
    }
}
