//
//  ScreenTimeDashboardView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct ScreenTimeDashboardView: View {
    @ObservedObject var tracker = ScreenTimeTrackerService.shared
    @State private var showingExclusionsSheet: Bool = false
    @State private var bannerNotification: String? = nil
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Top Header with Controls
                headerView
                
                // Status / Export Notification Banner
                if let msg = bannerNotification {
                    notificationBanner(msg)
                }
                
                // Live Active Foreground Session Bar
                if tracker.isTrackingEnabled && !tracker.isTrackingPaused {
                    liveSessionStatusBar
                }
                
                // Summary Cards
                let stats = tracker.getStatistics()
                ScreenTimeSummaryCardsView(stats: stats, selectedRange: tracker.selectedRange)
                
                // Visualizations (Charts & Donut)
                ScreenTimeChartsSectionView()
                
                // 24-Hour Timeline Bar
                ScreenTimeTimelineView()
                
                // Website Tracking & Privacy Boundaries Card
                ScreenTimeWebsiteNoticeCard()
                
                // Searchable Applications Table
                ScreenTimeExplorerTableView()
            }
            .padding(20)
        }
        .background(AppTheme.graphiteCanvas)
        .sheet(isPresented: $showingExclusionsSheet) {
            ScreenTimeExclusionsSheet()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        AdaptivePageHeader(
            title: "Screen Time Analytics",
            subtitle: "Private, native on-device application tracking • Foreground attention vs idle detection",
            leadingExtra: { statusBadge }
        ) {
            headerActionsToolbar
        }
    }
    
    private var headerActionsToolbar: some View {
        ViewThatFits(in: .horizontal) {
            // Wide toolbar: full inline controls
            HStack(spacing: 8) {
                rangePicker
                trackingControls
                exportMenu
                exclusionsButton
            }
            
            // Compact toolbar: primary controls with overflow menu
            HStack(spacing: 8) {
                rangePicker
                trackingControls
                
                Menu {
                    exportMenuItems
                    Divider()
                    Button {
                        showingExclusionsSheet = true
                    } label: {
                        Label("Excluded Applications", systemImage: "shield.lefthalf.filled")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var rangePicker: some View {
        Picker("Range", selection: $tracker.selectedRange) {
            ForEach(ScreenTimeRangeOption.allCases) { opt in
                Text(opt.rawValue).tag(opt)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }
    
    private var trackingControls: some View {
        HStack(spacing: 6) {
            if tracker.isTrackingEnabled {
                Button {
                    if tracker.isTrackingPaused {
                        tracker.resumeTracking()
                    } else {
                        tracker.pauseTracking()
                    }
                } label: {
                    Label(
                        tracker.isTrackingPaused ? "Resume" : "Pause",
                        systemImage: tracker.isTrackingPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(.bordered)
                .help(tracker.isTrackingPaused ? "Resume tracking" : "Pause tracking")
            }
            
            if tracker.isTrackingEnabled {
                Button {
                    tracker.isTrackingEnabled = false
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    tracker.isTrackingEnabled = true
                } label: {
                    Label("Start Tracking", systemImage: "record.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.successFill)
            }
        }
    }
    
    private var exportMenu: some View {
        Menu {
            exportMenuItems
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.bordered)
    }
    
    @ViewBuilder
    private var exportMenuItems: some View {
        Button {
            exportCSVReport()
        } label: {
            Label("Export Data as CSV", systemImage: "tablecells")
        }
        
        Button {
            exportPDFReport()
        } label: {
            Label("Export PDF Audit Report", systemImage: "doc.richtext")
        }
        
        Divider()
        
        Button {
            tracker.generateSampleHistoryIfEmpty()
            bannerNotification = "Sample 30-day activity dataset loaded for preview."
        } label: {
            Label("Seed 30-Day Demo Data", systemImage: "sparkles")
        }
    }
    
    private var exclusionsButton: some View {
        Button {
            showingExclusionsSheet = true
        } label: {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 13))
        }
        .buttonStyle(.bordered)
        .help("Privacy and excluded applications")
    }
    
    // MARK: - Status Badge
    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(
                    !tracker.isTrackingEnabled ? AppTheme.dangerRed :
                    tracker.isTrackingPaused ? AppTheme.warningAmber :
                    tracker.isCurrentlyIdle ? AppTheme.warningAmber : AppTheme.matrixGreen
                )
                .frame(width: 7, height: 7)
            
            Text(
                !tracker.isTrackingEnabled ? "Disabled" :
                tracker.isTrackingPaused ? "Paused" :
                tracker.isCurrentlyIdle ? "Idle (Away)" : "Live Tracking"
            )
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(
                !tracker.isTrackingEnabled ? AppTheme.dangerRed :
                tracker.isTrackingPaused ? AppTheme.warningAmber :
                tracker.isCurrentlyIdle ? AppTheme.warningAmber : AppTheme.matrixGreen
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }
    
    // MARK: - Live Active Session Bar
    private var liveSessionStatusBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: tracker.currentAppCategory.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(tracker.currentAppCategory.color)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Active App:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                        
                        Text(tracker.currentAppName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    
                    Text("\(tracker.currentAppCategory.rawValue) • \(tracker.currentAppBundleID)")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Text("Focus Time:")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    Text(Formatters.duration(tracker.currentSessionDuration, showSeconds: true))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.electricCyan)
                }
                
                HStack(spacing: 6) {
                    Text("Input Idle:")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    Text("\(Int(tracker.currentSystemIdleSeconds))s")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(tracker.isCurrentlyIdle ? AppTheme.warningAmber : AppTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Notification Banner
    private func notificationBanner(_ msg: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.successGreen)
            Text(msg)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Button {
                bannerNotification = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(AppTheme.successGreen.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - CSV Export Handler
    private func exportCSVReport() {
        let csv = tracker.generateCSVReport(for: tracker.selectedRange)
        let savePanel = NSSavePanel()
        savePanel.title = "Export Screen Time CSV"
        savePanel.nameFieldStringValue = "ScreenTime_\(tracker.selectedRange.rawValue.replacingOccurrences(of: " ", with: "_")).csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                bannerNotification = "Screen Time data successfully exported to \(url.lastPathComponent)"
            } catch {
                bannerNotification = "Failed writing CSV: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - PDF Export Handler
    private func exportPDFReport() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Screen Time PDF Report"
        savePanel.nameFieldStringValue = "ScreenTime_Audit_Report.pdf"
        savePanel.allowedContentTypes = [.pdf]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let stats = tracker.getStatistics()
                let topApps = tracker.getFilteredAppAggregates(for: tracker.selectedRange)
                let categories = tracker.getCategoryBreakdown(for: tracker.selectedRange)
                
                try ScreenTimePDFReportGenerator.shared.generatePDFReport(
                    range: tracker.selectedRange,
                    stats: stats,
                    topApps: topApps,
                    categories: categories,
                    to: url
                )
                bannerNotification = "Screen Time PDF report generated at \(url.lastPathComponent)"
            } catch {
                bannerNotification = "Failed generating PDF: \(error.localizedDescription)"
            }
        }
    }
}
