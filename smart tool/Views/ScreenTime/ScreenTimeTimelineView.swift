//
//  ScreenTimeTimelineView.swift
//  Naem Smart Tool
//

import SwiftUI

public struct ScreenTimeTimelineView: View {
    @ObservedObject var tracker = ScreenTimeTrackerService.shared
    
    public init() {}
    
    public var body: some View {
        let todayKey = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: Date())
        }()
        let summary = tracker.dailyRecords[todayKey]
        let segments = summary?.timelineSegments ?? []
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's Session Timeline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("Chronological application focus sessions throughout the day")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Text("\(segments.count) session transitions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            if segments.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("No session switches captured today yet. Focus sessions will appear as you switch apps.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                // Interactive visual timeline bar
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        let totalWidth = geo.size.width
                        let startOfDay = Calendar.current.startOfDay(for: Date())
                        let daySeconds: Double = 86400.0
                        
                        ZStack(alignment: .leading) {
                            // 24-hour background bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 24)
                            
                            // App blocks
                            ForEach(segments) { seg in
                                let segOffset = max(0, seg.startTime.timeIntervalSince(startOfDay))
                                let xPos = (segOffset / daySeconds) * totalWidth
                                let blockWidth = max(2.0, (seg.duration / daySeconds) * totalWidth)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(seg.category.color)
                                    .frame(width: min(totalWidth - xPos, blockWidth), height: 20)
                                    .offset(x: xPos, y: 2)
                                    .help("\(seg.appName) • \(Formatters.duration(seg.duration)) (\(seg.startTime.formatted(date: .omitted, time: .shortened)))")
                            }
                        }
                    }
                    .frame(height: 24)
                    
                    // Hour axis labels
                    HStack {
                        Text("12 AM")
                        Spacer()
                        Text("6 AM")
                        Spacer()
                        Text("12 PM")
                        Spacer()
                        Text("6 PM")
                        Spacer()
                        Text("11:59 PM")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.textTertiary)
                    
                    // Recent 5 Sessions preview list
                    VStack(spacing: 6) {
                        ForEach(Array(segments.suffix(5).reversed())) { seg in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(seg.category.color)
                                    .frame(width: 6, height: 6)
                                
                                Text(seg.appName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                Text("• \(seg.category.rawValue)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textTertiary)
                                
                                Spacer()
                                
                                Text(seg.startTime.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textSecondary)
                                
                                Text(Formatters.duration(seg.duration))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.electricCyan)
                                    .frame(width: 55, alignment: .trailing)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color.white.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .smartCard()
    }
}
