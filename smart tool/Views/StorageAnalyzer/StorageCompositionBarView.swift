//
//  StorageCompositionBarView.swift
//  Borno Pulse
//

import SwiftUI

public struct StorageCompositionBarView: View {
    @ObservedObject var service = StorageAnalyticsService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let volume = service.selectedVolume
            let total = volume?.totalCapacityBytes ?? 1
            let available = volume?.availableCapacityBytes ?? 0
            let used = volume?.usedCapacityBytes ?? 0
            let scanned = service.totalScannedBytes
            let unclassified = used > scanned ? (used - scanned) : 0
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Filesystem vs. Scanned Storage Composition")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Volume: \(volume?.name ?? "Macintosh HD") (\(volume?.fileSystemType ?? "APFS"))")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file) + " Used")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.electricBlue)
                    Text("•")
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(available), countStyle: .file) + " Free")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.matrixGreen)
                }
            }
            
            // Prominent Stacked Bar
            GeometryReader { geo in
                let w = geo.size.width
                let scannedRatio = min(1.0, Double(scanned) / Double(total))
                let unclassifiedRatio = min(1.0, Double(unclassified) / Double(total))
                let availableRatio = min(1.0, Double(available) / Double(total))
                
                let scannedWidth = max(0, w * scannedRatio)
                let unclassifiedWidth = max(0, w * unclassifiedRatio)
                let availableWidth = max(0, w * availableRatio)
                
                HStack(spacing: 2) {
                    // Scanned Accessible Files
                    if scannedWidth > 0 {
                        Rectangle()
                            .fill(AppTheme.electricBlue)
                            .frame(width: scannedWidth)
                    }
                    
                    // Unclassified / Protected System Space
                    if unclassifiedWidth > 0 {
                        Rectangle()
                            .fill(Color.purple.opacity(0.75))
                            .frame(width: unclassifiedWidth)
                    }
                    
                    // Available Free Storage
                    if availableWidth > 0 {
                        Rectangle()
                            .fill(AppTheme.matrixGreen.opacity(0.85))
                            .frame(width: availableWidth)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: 14)
            
            // Composition Legend
            HStack(spacing: 16) {
                compositionPill(
                    title: "Scanned Files",
                    bytes: scanned,
                    color: AppTheme.electricBlue
                )
                
                compositionPill(
                    title: "System & Reserved Space",
                    bytes: unclassified,
                    color: Color.purple
                )
                
                compositionPill(
                    title: "Available Free Space",
                    bytes: available,
                    color: AppTheme.matrixGreen
                )
                
                Spacer()
                
                Text("Total: \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            // Discrepancy Explanation Note
            Text("Note: Filesystem-reported used space and the sum of scanned files differ due to APFS purgeable snapshot blocks, System Integrity Protection (SIP) locked system binaries, and sandboxed user folders.")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .smartCard()
    }
    
    private func compositionPill(title: String, bytes: UInt64, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }
}
