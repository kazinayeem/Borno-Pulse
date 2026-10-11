//
//  PDFToolModels.swift
//  Borno Pulse
//

import Foundation
import PDFKit

public struct PDFFileQueueItem: Identifiable, Sendable {
    public var id: UUID = UUID()
    public var url: URL
    public var filename: String { url.lastPathComponent }
    public var pageCount: Int
    public var fileSize: UInt64
    public var isEncrypted: Bool
    public var outputSizeBytes: UInt64?
    public var status: FileItemStatus = .pending
    public var errorMessage: String?
    
    public init(url: URL, pageCount: Int = 1, fileSize: UInt64 = 0, isEncrypted: Bool = false) {
        self.url = url
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.isEncrypted = isEncrypted
    }
}

public enum PDFCompressionPreset: String, CaseIterable, Identifiable, Sendable {
    case highQuality = "Lossless Re-save"
    case balanced = "Balanced (JPEG Images)"
    case compact = "Smallest (Screen Images)"
    case flatten = "Flatten to Images"

    public var id: String { rawValue }

    /// What the preset actually does, shown in the UI.
    public var detail: String {
        switch self {
        case .highQuality:
            return "Rewrites the file structure only. Text, vectors and images are untouched."
        case .balanced:
            return "Re-encodes embedded images as JPEG (quality 75%, up to 150 ppi). Text, vectors, links and annotations are preserved."
        case .compact:
            return "Re-encodes images as JPEG (quality 50%) and downsamples them to 96 ppi for on-screen viewing. Text, vectors, links and annotations are preserved."
        case .flatten:
            return "Renders every page to a 110 DPI JPEG. Removes selectable text, links, form fields and annotations. Use only for scans."
        }
    }

    public var preservesText: Bool { self != .flatten }

    /// JPEG quality and maximum image resolution applied by the image-recompression presets.
    public var imageSettings: (quality: Double, resolution: Int)? {
        switch self {
        case .balanced: return (0.75, 150)
        case .compact: return (0.5, 96)
        case .highQuality, .flatten: return nil
        }
    }

    /// Rendering resolution for the flatten preset.
    public var dpi: CGFloat { 110 }
}

public enum PDFPageSizePreset: String, CaseIterable, Identifiable, Sendable {
    case a4 = "A4 (210 × 297 mm)"
    case usLetter = "US Letter (8.5 × 11 in)"
    case matchImage = "Match Image Dimensions"
    
    public var id: String { rawValue }
    
    public var pointSize: CGSize {
        switch self {
        case .a4: return CGSize(width: 595.28, height: 841.89)
        case .usLetter: return CGSize(width: 612.0, height: 792.0)
        case .matchImage: return .zero
        }
    }
}

public enum PDFPageMargin: String, CaseIterable, Identifiable, Sendable {
    case none = "No Margins"
    case small = "Compact (18 pt)"
    case standard = "Standard (36 pt)"
    
    public var id: String { rawValue }
    
    public var inset: CGFloat {
        switch self {
        case .none: return 0
        case .small: return 18
        case .standard: return 36
        }
    }
}

public enum PDFSplitMode: String, CaseIterable, Identifiable, Sendable {
    case everyPage = "Extract Every Page Separately"
    case pageRange = "Extract Selected Page Range"
    case everyNPages = "Split Every N Pages"
    
    public var id: String { rawValue }
}

public struct PDFMetadataInfo: Sendable {
    public var title: String?
    public var author: String?
    public var subject: String?
    public var creator: String?
    public var producer: String?
    public var creationDate: Date?
    public var pageCount: Int = 0
    public var isLocked: Bool = false
    public var hasDigitalSignature: Bool = false
    
    public init() {}
}
