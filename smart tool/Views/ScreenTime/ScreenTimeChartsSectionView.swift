//
//  ScreenTimeChartsSectionView.swift
//  Borno Pulse
//

import Charts
import SwiftUI

public struct ScreenTimeChartsSectionView: View {
    @ObservedObject var tracker = ScreenTimeTrackerService.shared
    
    public init() {}
    
    public var body: some View {
        AdaptiveTwoColumnLayout(spacing: 16, rightWidth: 320) {
            // Left / Main: Usage Trend Bar Chart
            usageTrendCard
        } right: {
            // Right / Stacked: Category Donut Chart
            categoryDonutCard
        }
    }
    
    // MARK: - Usage Trend Card
    private var usageTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tracker.selectedRange == .today ? "Today's Hourly Distribution" : "\(tracker.selectedRange.rawValue) Activity Trend")
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(tracker.selectedRange == .today ? "Foreground active focus vs idle pauses across 24 hours" : "Daily active user attention vs idle periods")
                        .font(AppTypography.font(size: 11))
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
                            .foregroundStyle(AppTheme.chartGrid)
                        AxisValueLabel(anchor: .trailing) {
                            if let mins = value.as(Double.self) {
                                Text("\(Int(mins))m")
                                    .font(AppTypography.monospaced(size: 9))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    // Show evenly spaced hours every 4 hours: 0h, 4h, 8h, 12h, 16h, 20h
                    AxisMarks(values: [0, 4, 8, 12, 16, 20].map { "\($0)h" }) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(AppTheme.chartGrid)
                        AxisValueLabel(anchor: .top) {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(AppTypography.caption)
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
        let isWeek = tracker.selectedRange == .week
        
        // In 30-day view, pick 5-6 evenly spaced milestones to avoid overlapping labels
        let milestoneIndices: Set<Int> = {
            if isWeek || trend.count <= 7 {
                return Set(0..<trend.count)
            } else {
                let step = max(1, trend.count / 5)
                var set = Set(stride(from: 0, to: trend.count, by: step))
                if let last = trend.indices.last {
                    set.insert(last)
                }
                return set
            }
        }()
        
        let milestoneKeys: Set<String> = Set(milestoneIndices.compactMap { idx in
            trend.indices.contains(idx) ? trend[idx].dayKey : nil
        })
        
        return Group {
            if hasData {
                Chart {
                    ForEach(Array(trend.enumerated()), id: \.element.id) { index, point in
                        BarMark(
                            x: .value("Date", point.dayKey),
                            y: .value("Hours", point.activeDurationHours)
                        )
                        .foregroundStyle(AppTheme.matrixGreen.gradient)
                        .cornerRadius(3)
                        
                        if point.idleDurationHours > 0 {
                            BarMark(
                                x: .value("Date", point.dayKey),
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
                            .foregroundStyle(AppTheme.chartGrid)
                        AxisValueLabel(anchor: .trailing) {
                            if let hrs = value.as(Double.self) {
                                Text(String(format: "%.1fh", hrs))
                                    .font(AppTypography.monospaced(size: 9))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    // Only label the selected milestone ticks so labels NEVER overlap
                    AxisMarks(values: Array(milestoneKeys)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(AppTheme.chartGrid)
                        AxisValueLabel(anchor: .top) {
                            if let dayKey = value.as(String.self),
                               let point = trend.first(where: { $0.dayKey == dayKey }) {
                                Text(isWeek ? point.weekdayLabel : point.shortDateLabel)
                                    .font(AppTypography.caption)
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
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("Interactive classification")
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                if tracker.filterCategory != nil {
                    Button {
                        tracker.filterCategory = nil
                    } label: {
                        Text("Clear")
                            .font(AppTypography.font(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.electricCyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if totalTime > 0 {
                // Adaptive container: side-by-side or stacked depending on width
                ViewThatFits(in: .horizontal) {
                    // When wide (e.g. stacked full-width mode), donut and legend can sit side-by-side
                    HStack(spacing: 16) {
                        donutVisual(categories: categories, totalTime: totalTime)
                            .frame(width: 140)
                        legendList(categories: categories)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // When in compact sidebar mode (320px column), donut on top, legend below
                    VStack(spacing: 12) {
                        donutVisual(categories: categories, totalTime: totalTime)
                        legendList(categories: categories)
                    }
                }
            } else {
                emptyChartState(message: "No category data recorded yet.")
            }
        }
        .padding(16)
        .smartCard()
    }
    
    private func donutVisual(categories: [CategoryBreakdownItem], totalTime: TimeInterval) -> some View {
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
            .frame(height: 130)
            
            VStack(spacing: 1) {
                Text(Formatters.duration(totalTime))
                    .font(AppTypography.monospaced(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Total")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
    
    private func legendList(categories: [CategoryBreakdownItem]) -> some View {
        VStack(spacing: 6) {
            ForEach(categories.prefix(5)) { item in
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
                            .font(AppTypography.font(size: 11, weight: tracker.filterCategory == item.category ? .bold : .regular))
                            .foregroundStyle(tracker.filterCategory == item.category ? AppTheme.electricCyan : AppTheme.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.0f%%", item.percentage)) • \(Formatters.duration(item.totalDuration))")
                            .font(AppTypography.monospaced(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(tracker.filterCategory == item.category ? AppTheme.electricCyan.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func legendDot(title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(AppTypography.font(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
    
    private func emptyChartState(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24))
                .foregroundStyle(AppTheme.textTertiary)
            Text(message)
                .font(AppTypography.font(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}
