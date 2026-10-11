//
//  StorageAnalyzerView.swift
//  Borno Pulse
//

import SwiftUI

public struct StorageAnalyzerView: View {
    @ObservedObject var service = StorageAnalyzerService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            topToolbar
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Category Distribution Grid
                    categoryDistributionSection
                    
                    // Large Files Section
                    largeFilesSection
                }
                .padding(20)
            }
        }
        .onAppear {
            if service.totalScannedFiles == 0 && !service.isScanning {
                service.startScan()
            }
        }
    }
    
    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing Folder")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(AppTheme.electricBlue)
                    Text(service.selectedDirectory.lastPathComponent)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            
            Button("Change Folder...") {
                service.selectCustomDirectory()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            if service.isScanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("\(service.scanProgressCount) files scanned")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Button("Cancel") {
                        service.cancelScan()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.dangerRed)
                }
            } else {
                Button {
                    service.startScan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackgroundSecondary)
    }
    
    // MARK: - Category Distribution
    private var categoryDistributionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Category Space Allocation")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("Total: \(Formatters.bytes(service.totalScannedBytes)) across \(service.totalScannedFiles) files")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            let columns = [GridItem(.adaptive(minimum: 180), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(StorageCategory.allCases) { cat in
                    let size = service.categorySizes[cat] ?? 0
                    let pct = service.totalScannedBytes > 0 ? (Double(size) / Double(service.totalScannedBytes)) * 100.0 : 0.0
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: cat.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.electricBlue)
                            Text(cat.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(Formatters.percentage(pct, decimals: 0))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        GaugeBar(
                            value: pct / 100.0,
                            gradient: AppTheme.blueGradient,
                            height: 4
                        )
                        
                        Text(Formatters.bytes(size))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .smartCard()
    }
    
    // MARK: - Large Files Section
    private var largeFilesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Largest Files Discovered (> 10 MB)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(service.largeFiles.count) largest items")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            if service.largeFiles.isEmpty {
                Text(service.isScanning ? "Scanning for large files..." : "No files larger than 10 MB found in this directory.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(service.largeFiles.prefix(25)) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.electricBlue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                            Text(item.path)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textTertiary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text(Formatters.bytes(item.sizeBytes))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.warningAmber)
                        
                        Button {
                            service.revealInFinder(item: item)
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.electricBlue)
                        .help("Reveal in Finder")
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .smartCard()
    }
}
