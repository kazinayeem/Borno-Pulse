//
//  PDFEditorGeometry.swift
//  Borno Pulse
//
//  Pure geometry used by the PDF editor. Every value here is in PDF page space
//  (points, origin bottom-left, y up). View/screen conversion is done exclusively
//  through PDFView.convert(_:from:) / convert(_:to:) in the canvas.
//

import CoreGraphics
import Foundation

public enum PDFEditorGeometry {

    public enum FitMode: Sendable {
        case page
        case width
    }

    /// Corner order (in the unrotated local frame): bottom-left, bottom-right, top-right, top-left.
    public static let cornerSigns: [CGPoint] = [
        CGPoint(x: -1, y: -1), CGPoint(x: 1, y: -1), CGPoint(x: 1, y: 1), CGPoint(x: -1, y: 1)
    ]

    public static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    public static func center(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    public static func normalizedDegrees(_ degrees: CGFloat) -> CGFloat {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        if abs(value - 360) < 0.0001 { value = 0 }
        return value
    }

    /// Rotates `vector` clockwise (as seen on screen) by `degrees` in a y-up space.
    public static func rotateClockwise(_ vector: CGPoint, degrees: CGFloat) -> CGPoint {
        let radians = -degrees * .pi / 180
        return CGPoint(
            x: vector.x * cos(radians) - vector.y * sin(radians),
            y: vector.x * sin(radians) + vector.y * cos(radians)
        )
    }

    public static func rotatedCorners(center: CGPoint, size: CGSize, degrees: CGFloat) -> [CGPoint] {
        cornerSigns.map { sign in
            let local = CGPoint(x: sign.x * size.width / 2, y: sign.y * size.height / 2)
            let rotated = rotateClockwise(local, degrees: degrees)
            return CGPoint(x: center.x + rotated.x, y: center.y + rotated.y)
        }
    }

    public static func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public static func rotatedBounds(center: CGPoint, size: CGSize, degrees: CGFloat) -> CGRect {
        boundingRect(of: rotatedCorners(center: center, size: size, degrees: degrees))
    }

    /// Hit test against the rotated rectangle rather than its axis-aligned bounding box.
    public static func contains(_ point: CGPoint, center: CGPoint, size: CGSize, degrees: CGFloat, tolerance: CGFloat = 0) -> Bool {
        let offset = CGPoint(x: point.x - center.x, y: point.y - center.y)
        let local = rotateClockwise(offset, degrees: -degrees)
        return abs(local.x) <= size.width / 2 + tolerance && abs(local.y) <= size.height / 2 + tolerance
    }

    /// Resizes a (possibly rotated) rectangle by dragging one of its corners. The opposite
    /// corner stays fixed. With `lockAspect` the original width/height ratio is preserved.
    public static func resize(
        center: CGPoint,
        size: CGSize,
        degrees: CGFloat,
        corner: Int,
        to point: CGPoint,
        lockAspect: Bool,
        minimumSize: CGFloat = 8
    ) -> (center: CGPoint, size: CGSize) {
        let sign = cornerSigns[((corner % 4) + 4) % 4]
        let anchorLocal = CGPoint(x: -sign.x * size.width / 2, y: -sign.y * size.height / 2)
        let offset = CGPoint(x: point.x - center.x, y: point.y - center.y)
        let dragLocal = rotateClockwise(offset, degrees: -degrees)

        var width = max(minimumSize, (dragLocal.x - anchorLocal.x) * sign.x)
        var height = max(minimumSize, (dragLocal.y - anchorLocal.y) * sign.y)

        if lockAspect, size.width > 0, size.height > 0 {
            let scale = max(width / size.width, height / size.height)
            let minScale = max(minimumSize / size.width, minimumSize / size.height)
            let finalScale = max(scale, minScale)
            width = size.width * finalScale
            height = size.height * finalScale
        }

        let newCornerLocal = CGPoint(x: anchorLocal.x + sign.x * width, y: anchorLocal.y + sign.y * height)
        let newCenterLocal = CGPoint(x: (anchorLocal.x + newCornerLocal.x) / 2, y: (anchorLocal.y + newCornerLocal.y) / 2)
        let rotatedCenter = rotateClockwise(newCenterLocal, degrees: degrees)
        return (CGPoint(x: center.x + rotatedCenter.x, y: center.y + rotatedCenter.y), CGSize(width: width, height: height))
    }

    public static func distance(from point: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - a.x, point.y - a.y) }
        let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
        return hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy))
    }

    /// Keeps at least `minimumVisible` points of `rect` inside `container` so objects can never be
    /// dragged completely off the page.
    public static func keepVisible(_ rect: CGRect, in container: CGRect, minimumVisible: CGFloat = 12) -> CGRect {
        var result = rect
        let visibleX = min(minimumVisible, rect.width)
        let visibleY = min(minimumVisible, rect.height)
        if result.maxX < container.minX + visibleX { result.origin.x = container.minX + visibleX - result.width }
        if result.minX > container.maxX - visibleX { result.origin.x = container.maxX - visibleX }
        if result.maxY < container.minY + visibleY { result.origin.y = container.minY + visibleY - result.height }
        if result.minY > container.maxY - visibleY { result.origin.y = container.maxY - visibleY }
        return result
    }

    /// Size of a page as displayed, taking the page's /Rotate value into account.
    public static func displayedPageSize(_ size: CGSize, rotation: Int) -> CGSize {
        let normalized = ((rotation % 360) + 360) % 360
        return (normalized == 90 || normalized == 270) ? CGSize(width: size.height, height: size.width) : size
    }

    /// Scale factor needed to fit a page into a viewport. Padding is applied on each side.
    public static func fitScale(pageSize: CGSize, rotation: Int, viewport: CGSize, mode: FitMode, padding: CGFloat = 16) -> CGFloat {
        let displayed = displayedPageSize(pageSize, rotation: rotation)
        guard displayed.width > 0, displayed.height > 0 else { return 1 }
        let availableWidth = max(1, viewport.width - padding * 2)
        let availableHeight = max(1, viewport.height - padding * 2)
        let widthScale = availableWidth / displayed.width
        switch mode {
        case .width:
            return widthScale
        case .page:
            return min(widthScale, availableHeight / displayed.height)
        }
    }

    /// Quad points (relative to the annotation bounds origin) covering the whole bounds, in the
    /// order PDFKit expects: top-left, top-right, bottom-left, bottom-right.
    public static func quadPoints(for size: CGSize) -> [CGPoint] {
        [
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height),
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0)
        ]
    }

    public static func aspectFit(_ size: CGSize, into box: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return box }
        let scale = min(box.width / size.width, box.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
