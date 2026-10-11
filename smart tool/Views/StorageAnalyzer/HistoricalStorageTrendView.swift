//
//  HistoricalStorageTrendView.swift
//  Naem Smart Tool
//

import Charts
import SwiftUI

public struct HistoricalStorageTrendView: View {
    @ObservedObject var historyService = HistoricalStorageService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Historical Storage Trend")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Track disk usage trends across scan intervals")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Toggle("Collect Local History", isOn: $historyService.isHistoryCollectionEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                
                if !historyService.snapshots.isEmpty {
                    Button("Clear History") {
                        historyService.clearHistory()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.dangerRed)
                }
            }
            
            if !historyService.isHistoryCollectionEnabled {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Storage History Collection Disabled")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Enable history collection above to track how your disk usage changes over successive scans. Snapshots are stored 100% locally on your Mac.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else if historyService.snapshots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No Historical Snapshots Recorded")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Historical data points are automatically recorded when a storage scan finishes.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                Chart(historyService.snapshots) { item in
                    AreaMark(
                        x: .value("Time", item.timestamp),
                        y: .value("Used GB", Double(item.usedCapacityBytes) / (1024 * 1024 * 1024))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.electricBlue.opacity(0.35), AppTheme.electricBlue.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    LineMark(
                        x: .value("Time", item.timestamp),
                        y: .value("Used GB", Double(item.usedCapacityBytes) / (1024 * 1024 * 1024))
                    )
                    .foregroundStyle(AppTheme.electricBlue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Time", item.timestamp),
                        y: .value("Used GB", Double(item.usedCapacityBytes) / (1024 * 1024 * 1024))
                    )
                    .foregroundStyle(AppTheme.neonCyan)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel {
                            if let doubleVal = val.as(Double.self) {
                                Text("\(Int(doubleVal)) GB")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
        }
        .smartCard()
    }
}
