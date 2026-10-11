//
//  PDFStudioModels.swift
//  Borno Pulse
//
//  Comprehensive data models for the Advanced PDF Studio.
//

import AppKit
import Foundation
import PDFKit

// MARK: - PDF Studio Tools
public enum PDFStudioTool: String, CaseIterable, Identifiable, Sendable {
    case imagesToPDF = "Images to PDF"
    case mergePDFs = "Merge PDFs"
    case mergeMixed = "Merge Images & PDFs"
    case advancedEditor = "Advanced PDF Editor"
    case pageOrganizer = "Page Organizer"
    case pdfToImages = "PDF to Images"
    case officeToPDF = "Word & Office to PDF"
    case compressor = "PDF Compressor"
    case splitter = "PDF Splitter"
    case extractor = "Page Extractor"
    case rotateReorder = "Rotate & Reorder"
    case metadataInspector = "Metadata & Privacy"
    case ocrSearchable = "OCR & Searchable PDF"
    case exportPrint = "Export & Print"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .imagesToPDF: return "photo.on.rectangle.angled"
        case .mergePDFs: return "doc.on.doc.fill"
        case .mergeMixed: return "arrow.triangle.merge"
        case .advancedEditor: return "pencil.and.outline"
        case .pageOrganizer: return "square.grid.3x3.fill"
        case .pdfToImages: return "photo.stack.fill"
        case .officeToPDF: return "doc.richtext.fill"
        case .compressor: return "arrow.down.circle.fill"
        case .splitter: return "scissors"
        case .extractor: return "arrow.up.right.and.arrow.down.left.rectangle"
        case .rotateReorder: return "rotate.right.fill"
        case .metadataInspector: return "lock.shield.fill"
        case .ocrSearchable: return "text.viewfinder"
        case .exportPrint: return "printer.fill"
        }
    }

    public var category: String {
        switch self {
        case .imagesToPDF, .mergePDFs, .mergeMixed, .officeToPDF, .pdfToImages:
            return "Assemble & Convert"
        case .advancedEditor, .pageOrganizer, .splitter, .extractor, .rotateReorder:
            return "Edit & Organize"
        case .compressor, .metadataInspector, .ocrSearchable, .exportPrint:
            return "Optimize & Tools"
        }
    }

    public var description: String {
        switch self {
        case .imagesToPDF:
            return "Combine multiple images into paginated A4, Letter, or custom dimension PDF documents."
        case .mergePDFs:
            return "Combine multiple PDF documents preserving vector artwork, text layers, and fonts."
        case .mergeMixed:
            return "Unified assembly workspace: mix images and PDF pages in any custom sequence."
        case .advancedEditor:
            return "Full PDF canvas with thumbnail sidebar, text, highlights, shapes, notes, and signatures."
        case .pageOrganizer:
            return "Visual grid thumbnail organizer to rotate, delete, duplicate, and reorder pages."
        case .pdfToImages:
            return "Render high-resolution PNG, JPG, or TIFF images from PDF pages with custom DPI."
        case .officeToPDF:
            return "Convert Word DOCX, RTF, TXT, HTML, and Markdown to PDF 100% offline."
        case .compressor:
            return "Downsample images and optimize streams with selectable compression presets."
        case .splitter:
            return "Split documents by every page, custom ranges, or recurring N-page intervals."
        case .extractor:
            return "Extract selected individual pages into a standalone new document."
        case .rotateReorder:
            return "Batch rotate pages by 90°, 180°, 270° or reverse document order."
        case .metadataInspector:
            return "Inspect document attributes, strip sensitive tracking metadata, and inspect permissions."
        case .ocrSearchable:
            return "On-device Apple Vision text recognition to generate searchable PDFs from scans."
        case .exportPrint:
            return "Native macOS PDF printing and validated export options."
        }
    }
}

// MARK: - Document Page Source Type
public enum DocumentPageSourceType: String, Codable, Sendable {
    case pdfPage
    case image
    case officeDocument
}

// MARK: - Image Fit Mode
public enum ImageFitMode: String, CaseIterable, Identifiable, Sendable {
    case contain = "Fit to Page (Aspect Ratio)"
    case cover = "Fill Entire Page (Crop)"
    case stretch = "Stretch to Edges"

    public var id: String { rawValue }
}

// MARK: - Unified PDF Studio Page Item
public struct PDFStudioPageItem: Identifiable, Sendable {
    public let id: UUID
    public let sourceURL: URL
    public let sourceFilename: String
    public let sourceType: DocumentPageSourceType
    public let originalPageIndex: Int
    public var rotationAngle: Int // 0, 90, 180, 270
    public var customWidth: CGFloat?
    public var customHeight: CGFloat?
    public var cachedThumbnail: NSImage?
    public var pageTitle: String
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        sourceType: DocumentPageSourceType,
        originalPageIndex: Int = 0,
        rotationAngle: Int = 0,
        customWidth: CGFloat? = nil,
        customHeight: CGFloat? = nil,
        cachedThumbnail: NSImage? = nil,
        pageTitle: String? = nil,
        isSelected: Bool = false
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.sourceFilename = sourceURL.lastPathComponent
        self.sourceType = sourceType
        self.originalPageIndex = originalPageIndex
        self.rotationAngle = rotationAngle
        self.customWidth = customWidth
        self.customHeight = customHeight
        self.cachedThumbnail = cachedThumbnail
        self.pageTitle = pageTitle ?? "\(sourceURL.lastPathComponent) (p. \(originalPageIndex + 1))"
        self.isSelected = isSelected
    }
}

// MARK: - PDF Annotation Tool Type
public enum PDFAnnotationToolType: String, CaseIterable, Identifiable, Sendable {
    case select = "Select"
    case highlight = "Highlight"
    case underline = "Underline"
    case strikeout = "Strikeout"
    case text = "Text Box"
    case pen = "Freehand Pen"
    case rectangle = "Rectangle"
    case circle = "Circle"
    case line = "Line"
    case arrow = "Arrow"
    case stickyNote = "Sticky Note"
    case cover = "Cover Region"
    case signatureStamp = "Signature"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .select: return "cursorarrow"
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .strikeout: return "strikethrough"
        case .text: return "character.textbox"
        case .pen: return "pencil.tip"
        case .rectangle: return "square"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .stickyNote: return "note.text"
        case .cover: return "rectangle.fill"
        case .signatureStamp: return "signature"
        }
    }

    /// Tools that create something by clicking/dragging on the page canvas.
    public static let canvasTools: [PDFAnnotationToolType] = [
        .select, .text, .highlight, .underline, .strikeout, .pen,
        .rectangle, .circle, .line, .arrow, .stickyNote, .cover
    ]

    public var usageHint: String {
        switch self {
        case .select:
            return "Click an object to select it. Drag to move, drag corner handles to resize, press Delete to remove. ⌥-click cycles through overlapping objects. Click empty page areas to select PDF text or fill form fields."
        case .highlight, .underline, .strikeout:
            return "Drag across text to mark it up. Dragging over an area with no text marks the dragged rectangle."
        case .text:
            return "Click to place a text box, or drag to size it. Edit the text, font, size and color in the inspector."
        case .pen:
            return "Drag to draw freehand. Each stroke becomes its own ink annotation."
        case .rectangle, .circle:
            return "Drag to draw. Hold Shift for a square/circle."
        case .line, .arrow:
            return "Drag from start to end point. Hold Shift to snap to 45°."
        case .stickyNote:
            return "Click to place a comment note, then type the comment in the inspector."
        case .cover:
            return "Drag to cover a region with an opaque box (whiteout). This hides content visually but does not remove the underlying text — it is not secure redaction."
        case .signatureStamp:
            return "Draw or import a signature; it is placed as a movable, resizable image."
        }
    }
}

// MARK: - PDF Annotation Style
public struct PDFAnnotationStyle: Sendable {
    public var color: NSColor
    public var opacity: CGFloat
    public var strokeWidth: CGFloat
    public var fontSize: CGFloat
    public var textColor: NSColor

    public init(
        color: NSColor = .systemYellow,
        opacity: CGFloat = 0.5,
        strokeWidth: CGFloat = 2.0,
        fontSize: CGFloat = 14.0,
        textColor: NSColor = .black
    ) {
        self.color = color
        self.opacity = opacity
        self.strokeWidth = strokeWidth
        self.fontSize = fontSize
        self.textColor = textColor
    }
}

// MARK: - Office Format
public enum PDFOfficeFormat: String, CaseIterable, Identifiable, Sendable {
    case docx = "Word Document (.docx)"
    case rtf = "Rich Text (.rtf)"
    case rtfd = "Rich Text with Attachments (.rtfd)"
    case txt = "Plain Text (.txt)"
    case html = "HTML Document (.html)"
    case markdown = "Markdown (.md)"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .docx: return "docx"
        case .rtf: return "rtf"
        case .rtfd: return "rtfd"
        case .txt: return "txt"
        case .html: return "html"
        case .markdown: return "md"
        }
    }
}
