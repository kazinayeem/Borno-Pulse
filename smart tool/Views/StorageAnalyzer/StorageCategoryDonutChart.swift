//
//  StorageCategoryDonutChart.swift
//  Borno Pulse
//

import Charts
import SwiftUI

public struct StorageCategoryDonutChart: View {
    @ObservedObject var service = StorageAnalyticsService.shared
    @State private var selectedSector: String?
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Storage by Category")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                if service.selectedCategoryFilter != nil {
                    Button("Clear Filter") {
                        service.selectedCategoryFilter = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.neonCyan)
                }
            }
            
            let activeCategories = StorageAnalyticsCategory.allCases
                .compactMap { cat -> (cat: StorageAnalyticsCategory, size: UInt64)? in
                    guard let sz = service.categorySizes[cat], sz > 0 else { return nil }
                    return (cat, sz)
                }
                .sorted { $0.size > $1.size }
            
            if activeCategories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No category data yet")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                HStack(spacing: 16) {
                    // Donut Chart
                    Chart(activeCategories, id: \.cat.id) { item in
                        SectorMark(
                            angle: .value("Size", item.size),
                            innerRadius: .ratio(0.62),
                            angularInset: 1.5
                        )
                        .cornerRadius(3)
                        .foregroundStyle(item.cat.color)
                        .opacity(service.selectedCategoryFilter == nil || service.selectedCategoryFilter == item.cat ? 1.0 : 0.3)
                    }
                    .chartAngleSelection(value: $selectedSector)
                    .frame(width: 140, height: 140)
                    
                    // Legend Grid
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(activeCategories.prefix(6), id: \.cat.id) { item in
                            Button {
                                if service.selectedCategoryFilter == item.cat {
                                    service.selectedCategoryFilter = nil
                                } else {
                                    service.selectedCategoryFilter = item.cat
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(item.cat.color)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(item.cat.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(service.selectedCategoryFilter == item.cat ? AppTheme.textPrimary : AppTheme.textSecondary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    let pct = service.totalScannedBytes > 0 ? (Double(item.size) / Double(service.totalScannedBytes)) * 100.0 : 0.0
                                    Text(String(format: "%.1f%%", pct))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(item.cat.color)
                                    
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file))
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.textTertiary)
                                        .frame(width: 58, alignment: .trailing)
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 4)
                                .background(service.selectedCategoryFilter == item.cat ? AppTheme.selectionBackground : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .smartCard()
    }
}
