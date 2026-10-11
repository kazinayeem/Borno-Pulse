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
        AdaptiveCardGrid(minColumnWidth: 175, spacing: 12) {
            // 1. Today Active Time
            cardItem(
                title: "Today's Active Time",
                value: Formatters.duration(stats.todayActiveDuration),
                subvalue: "Idle: \(Formatters.duration(stats.todayIdleDuration))",
                icon: "clock.badge.checkmark.fill",
                tint: AppTheme.matrixGreen,
                badge: "Active Focus"
            )
            
            // 2. 7-Day Daily Average
            cardItem(
                title: "Daily Average (7D)",
                value: Formatters.duration(stats.dailyAverage7Days),
                subvalue: "Week Total: \(Formatters.duration(stats.weeklyTotalDuration))",
                icon: "chart.line.uptrend.xyaxis",
                tint: AppTheme.electricBlue,
                badge: "7D Rolling"
            )
            
            // 3. This Month's Total
            cardItem(
                title: "Month Total (30D)",
                value: Formatters.duration(stats.monthlyTotalDuration),
                subvalue: "Daily Avg: \(Formatters.duration(stats.monthlyDailyAverage))",
                icon: "calendar.badge.clock",
                tint: AppTheme.purpleAccent,
                badge: "30D Total"
            )
            
            // 4. Most Used App
            if let topApp = stats.mostUsedAppToday {
                cardItem(
                    title: "Most-Used Today",
                    value: topApp.name,
                    subvalue: Formatters.duration(topApp.duration),
                    icon: topApp.category.icon,
                    tint: topApp.category.color,
                    badge: topApp.category.rawValue
                )
            } else {
                cardItem(
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
            cardItem(
                title: "Total Mac Uptime",
                value: String(format: "%.1f hrs", uptimeHours),
                subvalue: String(format: "%.1f%% user attention", min(100.0, activeRatio)),
                icon: "power",
                tint: AppTheme.electricCyan,
                badge: "Hardware"
            )
        }
    }
    
    private func cardItem(
        title: String,
        value: String,
        subvalue: String,
        icon: String,
        tint: Color,
        badge: String
    ) -> some View {
        ResponsiveMetricCard(
            title: title,
            value: value,
            subvalue: subvalue,
            icon: icon,
            tint: tint,
            badge: badge,
            tooltip: "\(title): \(value) (\(subvalue))"
        )
    }
}
