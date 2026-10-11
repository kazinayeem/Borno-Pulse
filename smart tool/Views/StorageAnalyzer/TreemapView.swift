//
//  TreemapView.swift
//  Naem Smart Tool
//

import SwiftUI

public struct TreemapView: View {
    @ObservedObject var service = StorageAnalyticsService.shared
    @State private var hoveredTile: TreemapTile?
    @State private var hoverLocation: CGPoint = .zero
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header & Breadcrumbs Toolbar
            HStack(spacing: 8) {
                // Back Button
                Button {
                    service.navigateUp()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(service.breadcrumbTrail.count <= 1)
                
                // Breadcrumbs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(service.breadcrumbTrail.enumerated()), id: \.element.id) { index, node in
                            Button {
                                service.navigateToBreadcrumb(at: index)
                            } label: {
                                Text(node.name.isEmpty ? "Root" : node.name)
                                    .font(.system(size: 11, weight: index == service.breadcrumbTrail.count - 1 ? .bold : .medium))
                                    .foregroundStyle(index == service.breadcrumbTrail.count - 1 ? AppTheme.electricBlue : AppTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            
                            if index < service.breadcrumbTrail.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Reset Button
                Button {
                    service.resetTreemapView()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(service.breadcrumbTrail.count <= 1)
                
                // Full-screen / Expand Toggle
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        service.isTreemapExpanded.toggle()
                    }
                } label: {
                    Image(systemName: service.isTreemapExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help(service.isTreemapExpanded ? "Collapse Treemap" : "Expand Treemap")
            }
            .padding(.horizontal, 4)
            
            // Canvas Area
            GeometryReader { geo in
                let frame = geo.frame(in: .local)
                ZStack(alignment: .topLeading) {
                    // Tiles Canvas
                    if service.treemapTiles.isEmpty {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.02))
                            VStack(spacing: 8) {
                                Image(systemName: "square.grid.3x3.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppTheme.textTertiary)
                                Text(service.isScanning ? "Generating Treemap..." : "Scan a volume to render treemap")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    } else {
                        ForEach(service.treemapTiles) { tile in
                            tileView(for: tile)
                        }
                    }
                    
                    // Hover Tooltip Popover
                    if let hovered = hoveredTile {
                        tooltipView(for: hovered)
                            .position(
                                x: min(max(hoverLocation.x, 100), frame.width - 100),
                                y: max(hoverLocation.y - 42, 30)
                            )
                            .transition(.opacity)
                    }
                }
                .onAppear {
                    service.recomputeTreemap(bounds: CGRect(origin: .zero, size: geo.size))
                }
                .onChange(of: geo.size) { newSize in
                    service.recomputeTreemap(bounds: CGRect(origin: .zero, size: newSize))
                }
            }
            .frame(height: service.isTreemapExpanded ? 640 : 380)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Tile Component
    @ViewBuilder
    private func tileView(for tile: TreemapTile) -> some View {
        let isHovered = hoveredTile?.id == tile.id
        let fitsLabel = tile.rect.width > 55 && tile.rect.height > 34
        let fitsSub = tile.rect.width > 70 && tile.rect.height > 52
        
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tile.category.color.opacity(isHovered ? 0.35 : 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            isHovered ? Color.white : tile.category.color.opacity(0.55),
                            lineWidth: isHovered ? 2 : 1
                        )
                )
            
            if fitsLabel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tile.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    
                    if fitsSub {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(tile.sizeBytes), countStyle: .file))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Text(String(format: "%.1f%%", tile.percentage))
                            .font(.system(size: 8))
                            .foregroundStyle(tile.category.color)
                    }
                }
                .padding(6)
            }
        }
        .frame(width: max(0, tile.rect.width - 2), height: max(0, tile.rect.height - 2))
        .position(x: tile.rect.midX, y: tile.rect.midY)
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.15)) {
                if inside {
                    hoveredTile = tile
                    hoverLocation = CGPoint(x: tile.rect.midX, y: tile.rect.minY)
                } else if hoveredTile?.id == tile.id {
                    hoveredTile = nil
                }
            }
        }
        .onTapGesture {
            // Find corresponding node to drill down
            if let nodeID = tile.nodeID,
               let current = service.currentDrillDownNode,
               let targetNode = current.children.first(where: { $0.id == nodeID }),
               targetNode.isDirectory {
                service.drillDown(to: targetNode)
            }
        }
    }
    
    // MARK: - Tooltip Component
    private func tooltipView(for tile: TreemapTile) -> some View {
        VStack(spacing: 3) {
            Text(tile.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            HStack(spacing: 6) {
                Text(ByteCountFormatter.string(fromByteCount: Int64(tile.sizeBytes), countStyle: .file))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.neonCyan)
                Text("•")
                    .font(.system(size: 8))
                    .foregroundStyle(.gray)
                Text(String(format: "%.1f%% of view", tile.percentage))
                    .font(.system(size: 9))
                    .foregroundStyle(tile.category.color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
    }
}
