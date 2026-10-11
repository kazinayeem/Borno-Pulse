//
//  StorageExplorerTableView.swift
//  Borno Pulse
//

import SwiftUI

public struct StorageExplorerTableView: View {
    @ObservedObject var service = StorageAnalyticsService.shared
    @State private var itemToCleanup: StorageAnalyticsItem?
    @State private var showingCleanupAlert = false
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Table Header & Search Controls
            ViewThatFits(in: .horizontal) {
                // Wide: Title on left, Search + Export on right
                HStack(spacing: 12) {
                    tableTitleSection
                    Spacer()
                    searchAndExportToolbar
                }
                
                // Compact: Title on top, Search + Export wrapped below
                VStack(alignment: .leading, spacing: 10) {
                    tableTitleSection
                    searchAndExportToolbar
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Filter Pills Bar (Responsive wrapping)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    itemTypeFilterPicker
                    minSizeFilterPicker
                    displayLimitPicker
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    itemTypeFilterPicker
                    HStack(spacing: 10) {
                        minSizeFilterPicker
                        displayLimitPicker
                    }
                }
            }
            
            // Clean Status Notice (if any)
            if let msg = service.cleanupSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.matrixGreen)
                    Text(msg)
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Button("Dismiss") {
                        service.cleanupSuccessMessage = nil
                    }
                    .buttonStyle(.plain)
                    .font(AppTypography.font(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(8)
                .background(AppTheme.matrixGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            
            // Horizontally Scrollable Table Container
            AdaptiveTableContainer(minWidth: 700) {
                VStack(spacing: 4) {
                    // Table Columns Header
                    HStack(spacing: 12) {
                        columnHeader("Name", column: .name)
                            .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
                        columnHeader("Type", column: .type)
                            .frame(width: 110, alignment: .leading)
                        columnHeader("Size", column: .size)
                            .frame(width: 85, alignment: .trailing)
                        columnHeader("% Total", column: .percentage)
                            .frame(width: 65, alignment: .trailing)
                        columnHeader("Modified", column: .date)
                            .frame(width: 95, alignment: .trailing)
                        Text("Actions")
                            .font(AppTypography.font(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    
                    // Table Items
                    let items = service.filteredExplorerItems
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text("No items matching current filters")
                                .font(AppTypography.font(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                    } else {
                        LazyVStack(spacing: 4) {
                            ForEach(items) { item in
                                tableRow(for: item)
                            }
                        }
                    }
                }
            }
        }
        .smartCard()
        .alert("Review Item for Safe Cleanup", isPresented: $showingCleanupAlert) {
            Button("Move to Trash", role: .destructive) {
                if let item = itemToCleanup {
                    _ = service.deleteEligibleItem(item: item)
                    itemToCleanup = nil
                }
            }
            Button("Cancel", role: .cancel) {
                itemToCleanup = nil
            }
        } message: {
            if let item = itemToCleanup {
                Text("\(service.cleanupExplanation(for: item))\n\nTarget: \(item.path)\nSize: \(ByteCountFormatter.string(fromByteCount: Int64(item.sizeBytes), countStyle: .file))")
            } else {
                Text("Are you sure you want to clean this item?")
            }
        }
    }
    
    // MARK: - Subcomponents
    private var tableTitleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Largest Files & Folders Explorer")
                .font(AppTypography.font(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Displaying \(service.filteredExplorerItems.count) items matching current filters")
                .font(AppTypography.font(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
    
    private var searchAndExportToolbar: some View {
        HStack(spacing: 8) {
            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textTertiary)
                TextField("Search file name or path...", text: $service.searchText)
                    .textFieldStyle(.plain)
                    .font(AppTypography.font(size: 12))
                if !service.searchText.isEmpty {
                    Button {
                        service.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .frame(minWidth: 140, maxWidth: 220)
            
            // Export CSV Button
            Button {
                service.exportScanResultsCSV()
            } label: {
                Label("Export CSV", systemImage: "tablecells.badge.ellipsis")
                    .font(AppTypography.font(size: 11))
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var itemTypeFilterPicker: some View {
        Picker("Item Type", selection: $service.itemTypeFilter) {
            ForEach(StorageAnalyticsService.ItemTypeFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .frame(minWidth: 160, maxWidth: 220)
    }
    
    private var minSizeFilterPicker: some View {
        Picker("Min Size", selection: $service.minimumSizeFilter) {
            ForEach(StorageAnalyticsService.MinimumSizeFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 110, maxWidth: 130)
    }
    
    private var displayLimitPicker: some View {
        Picker("Limit", selection: $service.displayLimit) {
            ForEach(StorageAnalyticsService.DisplayLimit.allCases) { limit in
                Text(limit.rawValue).tag(limit)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 90, maxWidth: 110)
    }
    
    // MARK: - Row Component
    @ViewBuilder
    private func tableRow(for item: StorageAnalyticsItem) -> some View {
        HStack(spacing: 12) {
            // Name & Icon
            HStack(spacing: 8) {
                Image(systemName: item.isDirectory ? "folder.fill" : item.category.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(item.isDirectory ? AppTheme.electricBlue : item.category.color)
                    .frame(width: 14)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(AppTypography.font(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .help(item.path)
                    Text(item.parentPath)
                        .font(AppTypography.font(size: 9))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                        .help(item.path)
                }
            }
            .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
            
            // Type
            Text(item.isDirectory ? "Folder" : item.category.rawValue)
                .font(AppTypography.font(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 110, alignment: .leading)
                .lineLimit(1)
            
            // Size
            Text(ByteCountFormatter.string(fromByteCount: Int64(item.sizeBytes), countStyle: .file))
                .font(AppTypography.monospaced(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 85, alignment: .trailing)
            
            // Percentage of Total
            let pct = service.totalScannedBytes > 0 ? (Double(item.sizeBytes) / Double(service.totalScannedBytes)) * 100.0 : 0.0
            Text(String(format: "%.1f%%", pct))
                .font(AppTypography.monospaced(size: 10))
                .foregroundStyle(AppTheme.neonCyan)
                .frame(width: 65, alignment: .trailing)
            
            // Date
            Text(item.modificationDate?.formatted(date: .numeric, time: .omitted) ?? "—")
                .font(AppTypography.monospaced(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 95, alignment: .trailing)
            
            // Actions
            HStack(spacing: 6) {
                Button {
                    service.revealInFinder(item: item)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Reveal in Finder")
                
                Button {
                    service.copyPath(item: item)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Copy Path: \(item.path)")
                
                if service.isEligibleForCleanup(item: item) {
                    Button {
                        itemToCleanup = item
                        showingCleanupAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.dangerRed)
                    }
                    .buttonStyle(.borderless)
                    .help("Safe Clean to Trash")
                }
            }
            .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.015))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }
    
    private func columnHeader(_ title: String, column: StorageAnalyticsService.ExplorerSortColumn) -> some View {
        Button {
            service.toggleSort(by: column)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(AppTypography.font(size: 10, weight: .semibold))
                    .foregroundStyle(service.sortColumn == column ? AppTheme.electricBlue : AppTheme.textTertiary)
                if service.sortColumn == column {
                    Image(systemName: service.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppTheme.electricBlue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
