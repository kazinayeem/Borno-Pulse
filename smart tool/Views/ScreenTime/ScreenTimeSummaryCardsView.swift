//
//  ScreenTimeSummaryCardsView.swift
//  Borno Pulse
//

import SwiftUI

public struct ScreenTimeSummaryCardsView: View {
    public let stats: ScreenTimeStatistics
    public let selectedRange: ScreenTimeRangeOption
    
    public init(stats: ScreenTimeStatistics, selectedRange: ScreenTimeRangeOption) {
        self.stats = stats
        self.selectedRange = selectedRange
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Main Top Metric Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                // 1. Today Active Time
                metricCard(
                    title: "Today's Active Time",
                    value: Formatters.duration(stats.todayActiveDuration),
                    subvalue: "Idle: \(Formatters.duration(stats.todayIdleDuration))",
                    icon: "clock.badge.checkmark.fill",
                    tint: AppTheme.matrixGreen,
                    badge: "Foreground Active"
                )
                
                // 2. 7-Day Daily Average
                metricCard(
                    title: "Daily Average (7D)",
                    value: Formatters.duration(stats.dailyAverage7Days),
                    subvalue: "Week Total: \(Formatters.duration(stats.weeklyTotalDuration))",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: AppTheme.electricBlue,
                    badge: "Rolling 7 Days"
                )
                
                // 3. This Month's Total
                metricCard(
                    title: "Month Total (30D)",
                    value: Formatters.duration(stats.monthlyTotalDuration),
                    subvalue: "Daily Avg: \(Formatters.duration(stats.monthlyDailyAverage))",
                    icon: "calendar.badge.clock",
                    tint: AppTheme.purpleAccent,
                    badge: "Rolling 30 Days"
                )
                
                // 4. Most Used App
                if let topApp = stats.mostUsedAppToday {
                    metricCard(
                        title: "Most-Used Today",
                        value: topApp.name,
                        subvalue: Formatters.duration(topApp.duration),
                        icon: topApp.category.icon,
                        tint: topApp.category.color,
                        badge: topApp.category.rawValue
                    )
                } else {
                    metricCard(
                        title: "Most-Used Today",
                        value: "No Activity",
                        subvalue: "Tracking standby",
                        icon: "app.fill",
                        tint: AppTheme.textSecondary,
                        badge: "Standby"
                    )
                }
                
                // 5. Total Hardware Uptime vs Attention
                let uptimeHours = stats.systemUptime / 3600.0
                let activeRatio = stats.systemUptime > 0 ? (stats.todayActiveDuration / stats.systemUptime) * 100.0 : 0.0
                metricCard(
                    title: "Total Mac Uptime",
                    value: String(format: "%.1f hrs", uptimeHours),
                    subvalue: String(format: "%.1f%% user attention", min(100.0, activeRatio)),
                    icon: "power",
                    tint: AppTheme.electricCyan,
                    badge: "Hardware Power"
                )
            }
        }
    }
    
    private func metricCard(
        title: String,
        value: String,
        subvalue: String,
        icon: String,
        tint: Color,
        badge: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                    
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tint.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(subvalue)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(14)
        .smartCard()
    }
}
