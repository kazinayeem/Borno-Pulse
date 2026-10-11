//
//  ScreenTimeDashboardView.swift
//  Naem Smart Tool
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Screen Time Analytics")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    statusBadge
                }
                
                Text("Private, native on-device application tracking • Foreground attention vs idle detection")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
            
            // Actions Toolbar
            HStack(spacing: 10) {
                // Date Range Picker
                Picker("Range", selection: $tracker.selectedRange) {
                    ForEach(ScreenTimeRangeOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                
                // Tracking Pause/Resume Button
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
                
                // Master Enable / Disable Tracking
                Button {
                    tracker.isTrackingEnabled.toggle()
                } label: {
                    Label(
                        tracker.isTrackingEnabled ? "Stop" : "Start Tracking",
                        systemImage: tracker.isTrackingEnabled ? "stop.fill" : "record.circle"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(tracker.isTrackingEnabled ? AppTheme.cardBackgroundSecondary : AppTheme.matrixGreen)
                
                // Export Menu (CSV & PDF)
                Menu {
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
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                
                // Privacy & Settings Sheet
                Button {
                    showingExclusionsSheet = true
                } label: {
                    Image(systemName: "hand.raised.shield")
                        .font(.system(size: 13))
                }
                .buttonStyle(.bordered)
                .help("Privacy and excluded applications")
            }
        }
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
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
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
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
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
