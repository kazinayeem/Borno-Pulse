//
//  PDFEditorService.swift
//  Borno Pulse
//
//  Native PDF editing, page manipulation, annotations, signatures, and form handling engine.
//

import AppKit
import Foundation
import PDFKit
import SwiftUI

@MainActor
public final class PDFEditorService: ObservableObject {
    public static let shared = PDFEditorService()

    @Published public var document: PDFDocument?
    @Published public var sourceURL: URL?
    @Published public var currentPageIndex: Int = 0
    @Published public var selectedAnnotationTool: PDFAnnotationToolType = .select
    @Published public var annotationColor: Color = .yellow
    @Published public var annotationOpacity: Double = 0.5
    @Published public var strokeWidth: Double = 2.0
    @Published public var textFontSize: Double = 14.0
    @Published public var statusMessage: String = "No document open"
    @Published public var detectedFormFields: [String] = []
    @Published public var canUndo: Bool = false
    @Published public var canRedo: Bool = false

    private var undoHistory: [Data] = []
    private var redoHistory: [Data] = []

    public init() {}

    // MARK: - Document Loading
    public func loadDocument(url: URL) {
        guard let doc = PDFDocument(url: url) else {
            statusMessage = "Unable to open PDF at \(url.lastPathComponent)"
            return
        }
        self.sourceURL = url
        self.document = doc
        self.currentPageIndex = 0
        self.undoHistory.removeAll()
        self.redoHistory.removeAll()
        saveStateForUndo()
        detectInteractiveForms()
        statusMessage = "Loaded \(url.lastPathComponent) (\(doc.pageCount) pages)"
    }

    public func loadDocument(doc: PDFDocument, title: String = "Untitled.pdf") {
        self.sourceURL = nil
        self.document = doc
        self.currentPageIndex = 0
        self.undoHistory.removeAll()
        self.redoHistory.removeAll()
        saveStateForUndo()
        detectInteractiveForms()
        statusMessage = "Loaded document: \(title)"
    }

    // MARK: - Page Operations
    public func insertBlankPage(at index: Int? = nil) {
        guard let doc = document else { return }
        saveStateForUndo()
        let targetIndex = index ?? (currentPageIndex + 1)
        let page = PDFPage()
        page.setBounds(CGRect(x: 0, y: 0, width: 595.28, height: 841.89), for: .mediaBox)
        doc.insert(page, at: min(targetIndex, doc.pageCount))
        currentPageIndex = targetIndex
        statusMessage = "Inserted blank page at position \(targetIndex + 1)"
    }

    public func deleteCurrentPage() {
        guard let doc = document, doc.pageCount > 1 else {
            statusMessage = "Cannot delete the only page in the document."
            return
        }
        saveStateForUndo()
        doc.removePage(at: currentPageIndex)
        currentPageIndex = min(currentPageIndex, doc.pageCount - 1)
        statusMessage = "Deleted page \(currentPageIndex + 1)"
    }

    public func rotateCurrentPage(delta: Int = 90) {
        guard let doc = document, let page = doc.page(at: currentPageIndex) else { return }
        saveStateForUndo()
        page.rotation = (page.rotation + delta) % 360
        statusMessage = "Rotated page \(currentPageIndex + 1) to \(page.rotation)°"
    }

    public func duplicateCurrentPage() {
        guard let doc = document, let page = doc.page(at: currentPageIndex) else { return }
        saveStateForUndo()
        if let copy = page.copy() as? PDFPage {
            doc.insert(copy, at: currentPageIndex + 1)
            currentPageIndex += 1
            statusMessage = "Duplicated page \(currentPageIndex)"
        }
    }

    // MARK: - Annotation Operations
    public func addAnnotation(
        type: PDFAnnotationToolType,
        bounds: CGRect,
        text: String? = nil,
        points: [CGPoint]? = nil
    ) {
        guard let doc = document, let page = doc.page(at: currentPageIndex) else { return }
        saveStateForUndo()

        let nsColor = NSColor(annotationColor).withAlphaComponent(CGFloat(annotationOpacity))

        switch type {
        case .highlight:
            let annot = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annot.color = nsColor
            page.addAnnotation(annot)

        case .underline:
            let annot = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
            annot.color = nsColor
            page.addAnnotation(annot)

        case .strikeout:
            let annot = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
            annot.color = nsColor
            page.addAnnotation(annot)

        case .text:
            let annot = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
            annot.contents = text ?? "Click to edit text"
            annot.font = NSFont.systemFont(ofSize: CGFloat(textFontSize))
            annot.fontColor = NSColor(annotationColor)
            annot.color = NSColor.clear
            page.addAnnotation(annot)

        case .rectangle:
            let annot = PDFAnnotation(bounds: bounds, forType: .square, withProperties: nil)
            annot.color = nsColor
            let border = PDFBorder()
            border.lineWidth = CGFloat(strokeWidth)
            annot.border = border
            page.addAnnotation(annot)

        case .circle:
            let annot = PDFAnnotation(bounds: bounds, forType: .circle, withProperties: nil)
            annot.color = nsColor
            let border = PDFBorder()
            border.lineWidth = CGFloat(strokeWidth)
            annot.border = border
            page.addAnnotation(annot)

        case .line, .arrow:
            let annot = PDFAnnotation(bounds: bounds, forType: .line, withProperties: nil)
            annot.color = nsColor
            let border = PDFBorder()
            border.lineWidth = CGFloat(strokeWidth)
            annot.border = border
            page.addAnnotation(annot)

        case .stickyNote:
            let annot = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
            annot.contents = text ?? "Note comment"
            annot.color = nsColor
            page.addAnnotation(annot)

        case .pen:
            let annot = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
            annot.color = nsColor
            if let pts = points, pts.count > 1 {
                let path = NSBezierPath()
                path.move(to: pts[0])
                for pt in pts.dropFirst() {
                    path.line(to: pt)
                }
                annot.add(path)
            }
            page.addAnnotation(annot)

        case .select, .signatureStamp:
            break
        }

        statusMessage = "Added \(type.rawValue) annotation"
    }

    // MARK: - Signature Stamp
    public func addSignature(image: NSImage, bounds: CGRect? = nil) {
        guard let doc = document, let page = doc.page(at: currentPageIndex) else { return }
        saveStateForUndo()

        let pageBounds = page.bounds(for: .mediaBox)
        let sigBounds = bounds ?? CGRect(
            x: (pageBounds.width - 200) / 2,
            y: 80,
            width: 200,
            height: 70
        )

        let annot = PDFAnnotation(bounds: sigBounds, forType: .stamp, withProperties: nil)
        annot.contents = "Signature"
        page.addAnnotation(annot)
        statusMessage = "Placed signature on page \(currentPageIndex + 1)"
    }

    public func addSignatureStamp(signatureImage: NSImage, bounds: CGRect) {
        addSignature(image: signatureImage, bounds: bounds)
    }

    // MARK: - Interactive Forms Detection
    public func detectInteractiveForms() {
        guard let doc = document else {
            detectedFormFields = []
            return
        }
        var fields: [String] = []
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i) {
                for annot in page.annotations {
                    if annot.type == "Widget" {
                        let name = annot.fieldName ?? "Field \(fields.count + 1)"
                        fields.append("\(name) (p. \(i + 1))")
                    }
                }
            }
        }
        self.detectedFormFields = fields
    }

    // MARK: - Undo & Redo
    private func saveStateForUndo() {
        guard let doc = document, let data = doc.dataRepresentation() else { return }
        undoHistory.append(data)
        if undoHistory.count > 15 {
            undoHistory.removeFirst()
        }
        redoHistory.removeAll()
        updateUndoRedoFlags()
    }

    public func undo() {
        guard !undoHistory.isEmpty else { return }
        if let currentData = document?.dataRepresentation() {
            redoHistory.append(currentData)
        }
        let previous = undoHistory.removeLast()
        self.document = PDFDocument(data: previous)
        updateUndoRedoFlags()
        statusMessage = "Undo performed"
    }

    public func redo() {
        guard !redoHistory.isEmpty else { return }
        if let currentData = document?.dataRepresentation() {
            undoHistory.append(currentData)
        }
        let next = redoHistory.removeLast()
        self.document = PDFDocument(data: next)
        updateUndoRedoFlags()
        statusMessage = "Redo performed"
    }

    private func updateUndoRedoFlags() {
        canUndo = !undoHistory.isEmpty
        canRedo = !redoHistory.isEmpty
    }

    // MARK: - Save Document
    public func saveDocument(to destinationURL: URL) -> Bool {
        guard let doc = document else { return false }
        return doc.write(to: destinationURL)
    }

    public func saveCopy(to destinationURL: URL) -> Bool {
        return saveDocument(to: destinationURL)
    }
}
