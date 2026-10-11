//
//  CustomizableWidgetView.swift
//  Borno Pulse
//
//  Interactive, customizable native macOS system monitoring mini dashboard widget.
//

import AppKit
import Charts
import SwiftUI

public struct CustomizableWidgetView: View {
    @ObservedObject var preferences = MenuBarWidgetPreferences.shared
    @ObservedObject var monitor = SystemMonitor.shared
    
    @State private var hoveredMetricId: WidgetMetricId? = nil
    @State private var showCleanerConfirmation: Bool = false
    
    public var onNavigateToSection: (NavigationSection) -> Void
    public var onQuickAction: (WidgetQuickActionId) -> Void
    
    public init(
        onNavigateToSection: @escaping (NavigationSection) -> Void = { _ in },
        onQuickAction: @escaping (WidgetQuickActionId) -> Void = { _ in }
    ) {
        self.onNavigateToSection = onNavigateToSection
        self.onQuickAction = onQuickAction
    }
    
    public var body: some View {
        VStack(spacing: preferences.compactSpacing ? 6 : 10) {
            // Widget Header (Status & Last Updated)
            widgetHeader
            
            // Metrics List / Grid according to selected layout style
            let activeMetrics = preferences.activeOrderedMetrics
            
            if activeMetrics.isEmpty {
                emptyStateNotice
            } else {
                switch preferences.layoutStyle {
                case .compact:
                    compactLayoutGrid(metrics: activeMetrics)
                case .balanced:
                    balancedLayoutList(metrics: activeMetrics)
                case .detailed:
                    detailedLayoutList(metrics: activeMetrics)
                }
            }
            
            // Configurable Quick Actions Footer
            if !preferences.enabledQuickActions.isEmpty {
                Divider().opacity(0.15)
                quickActionsFooter
            }
        }
        .padding(preferences.compactSpacing ? 10 : 12)
        .background(AppTheme.cardBackground)
        .alert("Run Cache Cleanup?", isPresented: $showCleanerConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Scan & Clean", role: .destructive) {
                onQuickAction(.openCleaner)
            }
        } message: {
            Text("This will scan and remove safe user application cache files to reclaim disk space.")
        }
    }
    
    // MARK: - Header
    private var widgetHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(monitor.isMonitoring && !monitor.isPaused ? AppTheme.successGreen : AppTheme.warningAmber)
                .frame(width: 7, height: 7)
            
            Text("System Monitor")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            
            Spacer()
            
            // Last Updated Timestamp
            Text("Updated \(monitor.snapshot.timestamp.formatted(date: .omitted, time: .standard))")
                .font(.system(size: 9))
                .foregroundStyle(AppTheme.textTertiary)
            
            Button {
                monitor.refreshNow()
                onQuickAction(.refreshMetrics)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Refresh metrics now")
        }
    }
    
    // MARK: - Empty State
    private var emptyStateNotice: some View {
        VStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No Metrics Enabled")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Open Settings > Menu Bar & Widget to select visible metrics.")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 1. Compact Layout (Clean Badge Grid)
    private func compactLayoutGrid(metrics: [WidgetMetricId]) -> some View {
        let visibleCount = min(metrics.count, preferences.maxVisibleRows * 2)
        let displayed = Array(metrics.prefix(visibleCount))
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: preferences.compactSpacing ? 4 : 6) {
            ForEach(displayed) { id in
                let item = preferences.extract(metric: id, from: monitor.snapshot)
                Button {
                    onNavigateToSection(item.dashboardSection)
                } label: {
                    HStack(spacing: 6) {
                        if preferences.showIcons {
                            Image(systemName: item.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(colorForCategory(item.category))
                                .frame(width: 14)
                        }
                        
                        if preferences.showLabels {
                            Text(item.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text(item.formattedValue)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(item.isAvailable ? AppTheme.textPrimary : AppTheme.textTertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(hoveredMetricId == id ? AppTheme.electricBlue.opacity(0.12) : AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(hoveredMetricId == id ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHov in
                    hoveredMetricId = isHov ? id : nil
                }
                .help(item.availabilityNote ?? "\(item.title): \(item.formattedValue) (Click to open dashboard)")
            }
        }
    }
    
    // MARK: - 2. Balanced Layout (Cards with Values & Progress Bars)
    private func balancedLayoutList(metrics: [WidgetMetricId]) -> some View {
        let visibleCount = min(metrics.count, preferences.maxVisibleRows)
        let displayed = Array(metrics.prefix(visibleCount))
        
        return VStack(spacing: preferences.compactSpacing ? 5 : 7) {
            ForEach(displayed) { id in
                let item = preferences.extract(metric: id, from: monitor.snapshot)
                Button {
                    onNavigateToSection(item.dashboardSection)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if preferences.showIcons {
                                Image(systemName: item.icon)
                                    .font(.system(size: 11))
                                    .foregroundStyle(colorForCategory(item.category))
                                    .frame(width: 14)
                            }
                            
                            if preferences.showLabels {
                                Text(item.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            
                            Spacer()
                            
                            Text(item.formattedValue)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(item.isAvailable ? AppTheme.textPrimary : AppTheme.textTertiary)
                            
                            if let sec = item.secondaryValue, !sec.isEmpty {
                                Text(sec)
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                        
                        if preferences.showProgressBars, let p = item.progress {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(AppTheme.chartTrack)
                                        .frame(height: 3)
                                    
                                    Capsule()
                                        .fill(colorForCategory(item.category))
                                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(p))), height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(hoveredMetricId == id ? AppTheme.electricBlue.opacity(0.10) : AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(hoveredMetricId == id ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHov in
                    hoveredMetricId = isHov ? id : nil
                }
                .help(item.availabilityNote ?? "\(item.title) — Click to view in main window")
            }
        }
    }
    
    // MARK: - 3. Detailed Layout (Full Rows with Sparklines & Details)
    private func detailedLayoutList(metrics: [WidgetMetricId]) -> some View {
        let visibleCount = min(metrics.count, preferences.maxVisibleRows)
        let displayed = Array(metrics.prefix(visibleCount))
        
        return VStack(spacing: preferences.compactSpacing ? 6 : 8) {
            ForEach(displayed) { id in
                let item = preferences.extract(metric: id, from: monitor.snapshot)
                Button {
                    onNavigateToSection(item.dashboardSection)
                } label: {
                    HStack(spacing: 8) {
                        if preferences.showIcons {
                            Image(systemName: item.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(colorForCategory(item.category))
                                .frame(width: 18)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            if let sec = item.secondaryValue {
                                Text(sec)
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        // Sparkline trend if available
                        if preferences.showTrendCharts, let series = item.sparkline, series.count >= 2 {
                            miniSparkline(data: series, color: colorForCategory(item.category))
                                .frame(width: 44, height: 16)
                        }
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.formattedValue)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(item.isAvailable ? AppTheme.textPrimary : AppTheme.textTertiary)
                            
                            if !item.isAvailable {
                                Text("N/A")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(AppTheme.warningAmber)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(hoveredMetricId == id ? AppTheme.electricBlue.opacity(0.12) : AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(hoveredMetricId == id ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHov in
                    hoveredMetricId = isHov ? id : nil
                }
                .help(item.availabilityNote ?? "\(item.title): \(item.formattedValue) (Click to inspect)")
            }
        }
    }
    
    // MARK: - Mini Sparkline Chart
    private func miniSparkline(data: [Double], color: Color) -> some View {
        let maxVal = max(data.max() ?? 100.0, 1.0)
        let normalized = data.suffix(15).map { $0 / maxVal }
        
        return GeometryReader { geo in
            Path { path in
                guard normalized.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(normalized.count - 1)
                for (i, val) in normalized.enumerated() {
                    let pt = CGPoint(
                        x: CGFloat(i) * stepX,
                        y: geo.size.height * CGFloat(1.0 - max(0.0, min(1.0, val)))
                    )
                    if i == 0 {
                        path.move(to: pt)
                    } else {
                        path.addLine(to: pt)
                    }
                }
            }
            .stroke(color, lineWidth: 1.2)
        }
    }
    
    // MARK: - Configurable Quick Actions Footer
    private var quickActionsFooter: some View {
        HStack(spacing: 6) {
            ForEach(preferences.enabledQuickActions) { action in
                Button {
                    handleQuickAction(action)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: action.icon)
                            .font(.system(size: 11))
                        Text(action.title)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(AppTheme.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .foregroundStyle(action == .quit ? AppTheme.dangerRed : AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(action.title)
            }
        }
    }
    
    private func handleQuickAction(_ action: WidgetQuickActionId) {
        if action == .openCleaner {
            showCleanerConfirmation = true
        } else {
            onQuickAction(action)
        }
    }
    
    private func colorForCategory(_ category: WidgetMetricCategory) -> Color {
        switch category {
        case .cpu: return AppTheme.electricBlue
        case .memory: return AppTheme.electricCyan
        case .gpu: return AppTheme.purpleAccent
        case .thermal: return AppTheme.orangeAccent
        case .battery: return AppTheme.matrixGreen
        case .storage: return AppTheme.warningAmber
        case .network: return AppTheme.successGreen
        case .system: return AppTheme.textSecondary
        }
    }
}
