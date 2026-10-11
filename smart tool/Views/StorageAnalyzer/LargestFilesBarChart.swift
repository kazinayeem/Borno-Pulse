//
//  LargestFilesBarChart.swift
//  Borno Pulse
//

import Charts
import SwiftUI

public struct LargestFilesBarChart: View {
    @ObservedObject var service = StorageAnalyticsService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Largest Individual Files", systemImage: "doc.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                Text("Top \(min(service.largestFiles.count, 10)) heavy consumers")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            let files = Array(service.largestFiles.prefix(10))
            
            if files.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No large files (> 50MB) discovered yet")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                VStack(spacing: 8) {
                    let maxSize = Double(files.first?.sizeBytes ?? 1)
                    
                    ForEach(Array(files.enumerated()), id: \.element.id) { index, item in
                        Button {
                            service.revealInFinder(item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.textTertiary)
                                        .frame(width: 14, alignment: .trailing)
                                    
                                    Image(systemName: item.category.icon)
                                        .font(.system(size: 10))
                                        .foregroundStyle(item.category.color)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .lineLimit(1)
                                        Text(item.parentPath)
                                            .font(.system(size: 9))
                                            .foregroundStyle(AppTheme.textTertiary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(item.sizeBytes), countStyle: .file))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AppTheme.matrixGreen)
                                }
                                
                                // Normalized Bar
                                GeometryReader { barGeo in
                                    let barRatio = max(0.04, Double(item.sizeBytes) / maxSize)
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(Color.white.opacity(0.05))
                                            .frame(height: 5)
                                        
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(item.category.color)
                                            .frame(width: barGeo.size.width * barRatio, height: 5)
                                    }
                                }
                                .frame(height: 5)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color.white.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Click to reveal \(item.path) in Finder")
                    }
                }
            }
        }
        .smartCard()
    }
}
