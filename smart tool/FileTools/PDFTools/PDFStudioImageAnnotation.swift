//
//  PDFStudioImageAnnotation.swift
//  Borno Pulse
//
//  Editable image / signature object stored as a PDF Stamp annotation.
//
//  PDFKit renders `draw(with:in:)` into the annotation's appearance stream when the
//  document is written, so the image is visible in every PDF viewer. The encoded image,
//  its unrotated size and rotation are also stored in private annotation dictionary keys
//  (/BornoImageData, /BornoImageSize, /BornoImageRotation, /BornoImageRole) so the object
//  stays selectable and editable when the file is reopened in Borno Pulse.
//

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

public final class PDFStudioImageAnnotation: PDFAnnotation {

    public enum Role: String, Sendable {
        case image
        case signature
    }

    public static let imageDataKey = PDFAnnotationKey(rawValue: "/BornoImageData")
    public static let sizeKey = PDFAnnotationKey(rawValue: "/BornoImageSize")
    public static let rotationKey = PDFAnnotationKey(rawValue: "/BornoImageRotation")
    public static let roleKey = PDFAnnotationKey(rawValue: "/BornoImageRole")

    /// Longest pixel edge kept for embedded images. Larger sources are downsampled once on insert.
    public static let maximumPixelDimension: CGFloat = 2400

    private var decodedImage: CGImage?

    public override init(bounds: CGRect, forType annotationType: PDFAnnotationSubtype, withProperties properties: [AnyHashable: Any]?) {
        super.init(bounds: bounds, forType: annotationType, withProperties: properties)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public convenience init?(imageData: Data, center: CGPoint, size: CGSize, rotation: CGFloat = 0, role: Role = .image) {
        guard Self.decode(imageData) != nil else { return nil }
        self.init(bounds: .zero, forType: .stamp, withProperties: nil)
        setValue(imageData.base64EncodedString(), forAnnotationKey: Self.imageDataKey)
        setValue(role.rawValue, forAnnotationKey: Self.roleKey)
        contents = role == .signature ? "Signature" : "Image"
        shouldDisplay = true
        shouldPrint = true
        setGeometry(center: center, size: size, rotation: rotation)
    }

    // MARK: - Stored State

    public var imageData: Data? {
        guard let string = value(forAnnotationKey: Self.imageDataKey) as? String else { return nil }
        return Data(base64Encoded: string)
    }

    public var role: Role {
        guard let raw = value(forAnnotationKey: Self.roleKey) as? String else { return .image }
        return Role(rawValue: raw) ?? .image
    }

    public var rotationDegrees: CGFloat {
        Self.storedRotation(of: self)
    }

    /// Unrotated size of the image object in page points.
    public var contentSize: CGSize {
        Self.storedSize(of: self) ?? bounds.size
    }

    static func storedRotation(of annotation: PDFAnnotation) -> CGFloat {
        guard let raw = annotation.value(forAnnotationKey: rotationKey) as? String, let value = Double(raw) else { return 0 }
        return CGFloat(value)
    }

    static func storedSize(of annotation: PDFAnnotation) -> CGSize? {
        guard let raw = annotation.value(forAnnotationKey: sizeKey) as? String else { return nil }
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }

    public var center: CGPoint { PDFEditorGeometry.center(of: bounds) }

    public var image: CGImage? {
        if let decodedImage { return decodedImage }
        guard let data = imageData else { return nil }
        decodedImage = Self.decode(data)
        return decodedImage
    }

    public var pixelSize: CGSize {
        guard let image else { return .zero }
        return CGSize(width: image.width, height: image.height)
    }

    public var rotatedCorners: [CGPoint] {
        PDFEditorGeometry.rotatedCorners(center: center, size: contentSize, degrees: rotationDegrees)
    }

    public func setGeometry(center: CGPoint, size: CGSize, rotation: CGFloat) {
        let normalized = PDFEditorGeometry.normalizedDegrees(rotation)
        setValue(String(format: "%.4f,%.4f", Double(size.width), Double(size.height)), forAnnotationKey: Self.sizeKey)
        setValue(String(format: "%.4f", Double(normalized)), forAnnotationKey: Self.rotationKey)
        bounds = PDFEditorGeometry.rotatedBounds(center: center, size: size, degrees: normalized)
    }

    public func containsPagePoint(_ point: CGPoint, tolerance: CGFloat = 0) -> Bool {
        PDFEditorGeometry.contains(point, center: center, size: contentSize, degrees: rotationDegrees, tolerance: tolerance)
    }

    // MARK: - Rendering

    public override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let image else {
            super.draw(with: box, in: context)
            return
        }
        let size = contentSize
        context.saveGState()
        context.interpolationQuality = .high
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: -rotationDegrees * .pi / 180)
        context.draw(image, in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        context.restoreGState()
    }

    // MARK: - Persistence Helpers

    public static func isStudioImage(_ annotation: PDFAnnotation) -> Bool {
        annotation is PDFStudioImageAnnotation || annotation.value(forAnnotationKey: imageDataKey) != nil
    }

    /// Replaces plain Stamp annotations that carry Borno image keys (as loaded from disk or
    /// produced by `PDFPage.copy()`) with live, editable `PDFStudioImageAnnotation` objects.
    @discardableResult
    public static func rehydrate(page: PDFPage) -> Int {
        var count = 0
        for annotation in page.annotations where !(annotation is PDFStudioImageAnnotation) {
            guard let data = (annotation.value(forAnnotationKey: imageDataKey) as? String).flatMap({ Data(base64Encoded: $0) }) else { continue }
            let roleRaw = annotation.value(forAnnotationKey: roleKey) as? String
            guard let live = PDFStudioImageAnnotation(
                imageData: data,
                center: PDFEditorGeometry.center(of: annotation.bounds),
                size: storedSize(of: annotation) ?? annotation.bounds.size,
                rotation: storedRotation(of: annotation),
                role: Role(rawValue: roleRaw ?? "") ?? .image
            ) else { continue }
            live.contents = annotation.contents
            page.removeAnnotation(annotation)
            page.addAnnotation(live)
            count += 1
        }
        return count
    }

    @discardableResult
    public static func rehydrate(document: PDFDocument) -> Int {
        var count = 0
        for index in 0..<document.pageCount {
            if let page = document.page(at: index) { count += rehydrate(page: page) }
        }
        return count
    }

    public static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Loads an image file with its EXIF orientation applied and downsampled to
    /// `maximumPixelDimension`, returning compact encoded data (PNG when transparency is
    /// present, otherwise high-quality JPEG).
    public static func normalizedImageData(contentsOf url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return normalizedImageData(source: source)
    }

    public static func normalizedImageData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return normalizedImageData(source: source)
    }

    public static func normalizedImageData(from image: NSImage) -> Data? {
        if let tiff = image.tiffRepresentation, let data = normalizedImageData(from: tiff) {
            return data
        }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return encode(cgImage)
    }

    private static func normalizedImageData(source: CGImageSource) -> Data? {
        guard CGImageSourceGetCount(source) > 0 else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        let longest = max(width, height)
        guard longest > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(longest, Double(maximumPixelDimension)),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return encode(image)
    }

    public static func encode(_ image: CGImage) -> Data? {
        let alpha = image.alphaInfo
        let hasAlpha = !(alpha == .none || alpha == .noneSkipFirst || alpha == .noneSkipLast)
        let type = hasAlpha ? UTType.png : UTType.jpeg
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, type.identifier as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = hasAlpha ? [:] : [kCGImageDestinationLossyCompressionQuality: 0.92]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Default on-page size for a newly inserted image: its natural size at 144 DPI, limited
    /// to `maxFraction` of the page.
    public static func defaultSize(forPixelSize pixels: CGSize, pageSize: CGSize, maxFraction: CGFloat = 0.6) -> CGSize {
        guard pixels.width > 0, pixels.height > 0 else { return CGSize(width: 120, height: 120) }
        let natural = CGSize(width: pixels.width / 2, height: pixels.height / 2)
        let limit = CGSize(width: max(40, pageSize.width * maxFraction), height: max(40, pageSize.height * maxFraction))
        if natural.width <= limit.width && natural.height <= limit.height {
            return CGSize(width: max(24, natural.width), height: max(24, natural.height))
        }
        return PDFEditorGeometry.aspectFit(natural, into: limit)
    }
}
