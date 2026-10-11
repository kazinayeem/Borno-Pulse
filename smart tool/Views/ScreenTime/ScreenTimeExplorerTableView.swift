//
//  ScreenTimeExplorerTableView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct ScreenTimeExplorerTableView: View {
    @ObservedObject var tracker = ScreenTimeTrackerService.shared
    
    public enum SortColumn: String, CaseIterable {
        case duration = "Duration"
        case activePercentage = "Active %"
        case name = "Application"
        case sessions = "Sessions"
    }
    
    @State private var sortColumn: SortColumn = .duration
    @State private var sortAscending: Bool = false
    
    public init() {}
    
    public var body: some View {
        let apps = sortedApps
        let maxDuration = apps.first?.totalDuration ?? 1.0
        
        VStack(alignment: .leading, spacing: 14) {
            // Header Controls
            ViewThatFits(in: .horizontal) {
                // Wide: title on left, all search and filters on right
                HStack(spacing: 10) {
                    explorerTitleSection(count: apps.count)
                    Spacer()
                    searchAndFiltersBar
                }
                
                // Compact: title on top, filters wrapped below
                VStack(alignment: .leading, spacing: 10) {
                    explorerTitleSection(count: apps.count)
                    searchAndFiltersBar
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Scrollable Table Container
            AdaptiveTableContainer(minWidth: 800) {
                VStack(spacing: 6) {
                    // Table Header Bar
                    HStack(spacing: 8) {
                        tableHeader(title: "Application", column: .name, width: 220, alignment: .leading)
                        tableHeader(title: "Category", column: nil, width: 130, alignment: .leading)
                        tableHeader(title: "Total Duration", column: .duration, width: 140, alignment: .leading)
                        tableHeader(title: "Active Focus", column: nil, width: 95, alignment: .leading)
                        tableHeader(title: "Active %", column: .activePercentage, width: 80, alignment: .leading)
                        tableHeader(title: "Sessions", column: .sessions, width: 65, alignment: .leading)
                        Spacer()
                        Text("Actions")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(width: 65, alignment: .trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    // Table Rows List
                    if apps.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 26))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text("No applications match the current search or filters.")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 3) {
                                ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                                    appRow(index: index + 1, app: app, maxDuration: maxDuration)
                                }
                            }
                        }
                        .frame(maxHeight: 340)
                    }
                }
            }
        }
        .padding(16)
        .smartCard()
    }
    
    private func explorerTitleSection(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Application Usage Explorer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            
            Text("\(count) applications recorded in \(tracker.selectedRange.rawValue.lowercased())")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
    
    private var searchAndFiltersBar: some View {
        HStack(spacing: 8) {
            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
                
                TextField("Search app or bundle ID...", text: $tracker.filterSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(minWidth: 120, maxWidth: 170)
                
                if !tracker.filterSearchText.isEmpty {
                    Button {
                        tracker.filterSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Category Filter
            Picker("Category", selection: $tracker.filterCategory) {
                Text("All Categories").tag(AppUsageCategory?.none)
                ForEach(AppUsageCategory.allCases) { cat in
                    Text(cat.rawValue).tag(AppUsageCategory?.some(cat))
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 120, maxWidth: 150)
            
            // Min Duration Filter
            Picker("Min Time", selection: $tracker.minDurationSeconds) {
                Text("All Durations").tag(TimeInterval(0))
                Text("> 1 min").tag(TimeInterval(60))
                Text("> 5 min").tag(TimeInterval(300))
                Text("> 15 min").tag(TimeInterval(900))
                Text("> 1 hour").tag(TimeInterval(3600))
            }
            .pickerStyle(.menu)
            .frame(minWidth: 100, maxWidth: 120)
        }
    }
    
    // MARK: - App Row
    private func appRow(index: Int, app: AppUsageAggregate, maxDuration: TimeInterval) -> some View {
        HStack(spacing: 8) {
            // App Name + Rank + Icon
            HStack(spacing: 8) {
                Text("\(index)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(index <= 3 ? AppTheme.electricCyan : AppTheme.textTertiary)
                    .frame(width: 20, alignment: .leading)
                
                appIconView(bundleID: app.bundleIdentifier, fallbackCategory: app.category)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.appName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    
                    Text(app.bundleIdentifier)
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 220, alignment: .leading)
            
            // Category Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(app.category.color)
                    .frame(width: 6, height: 6)
                
                Text(app.category.rawValue)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 140, alignment: .leading)
            
            // Total Duration + Relative Bar
            VStack(alignment: .leading, spacing: 3) {
                Text(Formatters.duration(app.totalDuration, showSeconds: true))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                
                GeometryReader { geo in
                    let fill = maxDuration > 0 ? (app.totalDuration / maxDuration) * geo.size.width : 0
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                        Capsule()
                            .fill(app.category.color.gradient)
                            .frame(width: max(3, fill))
                    }
                }
                .frame(height: 3)
            }
            .frame(width: 150, alignment: .leading)
            
            // Active Focus
            Text(Formatters.duration(app.activeDuration))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.matrixGreen)
                .frame(width: 100, alignment: .leading)
            
            // Active %
            Text(String(format: "%.0f%%", app.activePercentage))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(app.activePercentage >= 80 ? AppTheme.matrixGreen : AppTheme.warningAmber)
                .frame(width: 90, alignment: .leading)
            
            // Sessions
            Text("\(app.sessionCount)")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 70, alignment: .leading)
            
            Spacer()
            
            // Actions
            HStack(spacing: 6) {
                // Reveal in Finder
                Button {
                    revealAppInFinder(bundleID: app.bundleIdentifier)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Locate application in Finder")
                
                // Exclude toggle
                Button {
                    tracker.toggleExclusion(for: app.bundleIdentifier)
                } label: {
                    Image(systemName: tracker.isExcluded(app.bundleIdentifier) ? "eye.slash.fill" : "eye")
                        .font(.system(size: 10))
                        .foregroundStyle(tracker.isExcluded(app.bundleIdentifier) ? AppTheme.warningAmber : AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(tracker.isExcluded(app.bundleIdentifier) ? "Include in Screen Time" : "Exclude from Screen Time")
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.015))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    // MARK: - App Icon View
    private func appIconView(bundleID: String, fallbackCategory: AppUsageCategory) -> some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let img = NSWorkspace.shared.icon(forFile: url.path)
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: fallbackCategory.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(fallbackCategory.color)
                    .frame(width: 20, height: 20)
                    .background(fallbackCategory.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
    
    private func revealAppInFinder(bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    // MARK: - Sorting Helper
    private var sortedApps: [AppUsageAggregate] {
        let list = tracker.getFilteredAppAggregates(for: tracker.selectedRange)
        return list.sorted { a, b in
            switch sortColumn {
            case .duration:
                return sortAscending ? a.totalDuration < b.totalDuration : a.totalDuration > b.totalDuration
            case .activePercentage:
                return sortAscending ? a.activePercentage < b.activePercentage : a.activePercentage > b.activePercentage
            case .name:
                return sortAscending ? a.appName.localizedCompare(b.appName) == .orderedAscending : a.appName.localizedCompare(b.appName) == .orderedDescending
            case .sessions:
                return sortAscending ? a.sessionCount < b.sessionCount : a.sessionCount > b.sessionCount
            }
        }
    }
    
    private func tableHeader(title: String, column: SortColumn?, width: CGFloat, alignment: Alignment) -> some View {
        Button {
            guard let col = column else { return }
            if sortColumn == col {
                sortAscending.toggle()
            } else {
                sortColumn = col
                sortAscending = false
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(column != nil && sortColumn == column ? AppTheme.electricCyan : AppTheme.textTertiary)
                
                if let col = column, sortColumn == col {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppTheme.electricCyan)
                }
            }
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
        .disabled(column == nil)
    }
}
