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
                
                // Summary Metric Cards
                summaryCardsGrid
                
                // Prominent Storage Composition Bar
                StorageCompositionBarView()
                
                // Interactive Treemap
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Interactive Storage Treemap")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Tile areas are proportional to size. Click any category or folder to drill down into subdirectories.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    
                    TreemapView()
                }
                .smartCard()
                
                // Charts Section: Donut Chart & Rankings
                HStack(alignment: .top, spacing: 16) {
                    StorageCategoryDonutChart()
                        .frame(maxWidth: .infinity)
                    
                    LargestFoldersBarChart()
                        .frame(maxWidth: .infinity)
                }
                
                HStack(alignment: .top, spacing: 16) {
                    LargestFilesBarChart()
                        .frame(maxWidth: .infinity)
                    
                    HistoricalStorageTrendView()
                        .frame(maxWidth: .infinity)
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Analytics")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Comprehensive visual breakdown of disk consumption, file types, and space hogs across mounted volumes")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
            
            // Volume Switcher & Scan Controls
            HStack(spacing: 10) {
                // Volume Selector Menu
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
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                
                // Scan Mode Picker
                Picker("Scope", selection: $service.scanMode) {
                    ForEach(StorageScanMode.allCases) { mode in
                        Text(mode == .quick ? "Quick" : "Detailed").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                
                // Scan Action Button
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
        
        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 14) {
            summaryCard(
                title: "Total Capacity",
                value: ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file),
                subtext: vol?.name ?? "Macintosh HD",
                icon: "internaldrive.fill",
                color: AppTheme.electricBlue
            )
            
            summaryCard(
                title: "Used / Free Space",
                value: ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file),
                subtext: "\(ByteCountFormatter.string(fromByteCount: Int64(available), countStyle: .file)) Free (\(String(format: "%.1f%%", usedPct)) Used)",
                icon: "piechart.fill",
                color: AppTheme.neonCyan
            )
            
            summaryCard(
                title: "Largest File",
                value: largest != nil ? ByteCountFormatter.string(fromByteCount: Int64(largest!.sizeBytes), countStyle: .file) : "—",
                subtext: largest?.name ?? "None discovered",
                icon: "doc.badge.arrow.up",
                color: AppTheme.warningAmber
            )
            
            summaryCard(
                title: "Scanned Content",
                value: "\(service.scanProgressCount) Files",
                subtext: "\(service.scannedFoldersCount) Folders • \(service.lastScanTime?.formatted(date: .omitted, time: .shortened) ?? "Pending")",
                icon: "sparkle.magnifyingglass",
                color: AppTheme.matrixGreen
            )
        }
    }
    
    private func summaryCard(title: String, value: String, subtext: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            
            Text(subtext)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
        }
        .smartCard()
    }
    
    // MARK: - Inaccessible Locations Warning
    private var inaccessibleLocationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.warningAmber)
                Text("Inaccessible Filesystem Locations")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            Text("The following directories were skipped because macOS System Integrity Protection (SIP) or file privacy sandbox permissions restrict access:")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
            
            Text(service.inaccessibleLocations.joined(separator: ", "))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .smartCard()
    }
}
