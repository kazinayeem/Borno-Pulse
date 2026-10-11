//
//  LargestFoldersBarChart.swift
//  Naem Smart Tool
//

import Charts
import SwiftUI

public struct LargestFoldersBarChart: View {
    @ObservedObject var service = StorageAnalyticsService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Largest Discovered Folders", systemImage: "folder.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                Text("Top \(min(service.largestFolders.count, 10)) by size")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            let folders = Array(service.largestFolders.prefix(10))
            
            if folders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No large folders discovered yet")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                VStack(spacing: 8) {
                    let maxSize = Double(folders.first?.sizeBytes ?? 1)
                    
                    ForEach(folders) { item in
                        Button {
                            service.revealInFinder(item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.electricBlue)
                                    
                                    Text(item.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(item.sizeBytes), countStyle: .file))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AppTheme.neonCyan)
                                }
                                
                                // Normalized Bar
                                GeometryReader { barGeo in
                                    let barRatio = max(0.04, Double(item.sizeBytes) / maxSize)
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(Color.white.opacity(0.05))
                                            .frame(height: 6)
                                        
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(AppTheme.blueGradient)
                                            .frame(width: barGeo.size.width * barRatio, height: 6)
                                    }
                                }
                                .frame(height: 6)
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
