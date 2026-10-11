//
//  StorageExplorerTableView.swift
//  Naem Smart Tool
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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Largest Files & Folders Explorer")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Displaying \(service.filteredExplorerItems.count) items matching current filters")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                // Search Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.textTertiary)
                    TextField("Search file name or path...", text: $service.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
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
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .frame(maxWidth: 220)
                
                // Export CSV Button
                Button {
                    service.exportScanResultsCSV()
                } label: {
                    Label("Export CSV", systemImage: "tablecells.badge.ellipsis")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }
            
            // Filter Pills Bar
            HStack(spacing: 10) {
                // Item Type
                Picker("Item Type", selection: $service.itemTypeFilter) {
                    ForEach(StorageAnalyticsService.ItemTypeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 230)
                
                // Minimum Size
                Picker("Min Size", selection: $service.minimumSizeFilter) {
                    ForEach(StorageAnalyticsService.MinimumSizeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 130)
                
                // Display Limit
                Picker("Limit", selection: $service.displayLimit) {
                    ForEach(StorageAnalyticsService.DisplayLimit.allCases) { limit in
                        Text(limit.rawValue).tag(limit)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 110)
                
                Spacer()
            }
            
            // Clean Status Notice (if any)
            if let msg = service.cleanupSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.matrixGreen)
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Button("Dismiss") {
                        service.cleanupSuccessMessage = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(8)
                .background(AppTheme.matrixGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            
            // Table Columns Header
            HStack(spacing: 12) {
                columnHeader("Name", column: .name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                columnHeader("Type", column: .type)
                    .frame(width: 130, alignment: .leading)
                columnHeader("Size", column: .size)
                    .frame(width: 85, alignment: .trailing)
                columnHeader("% Total", column: .percentage)
                    .frame(width: 65, alignment: .trailing)
                columnHeader("Modified", column: .date)
                    .frame(width: 100, alignment: .trailing)
                Text("Actions")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 100, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
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
                        .font(.system(size: 11))
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Text(item.parentPath)
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Type
            Text(item.isDirectory ? "Folder" : item.category.rawValue)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 130, alignment: .leading)
                .lineLimit(1)
            
            // Size
            Text(ByteCountFormatter.string(fromByteCount: Int64(item.sizeBytes), countStyle: .file))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 85, alignment: .trailing)
            
            // Percentage of Total
            let pct = service.totalScannedBytes > 0 ? (Double(item.sizeBytes) / Double(service.totalScannedBytes)) * 100.0 : 0.0
            Text(String(format: "%.1f%%", pct))
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.neonCyan)
                .frame(width: 65, alignment: .trailing)
            
            // Date
            Text(item.modificationDate?.formatted(date: .numeric, time: .omitted) ?? "—")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 100, alignment: .trailing)
            
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
                .help("Copy Path")
                
                if service.isEligibleForCleanup(item: item) {
                    Button {
                        itemToCleanup = item
                        showingCleanupAlert = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.warningAmber)
                    }
                    .buttonStyle(.borderless)
                    .help("Review for Safe Cleanup")
                }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.015))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private func columnHeader(_ title: String, column: StorageAnalyticsService.StorageSortColumn) -> some View {
        Button {
            if service.sortColumn == column {
                service.sortAscending.toggle()
            } else {
                service.sortColumn = column
                service.sortAscending = false
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                if service.sortColumn == column {
                    Image(systemName: service.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
            }
            .foregroundStyle(service.sortColumn == column ? AppTheme.electricBlue : AppTheme.textTertiary)
        }
        .buttonStyle(.plain)
    }
}
