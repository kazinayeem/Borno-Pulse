//
//  ScreenTimeChartsSectionView.swift
//  Naem Smart Tool
//

import Charts
import SwiftUI

public struct ScreenTimeChartsSectionView: View {
    @ObservedObject var tracker = ScreenTimeTrackerService.shared
    
    public init() {}
    
    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: Usage Trend Bar Chart
            usageTrendCard
                .frame(maxWidth: .infinity)
            
            // Right: Category Donut Chart
            categoryDonutCard
                .frame(width: 320)
        }
    }
    
    // MARK: - Usage Trend Card
    private var usageTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tracker.selectedRange == .today ? "Today's Hourly Distribution" : "\(tracker.selectedRange.rawValue) Activity Trend")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(tracker.selectedRange == .today ? "Foreground active focus vs idle pauses across 24 hours" : "Daily active user attention vs idle periods")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    legendDot(title: "Active Focus", color: AppTheme.matrixGreen)
                    legendDot(title: "Idle / Away", color: AppTheme.warningAmber.opacity(0.7))
                }
            }
            
            if tracker.selectedRange == .today {
                hourlyTodayChart
            } else {
                dailyTrendChart
            }
        }
        .padding(16)
        .smartCard()
    }
    
    // MARK: - Hourly Chart for Today
    private var hourlyTodayChart: some View {
        let todayKey = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: Date())
        }()
        let summary = tracker.dailyRecords[todayKey]
        let buckets = summary?.hourlyBuckets ?? (0..<24).map { HourlyUsageBucket(hour: $0) }
        let hasData = buckets.contains { $0.totalDuration > 0 }
        
        return Group {
            if hasData {
                Chart {
                    ForEach(buckets) { bucket in
                        BarMark(
                            x: .value("Hour", "\(bucket.hour)h"),
                            y: .value("Minutes", bucket.activeDuration / 60.0)
                        )
                        .foregroundStyle(AppTheme.matrixGreen.gradient)
                        
                        if bucket.idleDuration > 0 {
                            BarMark(
                                x: .value("Hour", "\(bucket.hour)h"),
                                y: .value("Minutes", bucket.idleDuration / 60.0)
                            )
                            .foregroundStyle(AppTheme.warningAmber.opacity(0.6).gradient)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel {
                            if let mins = value.as(Double.self) {
                                Text("\(Int(mins))m")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [0, 4, 8, 12, 16, 20].map { "\($0)h" }) { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                emptyChartState(message: "No hourly activity recorded today yet.")
            }
        }
    }
    
    // MARK: - Daily Trend Chart (Week / Month)
    private var dailyTrendChart: some View {
        let trend = tracker.getDailyTrend(for: tracker.selectedRange)
        let hasData = trend.contains { $0.totalDurationHours > 0 }
        
        return Group {
            if hasData {
                Chart {
                    ForEach(trend) { point in
                        BarMark(
                            x: .value("Date", point.label),
                            y: .value("Hours", point.activeDurationHours)
                        )
                        .foregroundStyle(AppTheme.matrixGreen.gradient)
                        .cornerRadius(3)
                        
                        if point.idleDurationHours > 0 {
                            BarMark(
                                x: .value("Date", point.label),
                                y: .value("Hours", point.idleDurationHours)
                            )
                            .foregroundStyle(AppTheme.warningAmber.opacity(0.55).gradient)
                            .cornerRadius(3)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel {
                            if let hrs = value.as(Double.self) {
                                Text(String(format: "%.1fh", hrs))
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 8))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                emptyChartState(message: "No activity data available in the selected range.")
            }
        }
    }
    
    // MARK: - Category Donut Card
    private var categoryDonutCard: some View {
        let categories = tracker.getCategoryBreakdown(for: tracker.selectedRange)
        let totalTime = categories.reduce(0.0) { $0 + $1.totalDuration }
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Category Breakdown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("Interactive application classification")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                if tracker.filterCategory != nil {
                    Button {
                        tracker.filterCategory = nil
                    } label: {
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.electricCyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if totalTime > 0 {
                ZStack {
                    Chart(categories) { item in
                        SectorMark(
                            angle: .value("Usage", item.totalDuration),
                            innerRadius: .ratio(0.62),
                            angularInset: 1.5
                        )
                        .foregroundStyle(item.category.color)
                        .opacity(tracker.filterCategory == nil || tracker.filterCategory == item.category ? 1.0 : 0.3)
                    }
                    .frame(height: 140)
                    
                    VStack(spacing: 2) {
                        Text(Formatters.duration(totalTime))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Total Tracked")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                
                // Clickable Category Legend List
                VStack(spacing: 6) {
                    ForEach(categories.prefix(4)) { item in
                        Button {
                            if tracker.filterCategory == item.category {
                                tracker.filterCategory = nil
                            } else {
                                tracker.filterCategory = item.category
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.category.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(item.category.rawValue)
                                    .font(.system(size: 11, weight: tracker.filterCategory == item.category ? .bold : .regular))
                                    .foregroundStyle(tracker.filterCategory == item.category ? AppTheme.electricCyan : AppTheme.textPrimary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("\(String(format: "%.0f%%", item.percentage)) • \(Formatters.duration(item.totalDuration))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(tracker.filterCategory == item.category ? AppTheme.electricCyan.opacity(0.1) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                emptyChartState(message: "No category data recorded yet.")
            }
        }
        .padding(16)
        .smartCard()
    }
    
    private func legendDot(title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
    
    private func emptyChartState(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24))
                .foregroundStyle(AppTheme.textTertiary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}
