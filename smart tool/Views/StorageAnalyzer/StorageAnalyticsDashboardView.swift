//
//  StorageAnalyticsDashboardView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct StorageAnalyticsDashboardView: View {
    @ObservedObject var service = StorageAnalyticsService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Top Header Toolbar
                topHeaderSection
                
                // Summary Metric Cards (Adaptive Grid)
                summaryCardsGrid
                
                // Prominent Storage Composition Bar
                StorageCompositionBarView()
                
                // Interactive Treemap
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Interactive Storage Treemap")
                                .font(AppTypography.font(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Tile areas are proportional to size. Click any category or folder to drill down into subdirectories.")
                                .font(AppTypography.font(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    
                    TreemapView()
                }
                .smartCard()
                
                // Charts Section: Donut Chart & Rankings (Adaptive Two Column)
                AdaptiveTwoColumnLayout(spacing: 16) {
                    StorageCategoryDonutChart()
                } right: {
                    LargestFoldersBarChart()
                }
                
                AdaptiveTwoColumnLayout(spacing: 16) {
                    LargestFilesBarChart()
                } right: {
                    HistoricalStorageTrendView()
                }
                
                // Searchable File & Folder Explorer
                StorageExplorerTableView()
                
                // Inaccessible Locations Notice (if any)
                if !service.inaccessibleLocations.isEmpty {
                    inaccessibleLocationsCard
                }
            }
            .padding(24)
        }
        .background(AppTheme.graphiteCanvas)
        .onAppear {
            if service.totalScannedBytes == 0 && !service.isScanning {
                service.startScan()
            }
        }
    }
    
    // MARK: - Top Header Section
    private var topHeaderSection: some View {
        AdaptivePageHeader(
            title: "Storage Analytics",
            subtitle: "Comprehensive visual breakdown of disk consumption, file types, and space hogs across mounted volumes"
        ) {
            headerActionsToolbar
        }
    }
    
    private var headerActionsToolbar: some View {
        ViewThatFits(in: .horizontal) {
            // Wide toolbar: All inline controls
            HStack(spacing: 10) {
                volumeSelectorMenu
                scopePicker
                scanActionButton
            }
            
            // Compact toolbar: Volume + Action, scope in submenu or wrapped
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    volumeSelectorMenu
                    scanActionButton
                }
                scopePicker
            }
        }
    }
    
    private var volumeSelectorMenu: some View {
        Menu {
            ForEach(service.mountedVolumes) { vol in
                Button {
                    service.selectedVolume = vol
                    service.customDirectoryURL = nil
                    service.startScan()
                } label: {
                    HStack {
                        Text(vol.name)
                        if service.selectedVolume?.id == vol.id && service.customDirectoryURL == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Analyze Specific Folder...") {
                service.selectCustomFolder()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: service.customDirectoryURL != nil ? "folder.fill" : "internaldrive.fill")
                    .foregroundStyle(AppTheme.neonCyan)
                Text(service.customDirectoryURL?.lastPathComponent ?? service.selectedVolume?.name ?? "Macintosh HD")
                    .font(AppTypography.font(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppTheme.cardBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
        }
        .menuStyle(.borderlessButton)
    }
    
    private var scopePicker: some View {
        Picker("Scope", selection: $service.scanMode) {
            ForEach(StorageScanMode.allCases) { mode in
                Text(mode == .quick ? "Quick" : "Detailed").tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(minWidth: 120, maxWidth: 140)
    }
    
    @ViewBuilder
    private var scanActionButton: some View {
        if service.isScanning {
            Button {
                service.cancelScan()
            } label: {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Cancel")
                }
            }
            .buttonStyle(.bordered)
            .foregroundStyle(AppTheme.dangerRed)
        } else {
            Button {
                service.startScan()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Rescan")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.electricBlue)
        }
    }
    
    // MARK: - Summary Metric Cards Grid
    private var summaryCardsGrid: some View {
        let vol = service.selectedVolume
        let total = vol?.totalCapacityBytes ?? 0
        let used = vol?.usedCapacityBytes ?? 0
        let available = vol?.availableCapacityBytes ?? 0
        let usedPct = vol?.usedPercentage ?? 0.0
        let largest = service.largestFiles.first
        
        return AdaptiveCardGrid(minColumnWidth: 175, spacing: 14) {
            ResponsiveMetricCard(
                title: "Total Capacity",
                value: ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file),
                subvalue: vol?.name ?? "Macintosh HD",
                icon: "internaldrive.fill",
                tint: AppTheme.electricBlue,
                badge: "Volume",
                tooltip: "Total hardware capacity of the monitored volume"
            )
            
            ResponsiveMetricCard(
                title: "Used / Free Space",
                value: ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file),
                subvalue: "\(ByteCountFormatter.string(fromByteCount: Int64(available), countStyle: .file)) Free (\(String(format: "%.1f%%", usedPct)))",
                icon: "chart.pie.fill",
                tint: AppTheme.neonCyan,
                badge: "\(String(format: "%.0f%%", usedPct)) Used",
                tooltip: "Used space: \(ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file))\nFree space: \(ByteCountFormatter.string(fromByteCount: Int64(available), countStyle: .file))"
            )
            
            ResponsiveMetricCard(
                title: "Largest File",
                value: largest != nil ? ByteCountFormatter.string(fromByteCount: Int64(largest!.sizeBytes), countStyle: .file) : "—",
                subvalue: largest?.name ?? "None discovered",
                icon: "doc.badge.arrow.up",
                tint: AppTheme.warningAmber,
                badge: "Space Hog",
                tooltip: largest?.path ?? "No large file discovered"
            )
            
            ResponsiveMetricCard(
                title: "Scanned Content",
                value: "\(service.scanProgressCount) Files",
                subvalue: "\(service.scannedFoldersCount) Folders • \(service.lastScanTime?.formatted(date: .omitted, time: .shortened) ?? "Pending")",
                icon: "sparkle.magnifyingglass",
                tint: AppTheme.matrixGreen,
                badge: "Analyzed",
                tooltip: "\(service.scanProgressCount) files across \(service.scannedFoldersCount) directories analyzed"
            )
        }
    }
    
    // MARK: - Inaccessible Locations Card
    private var inaccessibleLocationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(AppTheme.warningAmber)
                Text("Permission Notice • Protected Directories")
                    .font(AppTypography.font(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            Text("macOS Sandbox & TCC protect certain private locations (e.g. Safari data, system security logs) unless explicitly granted Full Disk Access in macOS System Settings.")
                .font(AppTypography.font(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .smartCard()
    }
}
