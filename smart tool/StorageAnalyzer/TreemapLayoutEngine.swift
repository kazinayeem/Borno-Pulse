//
//  TreemapLayoutEngine.swift
//  Borno Pulse
//

import CoreGraphics
import Foundation

public final class TreemapLayoutEngine: Sendable {
    public static let shared = TreemapLayoutEngine()
    
    public init() {}
    
    public struct LayoutItem: Sendable {
        public let id: String
        public let name: String
        public let size: UInt64
        public let category: StorageAnalyticsCategory
        public let isDirectory: Bool
        public let nodeID: UUID?
        
        public init(
            id: String,
            name: String,
            size: UInt64,
            category: StorageAnalyticsCategory,
            isDirectory: Bool = false,
            nodeID: UUID? = nil
        ) {
            self.id = id
            self.name = name
            self.size = size
            self.category = category
            self.isDirectory = isDirectory
            self.nodeID = nodeID
        }
    }
    
    /// Computes squarified treemap tiles within the given bounding rectangle.
    /// Limits items to top `maxTiles` and aggregates the rest into an 'Other' tile.
    public func layout(
        items: [LayoutItem],
        bounds: CGRect,
        maxTiles: Int = 36
    ) -> [TreemapTile] {
        guard bounds.width > 0, bounds.height > 0, !items.isEmpty else {
            return []
        }
        
        // Filter out zero-size items and sort descending by size
        let validItems = items.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard !validItems.isEmpty else { return [] }
        
        let totalSize = validItems.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else { return [] }
        
        // Truncate and aggregate if count exceeds maxTiles
        var processedItems: [LayoutItem] = []
        if validItems.count > maxTiles {
            let primary = Array(validItems.prefix(maxTiles - 1))
            let remainder = Array(validItems.dropFirst(maxTiles - 1))
            let remainderSize = remainder.reduce(0) { $0 + $1.size }
            
            processedItems = primary
            if remainderSize > 0 {
                processedItems.append(
                    LayoutItem(
                        id: "aggregated-other",
                        name: "Other (\(remainder.count) items)",
                        size: remainderSize,
                        category: .other,
                        isDirectory: true
                    )
                )
            }
        } else {
            processedItems = validItems
        }
        
        // Normalize areas to bounding box area
        let totalArea = Double(bounds.width * bounds.height)
        let weights: [(item: LayoutItem, normalizedArea: Double)] = processedItems.map { item in
            let area = (Double(item.size) / Double(totalSize)) * totalArea
            return (item, area)
        }
        
        var tiles: [TreemapTile] = []
        squarify(
            children: weights,
            row: [],
            bounds: bounds,
            totalSize: totalSize,
            tiles: &tiles
        )
        
        return tiles
    }
    
    // MARK: - Squarify Algorithm
    private func squarify(
        children: [(item: LayoutItem, normalizedArea: Double)],
        row: [(item: LayoutItem, normalizedArea: Double)],
        bounds: CGRect,
        totalSize: UInt64,
        tiles: inout [TreemapTile]
    ) {
        guard !children.isEmpty else {
            if !row.isEmpty {
                layoutRow(row: row, bounds: bounds, totalSize: totalSize, tiles: &tiles)
            }
            return
        }
        
        let currentBounds = bounds
        let shorterEdge = min(currentBounds.width, currentBounds.height)
        guard shorterEdge > 0 else { return }
        
        let head = children[0]
        let tail = Array(children.dropFirst())
        
        var testRow = row
        testRow.append(head)
        
        if row.isEmpty || worstAspectRatio(row: testRow, sideLength: Double(shorterEdge)) <= worstAspectRatio(row: row, sideLength: Double(shorterEdge)) {
            // Keep adding to current row
            squarify(children: tail, row: testRow, bounds: currentBounds, totalSize: totalSize, tiles: &tiles)
        } else {
            // Layout current row and continue with new remaining bounds
            let remainingBounds = layoutRow(row: row, bounds: currentBounds, totalSize: totalSize, tiles: &tiles)
            squarify(children: children, row: [], bounds: remainingBounds, totalSize: totalSize, tiles: &tiles)
        }
    }
    
    @discardableResult
    private func layoutRow(
        row: [(item: LayoutItem, normalizedArea: Double)],
        bounds: CGRect,
        totalSize: UInt64,
        tiles: inout [TreemapTile]
    ) -> CGRect {
        guard !row.isEmpty, bounds.width > 0, bounds.height > 0 else { return bounds }
        
        let rowArea = row.reduce(0.0) { $0 + $1.normalizedArea }
        let isHorizontal = bounds.width >= bounds.height
        
        if isHorizontal {
            let rowWidth = rowArea / Double(bounds.height)
            let clampedRowWidth = min(rowWidth, Double(bounds.width))
            var currentY = Double(bounds.minY)
            
            for element in row {
                let tileHeight = element.normalizedArea / clampedRowWidth
                let tileRect = CGRect(
                    x: Double(bounds.minX),
                    y: currentY,
                    width: clampedRowWidth,
                    height: tileHeight
                )
                
                let percentage = (Double(element.item.size) / Double(totalSize)) * 100.0
                tiles.append(
                    TreemapTile(
                        id: element.item.id,
                        name: element.item.name,
                        sizeBytes: element.item.size,
                        percentage: percentage,
                        category: element.item.category,
                        rect: tileRect,
                        isDirectory: element.item.isDirectory,
                        nodeID: element.item.nodeID
                    )
                )
                currentY += tileHeight
            }
            
            return CGRect(
                x: bounds.minX + clampedRowWidth,
                y: bounds.minY,
                width: max(0, bounds.width - clampedRowWidth),
                height: bounds.height
            )
        } else {
            let rowHeight = rowArea / Double(bounds.width)
            let clampedRowHeight = min(rowHeight, Double(bounds.height))
            var currentX = Double(bounds.minX)
            
            for element in row {
                let tileWidth = element.normalizedArea / clampedRowHeight
                let tileRect = CGRect(
                    x: currentX,
                    y: Double(bounds.minY),
                    width: tileWidth,
                    height: clampedRowHeight
                )
                
                let percentage = (Double(element.item.size) / Double(totalSize)) * 100.0
                tiles.append(
                    TreemapTile(
                        id: element.item.id,
                        name: element.item.name,
                        sizeBytes: element.item.size,
                        percentage: percentage,
                        category: element.item.category,
                        rect: tileRect,
                        isDirectory: element.item.isDirectory,
                        nodeID: element.item.nodeID
                    )
                )
                currentX += tileWidth
            }
            
            return CGRect(
                x: bounds.minX,
                y: bounds.minY + clampedRowHeight,
                width: bounds.width,
                height: max(0, bounds.height - clampedRowHeight)
            )
        }
    }
    
    private func worstAspectRatio(row: [(item: LayoutItem, normalizedArea: Double)], sideLength: Double) -> Double {
        guard !row.isEmpty, sideLength > 0 else { return Double.infinity }
        
        let rowSum = row.reduce(0.0) { $0 + $1.normalizedArea }
        guard rowSum > 0 else { return Double.infinity }
        
        let s2 = sideLength * sideLength
        let rowSum2 = rowSum * rowSum
        
        var maxRatio = 0.0
        for element in row {
            let r = element.normalizedArea
            guard r > 0 else { continue }
            let ratio1 = (s2 * r) / rowSum2
            let ratio2 = rowSum2 / (s2 * r)
            let ratio = max(ratio1, ratio2)
            if ratio > maxRatio {
                maxRatio = ratio
            }
        }
        return maxRatio
    }
}
