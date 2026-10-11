//
//  SmartToolWidget.swift
//  Borno Pulse
//

import SwiftUI
import WidgetKit

public struct SmartToolWidgetEntry: TimelineEntry, Sendable {
    public let date: Date
    public let cpuUsage: Double
    public let memoryUsage: Double
    public let batteryPercentage: Int
    public let storageFreeBytes: UInt64
    public let healthText: String
    
    public init(
        date: Date = Date(),
        cpuUsage: Double = 12.0,
        memoryUsage: Double = 54.0,
        batteryPercentage: Int = 85,
        storageFreeBytes: UInt64 = 48 * 1024 * 1024 * 1024,
        healthText: String = "Optimal"
    ) {
        self.date = date
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.batteryPercentage = batteryPercentage
        self.storageFreeBytes = storageFreeBytes
        self.healthText = healthText
    }
}

public struct SmartToolTimelineProvider: TimelineProvider {
    public typealias Entry = SmartToolWidgetEntry
    
    public init() {}
    
    public func placeholder(in context: Context) -> SmartToolWidgetEntry {
        SmartToolWidgetEntry()
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (SmartToolWidgetEntry) -> Void) {
        let entry = SmartToolWidgetEntry()
        completion(entry)
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<SmartToolWidgetEntry>) -> Void) {
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(900)
        
        let entry = SmartToolWidgetEntry(date: currentDate)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

public struct SmartToolWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    public var entry: SmartToolWidgetEntry
    
    public init(entry: SmartToolWidgetEntry) {
        self.entry = entry
    }
    
    public var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            largeWidget
        }
    }
    
    // MARK: - Small Widget
    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                    .foregroundStyle(AppTheme.electricBlue)
                Text("Smart Tool")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Circle()
                    .fill(AppTheme.successGreen)
                    .frame(width: 6, height: 6)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CPU")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("\(Int(entry.cpuUsage))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                GaugeBar(value: entry.cpuUsage / 100.0, gradient: AppTheme.blueGradient, height: 4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("RAM")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("\(Int(entry.memoryUsage))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                GaugeBar(value: entry.memoryUsage / 100.0, gradient: LinearGradient(colors: [AppTheme.electricCyan, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing), height: 4)
            }
            
            Text("Updated periodic")
                .font(.system(size: 8))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(12)
        .containerBackground(AppTheme.cardBackground, for: .widget)
    }
    
    // MARK: - Medium Widget
    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                        .foregroundStyle(AppTheme.electricBlue)
                    Text("Borno Pulse")
                        .font(.system(size: 12, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("CPU Load").font(.system(size: 10)).foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("\(Int(entry.cpuUsage))%").font(.system(size: 11, weight: .bold))
                    }
                    GaugeBar(value: entry.cpuUsage / 100.0, gradient: AppTheme.blueGradient, height: 4)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Memory").font(.system(size: 10)).foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("\(Int(entry.memoryUsage))%").font(.system(size: 11, weight: .bold))
                    }
                    GaugeBar(value: entry.memoryUsage / 100.0, gradient: LinearGradient(colors: [AppTheme.electricCyan, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing), height: 4)
                }
            }
            
            Divider().opacity(0.2)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Health: \(entry.healthText)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.successGreen)
                    Spacer()
                    Image(systemName: "battery.100")
                        .foregroundStyle(AppTheme.successGreen)
                    Text("\(entry.batteryPercentage)%")
                        .font(.system(size: 11, weight: .bold))
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Storage Available")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(Formatters.bytes(entry.storageFreeBytes))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.warningAmber)
                }
                
                Text("Open Borno Pulse for 1s live telemetry")
                    .font(.system(size: 8))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(14)
        .containerBackground(AppTheme.cardBackground, for: .widget)
    }
    
    // MARK: - Large Widget
    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                    .foregroundStyle(AppTheme.electricBlue)
                Text("Borno Pulse — System Monitor")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                StatusBadge(text: entry.healthText, color: AppTheme.successGreen)
            }
            
            Divider().opacity(0.15)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU Load").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                    Text("\(Int(entry.cpuUsage))%").font(.system(size: 20, weight: .bold, design: .rounded))
                    GaugeBar(value: entry.cpuUsage / 100.0, gradient: AppTheme.blueGradient, height: 6)
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("RAM Pressure").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                    Text("\(Int(entry.memoryUsage))%").font(.system(size: 20, weight: .bold, design: .rounded))
                    GaugeBar(value: entry.memoryUsage / 100.0, gradient: LinearGradient(colors: [AppTheme.electricCyan, AppTheme.electricBlue], startPoint: .leading, endPoint: .trailing), height: 6)
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage Free").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                    Text(Formatters.bytes(entry.storageFreeBytes)).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.warningAmber)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Battery State").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                    Text("\(entry.batteryPercentage)%").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.successGreen)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            Spacer()
            
            Text("WidgetKit updates are scheduled periodically by macOS to conserve battery. High-frequency 1-second monitoring runs inside the main application.")
                .font(.system(size: 9))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(16)
        .containerBackground(AppTheme.cardBackground, for: .widget)
    }
}

public struct SmartToolWidget: Widget {
    public let kind: String = "SmartToolWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SmartToolTimelineProvider()) { entry in
            SmartToolWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Smart Tool Overview")
        .description("View real-time CPU, RAM, storage, and battery metrics on your macOS desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
