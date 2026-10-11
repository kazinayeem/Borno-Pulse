//
//  PDFEditorService.swift
//  Borno Pulse
//
//  Document model for the Advanced PDF Editor: annotation creation/editing, editable image
//  objects, page operations, undo/redo, forms, and crash-safe save. All geometry is in PDF
//  page space; the canvas (PDFEditorCanvasView) is responsible for view <-> page conversion.
//

import AppKit
import Foundation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

public struct PDFEditorAlert: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public enum PDFEditableKind: String, Sendable {
    case image = "Image"
    case signature = "Signature"
    case freeText = "Text Box"
    case note = "Sticky Note"
    case highlight = "Highlight"
    case underline = "Underline"
    case strikeOut = "Strikethrough"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case line = "Line"
    case arrow = "Arrow"
    case ink = "Freehand Drawing"
    case cover = "Cover Region"
    case stamp = "Stamp"

    public var isImage: Bool { self == .image || self == .signature }
    public var isMarkup: Bool { self == .highlight || self == .underline || self == .strikeOut }
    public var hasEndpoints: Bool { self == .line || self == .arrow }
    public var isResizable: Bool {
        switch self {
        case .image, .signature, .freeText, .rectangle, .ellipse, .cover: return true
        default: return false
        }
    }
    public var isMovable: Bool { !isMarkup }
    public var supportsFill: Bool { self == .rectangle || self == .ellipse || self == .freeText || self == .cover }
    public var supportsStroke: Bool { self == .rectangle || self == .ellipse || self == .line || self == .arrow || self == .ink }
}

public struct PDFFormFieldInfo: Identifiable {
    public enum Kind: String {
        case text = "Text"
        case checkbox = "Checkbox"
        case radio = "Radio Button"
        case choice = "Choice"
        case signature = "Signature"
        case pushButton = "Button"
    }

    public let id: ObjectIdentifier
    public let annotation: PDFAnnotation
    public let name: String
    public let pageIndex: Int
    public let kind: Kind
}

/// Snapshot of everything the editor can change on an annotation, used for undo/redo.
public struct PDFAnnotationState: Equatable {
    var bounds: CGRect
    var contents: String?
    var color: NSColor
    var interiorColor: NSColor?
    var fontColor: NSColor?
    var font: NSFont?
    var lineWidth: CGFloat
    var startPoint: CGPoint
    var endPoint: CGPoint
    var endLineStyle: PDFLineStyle
    var imageSize: CGSize?
    var imageRotation: CGFloat
}

@MainActor
public final class PDFEditorService: ObservableObject {
    public static let shared = PDFEditorService()

    public enum LoadResult: Equatable {
        case opened
        case needsPassword
        case failed(String)
    }

    public static let coverKey = PDFAnnotationKey(rawValue: "/BornoCover")
    public static let defaultPageSize = CGSize(width: 595.28, height: 841.89)
    public static let fontChoices: [(name: String, postScript: String)] = [
        ("Helvetica", "Helvetica"),
        ("Helvetica Bold", "Helvetica-Bold"),
        ("Times", "Times-Roman"),
        ("Georgia", "Georgia"),
        ("Arial", "ArialMT"),
        ("Avenir Next", "AvenirNext-Regular"),
        ("Courier", "Courier"),
        ("Menlo", "Menlo-Regular")
    ]

    // MARK: Published State

    @Published public private(set) var document: PDFDocument?
    @Published public private(set) var sourceURL: URL?
    @Published public private(set) var documentTitle: String = ""
    @Published public private(set) var documentNotice: String?
    @Published public var currentPageIndex: Int = 0 {
        didSet {
            guard currentPageIndex != oldValue else { return }
            if let page = currentPage { canvas?.goToPageIfNeeded(page) }
        }
    }
    @Published public var selectedAnnotationTool: PDFAnnotationToolType = .select {
        didSet {
            guard selectedAnnotationTool != oldValue else { return }
            endTextEditSession()
            if let stored = toolColors[selectedAnnotationTool] {
                isSyncingToolColor = true
                annotationColor = stored
                isSyncingToolColor = false
            }
            if selectedAnnotationTool != .select { canvas?.clearTextSelection() }
            canvas?.toolChanged()
        }
    }
    @Published public var annotationColor: Color = .red {
        didSet {
            if !isSyncingToolColor { toolColors[selectedAnnotationTool] = annotationColor }
        }
    }
    @Published public var annotationOpacity: Double = 0.45
    @Published public var strokeWidth: Double = 2.0
    @Published public var textFontSize: Double = 14.0
    @Published public var textFontName: String = "Helvetica"
    @Published public var shapeFillEnabled: Bool = false
    @Published public var shapeFillColor: Color = Color(nsColor: NSColor(srgbRed: 1, green: 0.9, blue: 0.6, alpha: 1))
    @Published public var lockImageAspectRatio: Bool = true
    @Published public var statusMessage: String = "No document open"
    @Published public var detectedFormFields: [String] = []
    @Published public private(set) var formFields: [PDFFormFieldInfo] = []
    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false
    @Published public private(set) var undoActionName: String = ""
    @Published public private(set) var redoActionName: String = ""
    @Published public private(set) var hasUnsavedChanges: Bool = false
    @Published public private(set) var selectedAnnotation: PDFAnnotation?
    @Published public private(set) var revision: Int = 0
    @Published public var zoomPercent: Int = 100
    @Published public var lastError: PDFEditorAlert?
    @Published public var pendingPasswordURL: URL?
    @Published public private(set) var textEditRequest: Int = 0

    public let undoManager: UndoManager
    weak var canvas: PDFEditorCanvasView?

    private var toolColors: [PDFAnnotationToolType: Color] = [
        .highlight: Color(nsColor: .systemYellow),
        .underline: Color(nsColor: NSColor(srgbRed: 0.1, green: 0.45, blue: 0.95, alpha: 1)),
        .strikeout: Color(nsColor: NSColor(srgbRed: 0.85, green: 0.1, blue: 0.1, alpha: 1)),
        .text: Color(nsColor: .black),
        .pen: Color(nsColor: NSColor(srgbRed: 0.1, green: 0.3, blue: 0.85, alpha: 1)),
        .rectangle: Color(nsColor: NSColor(srgbRed: 0.85, green: 0.1, blue: 0.1, alpha: 1)),
        .circle: Color(nsColor: NSColor(srgbRed: 0.85, green: 0.1, blue: 0.1, alpha: 1)),
        .line: Color(nsColor: NSColor(srgbRed: 0.85, green: 0.1, blue: 0.1, alpha: 1)),
        .arrow: Color(nsColor: NSColor(srgbRed: 0.85, green: 0.1, blue: 0.1, alpha: 1)),
        .stickyNote: Color(nsColor: .systemYellow),
        .cover: Color(nsColor: .white)
    ]
    private var isSyncingToolColor = false
    private var textSession: (annotation: PDFAnnotation, before: PDFAnnotationState, name: String)?
    private var sessionGeneration: Int = 0
    private var clipboardTemplate: PDFAnnotation?
    private var clipboardChangeCount: Int = -1
    private var pasteCount: Int = 0

    static let annotationPasteboardType = NSPasteboard.PasteboardType("com.naem.borno.pdf-annotation")

    public init() {
        undoManager = UndoManager()
        undoManager.groupsByEvent = false
        undoManager.levelsOfUndo = 200
        for name in [Notification.Name.NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange, .NSUndoManagerDidCloseUndoGroup] {
            NotificationCenter.default.addObserver(forName: name, object: undoManager, queue: .main) { [weak self] _ in
                if Thread.isMainThread {
                    self?.refreshUndoState()
                } else {
                    DispatchQueue.main.async { self?.refreshUndoState() }
                }
            }
        }
    }

    // MARK: - Document Lifecycle

    public var currentPage: PDFPage? { document?.page(at: currentPageIndex) }
    public var pageCount: Int { document?.pageCount ?? 0 }

    @discardableResult
    public func loadDocument(url: URL, password: String? = nil) -> LoadResult {
        guard let doc = PDFDocument(url: url) else {
            let message = "“\(url.lastPathComponent)” could not be opened. It may be damaged or not a PDF."
            statusMessage = message
            return .failed(message)
        }
        if doc.isLocked {
            guard let password, doc.unlock(withPassword: password) else {
                statusMessage = password == nil ? "“\(url.lastPathComponent)” is password-protected." : "Incorrect password for “\(url.lastPathComponent)”."
                return .needsPassword
            }
        }
        guard doc.pageCount > 0 else {
            let message = "“\(url.lastPathComponent)” contains no pages."
            statusMessage = message
            return .failed(message)
        }
        install(doc, url: url, title: url.lastPathComponent)
        var notices: [String] = []
        if doc.isEncrypted {
            notices.append("This PDF was password-protected. Saved copies are written without the password.")
        }
        if !doc.allowsCommenting || !doc.allowsDocumentChanges {
            notices.append("The document's owner restricted editing; some viewers may ignore your changes.")
        }
        documentNotice = notices.isEmpty ? nil : notices.joined(separator: " ")
        return .opened
    }

    public func loadDocument(doc: PDFDocument, title: String = "Untitled.pdf") {
        install(doc, url: nil, title: title)
        documentNotice = nil
    }

    private func install(_ doc: PDFDocument, url: URL?, title: String) {
        endTextEditSession()
        PDFStudioImageAnnotation.rehydrate(document: doc)
        undoManager.removeAllActions()
        selectedAnnotation = nil
        clipboardTemplate = nil
        sourceURL = url
        documentTitle = title
        document = doc
        currentPageIndex = 0
        hasUnsavedChanges = false
        selectedAnnotationTool = .select
        detectInteractiveForms()
        refreshUndoState()
        revision &+= 1
        statusMessage = "Opened \(title) (\(doc.pageCount) page\(doc.pageCount == 1 ? "" : "s"))"
    }

    public func closeDocument() {
        endTextEditSession()
        undoManager.removeAllActions()
        selectedAnnotation = nil
        document = nil
        sourceURL = nil
        documentTitle = ""
        documentNotice = nil
        hasUnsavedChanges = false
        formFields = []
        detectedFormFields = []
        refreshUndoState()
        statusMessage = "No document open"
    }

    // MARK: - Saving

    @discardableResult
    public func save() -> Result<URL, Error> {
        guard let url = sourceURL else {
            return .failure(PDFStudioError.failed("This document has not been saved yet. Use Save As… to choose a location."))
        }
        return write(to: url, adoptLocation: true, options: nil, actionName: "Save")
    }

    @discardableResult
    public func save(as url: URL) -> Result<URL, Error> {
        write(to: url, adoptLocation: true, options: nil, actionName: "Save As")
    }

    /// Writes a copy without changing the open document's location. `flatten` burns annotations
    /// (including images) into the page content so they can no longer be edited or removed.
    @discardableResult
    public func exportCopy(to url: URL, flatten: Bool = false) -> Result<URL, Error> {
        write(to: url, adoptLocation: false, options: flatten ? [.burnInAnnotationsOption: true] : nil, actionName: "Export")
    }

    public func saveDocument(to destinationURL: URL) -> Bool {
        if case .success = save(as: destinationURL) { return true }
        return false
    }

    public func saveCopy(to destinationURL: URL) -> Bool {
        if case .success = exportCopy(to: destinationURL) { return true }
        return false
    }

    private func write(to url: URL, adoptLocation: Bool, options: [PDFDocumentWriteOption: Any]?, actionName: String) -> Result<URL, Error> {
        endTextEditSession()
        guard let doc = document else { return .failure(PDFStudioError.noDocument) }
        do {
            try PDFSafeWriter.write(doc, to: url, options: options)
            if adoptLocation {
                sourceURL = url
                documentTitle = url.lastPathComponent
                hasUnsavedChanges = false
            }
            statusMessage = "\(actionName) complete: \(url.lastPathComponent)"
            return .success(url)
        } catch {
            statusMessage = "\(actionName) failed: \(error.localizedDescription)"
            lastError = PDFEditorAlert(title: "\(actionName) Failed", message: error.localizedDescription)
            return .failure(error)
        }
    }

    // MARK: - Interactive File Flows (panels / prompts)

    /// Asks the user what to do with unsaved changes. Returns `true` when it is safe to continue.
    public func confirmProceedWithUnsavedChanges(before action: String) -> Bool {
        endTextEditSession()
        guard hasUnsavedChanges, document != nil else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to “\(documentTitle)” before \(action)?"
        alert.informativeText = "If you don't save, your changes will be lost."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveInteractively()
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    @discardableResult
    public func saveInteractively() -> Bool {
        if sourceURL != nil, case .success = save() { return true }
        if sourceURL != nil { return false }
        return runSaveAsPanel()
    }

    @discardableResult
    public func runSaveAsPanel() -> Bool {
        guard document != nil else { return false }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = documentTitle.isEmpty ? "Document.pdf" : documentTitle
        if let folder = sourceURL?.deletingLastPathComponent() { panel.directoryURL = folder }
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        if case .success = save(as: url) { return true }
        return false
    }

    public func runExportPanel(flatten: Bool) {
        guard document != nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        let base = (documentTitle as NSString).deletingPathExtension
        panel.nameFieldStringValue = "\(base.isEmpty ? "Document" : base)\(flatten ? " (Flattened)" : " copy").pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if url == sourceURL {
            lastError = PDFEditorAlert(title: "Choose a Different Name", message: "Export writes a separate copy. Use Save to update the open document.")
            return
        }
        if case .success(let written) = exportCopy(to: url, flatten: flatten) {
            NSWorkspace.shared.activateFileViewerSelecting([written])
        }
    }

    public func runOpenPanel() {
        guard confirmProceedWithUnsavedChanges(before: "opening another document") else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openDocument(at: url)
    }

    public func openDocument(at url: URL) {
        switch loadDocument(url: url) {
        case .opened:
            break
        case .needsPassword:
            pendingPasswordURL = url
        case .failed(let message):
            lastError = PDFEditorAlert(title: "Cannot Open PDF", message: message)
        }
    }

    /// Returns `false` if the password was wrong (the prompt stays open).
    public func unlockPendingDocument(password: String) -> Bool {
        guard let url = pendingPasswordURL else { return true }
        switch loadDocument(url: url, password: password) {
        case .opened:
            pendingPasswordURL = nil
            return true
        case .needsPassword:
            return false
        case .failed(let message):
            pendingPasswordURL = nil
            lastError = PDFEditorAlert(title: "Cannot Open PDF", message: message)
            return true
        }
    }

    public func requestClose() {
        guard confirmProceedWithUnsavedChanges(before: "closing") else { return }
        closeDocument()
    }

    public func printDocument() {
        guard let doc = document else { return }
        endTextEditSession()
        let info = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo.shared
        guard let operation = doc.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: true) else {
            lastError = PDFEditorAlert(title: "Print Unavailable", message: "macOS could not prepare this document for printing.")
            return
        }
        operation.jobTitle = documentTitle
        if let window = canvas?.window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    // MARK: - Undo Infrastructure

    public func undo() {
        endTextEditSession()
        guard undoManager.canUndo else { return }
        undoManager.undo()
        refreshUndoState()
        statusMessage = "Undo"
    }

    public func redo() {
        endTextEditSession()
        guard undoManager.canRedo else { return }
        undoManager.redo()
        refreshUndoState()
        statusMessage = "Redo"
    }

    func refreshUndoState() {
        canUndo = undoManager.canUndo || textSession != nil
        canRedo = undoManager.canRedo
        undoActionName = undoManager.undoActionName
        redoActionName = undoManager.redoActionName
    }

    /// Runs `body` as a single undoable step.
    private func perform(_ name: String, page: PDFPage? = nil, _ body: () -> Void) {
        endTextEditSession()
        undoManager.beginUndoGrouping()
        body()
        undoManager.setActionName(name)
        undoManager.endUndoGrouping()
        afterMutation(page: page)
        statusMessage = name
    }

    private func registerUndo(_ name: String, undo: @escaping @MainActor () -> Void, redo: @escaping @MainActor () -> Void) {
        undoManager.registerUndo(withTarget: self) { target in
            if Thread.isMainThread {
                undo()
                target.registerUndo(name, undo: redo, redo: undo)
                target.afterMutation(page: nil)
            } else {
                DispatchQueue.main.async {
                    undo()
                    target.registerUndo(name, undo: redo, redo: undo)
                    target.afterMutation(page: nil)
                }
            }
        }
        undoManager.setActionName(name)
    }

    private func afterMutation(page: PDFPage?) {
        hasUnsavedChanges = true
        revision &+= 1
        if let selected = selectedAnnotation, selected.page == nil {
            selectedAnnotation = nil
        }
        if let doc = document, currentPageIndex >= doc.pageCount {
            currentPageIndex = max(0, doc.pageCount - 1)
        }
        refreshUndoState()
        if let page {
            canvas?.refresh(page: page)
        } else {
            canvas?.refreshVisiblePages()
        }
    }

    public func markDocumentEdited() {
        hasUnsavedChanges = true
    }

    // MARK: - Annotation Classification & Hit Testing

    public static func kind(of annotation: PDFAnnotation) -> PDFEditableKind? {
        if let image = annotation as? PDFStudioImageAnnotation {
            return image.role == .signature ? .signature : .image
        }
        if annotation.value(forAnnotationKey: coverKey) != nil { return .cover }
        switch annotation.type ?? "" {
        case "FreeText": return .freeText
        case "Text": return .note
        case "Highlight": return .highlight
        case "Underline": return .underline
        case "StrikeOut": return .strikeOut
        case "Square": return .rectangle
        case "Circle": return .ellipse
        case "Line": return (annotation.endLineStyle == .none && annotation.startLineStyle == .none) ? .line : .arrow
        case "Ink": return .ink
        case "Stamp": return .stamp
        default: return nil
        }
    }

    public var selectedKind: PDFEditableKind? {
        selectedAnnotation.flatMap { Self.kind(of: $0) }
    }

    /// Editable annotations under `point`, highest priority first:
    /// 1. inserted images/signatures (topmost first, rotated-rect hit test),
    /// 2. other editable annotations (topmost first),
    /// PDF page text, links and form widgets are never returned; clicks there fall through to PDFKit.
    public func hitTest(page: PDFPage, point: CGPoint, tolerance: CGFloat = 3) -> [PDFAnnotation] {
        var images: [PDFAnnotation] = []
        var others: [PDFAnnotation] = []
        for annotation in page.annotations.reversed() where annotation.shouldDisplay {
            guard let kind = Self.kind(of: annotation) else { continue }
            switch kind {
            case .image, .signature:
                if let image = annotation as? PDFStudioImageAnnotation, image.containsPagePoint(point, tolerance: tolerance) {
                    images.append(annotation)
                }
            case .line, .arrow:
                let (start, end) = Self.lineEndpoints(of: annotation)
                let width = annotation.border?.lineWidth ?? 1
                if PDFEditorGeometry.distance(from: point, toSegment: start, end) <= width / 2 + tolerance + 2 {
                    others.append(annotation)
                }
            case .ink:
                if annotation.bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point),
                   Self.inkHit(annotation, point: point, tolerance: tolerance + (annotation.border?.lineWidth ?? 1)) {
                    others.append(annotation)
                }
            default:
                if annotation.bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
                    others.append(annotation)
                }
            }
        }
        return images + others
    }

    private static func inkHit(_ annotation: PDFAnnotation, point: CGPoint, tolerance: CGFloat) -> Bool {
        let origin = annotation.bounds.origin
        let local = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        for path in annotation.paths ?? [] {
            var previous: CGPoint?
            var points = [NSPoint](repeating: .zero, count: 3)
            for index in 0..<path.elementCount {
                let element = path.element(at: index, associatedPoints: &points)
                let current: CGPoint
                switch element {
                case .moveTo:
                    previous = points[0]
                    continue
                case .lineTo:
                    current = points[0]
                case .curveTo, .cubicCurveTo:
                    current = points[2]
                case .quadraticCurveTo:
                    current = points[1]
                case .closePath:
                    continue
                @unknown default:
                    continue
                }
                if let previous, PDFEditorGeometry.distance(from: local, toSegment: previous, current) <= tolerance {
                    return true
                }
                previous = current
            }
        }
        return false
    }

    public static func lineEndpoints(of annotation: PDFAnnotation) -> (CGPoint, CGPoint) {
        let origin = annotation.bounds.origin
        return (
            CGPoint(x: origin.x + annotation.startPoint.x, y: origin.y + annotation.startPoint.y),
            CGPoint(x: origin.x + annotation.endPoint.x, y: origin.y + annotation.endPoint.y)
        )
    }

    /// Line endpoints are stored relative to the bounds origin, so bounds are recomputed to
    /// enclose both points plus room for the line width and arrow head.
    public static func setLineEndpoints(_ annotation: PDFAnnotation, start: CGPoint, end: CGPoint) {
        let width = annotation.border?.lineWidth ?? 1
        let padding = max(8, width * 4)
        let rect = PDFEditorGeometry.rect(from: start, to: end).insetBy(dx: -padding, dy: -padding)
        annotation.bounds = rect
        annotation.startPoint = CGPoint(x: start.x - rect.minX, y: start.y - rect.minY)
        annotation.endPoint = CGPoint(x: end.x - rect.minX, y: end.y - rect.minY)
    }

    // MARK: - State Capture

    public static func captureState(_ annotation: PDFAnnotation) -> PDFAnnotationState {
        let image = annotation as? PDFStudioImageAnnotation
        return PDFAnnotationState(
            bounds: annotation.bounds,
            contents: annotation.contents,
            color: annotation.color,
            interiorColor: annotation.interiorColor,
            fontColor: annotation.type == "FreeText" ? annotation.fontColor : nil,
            font: annotation.type == "FreeText" ? annotation.font : nil,
            lineWidth: annotation.border?.lineWidth ?? 0,
            startPoint: annotation.type == "Line" ? annotation.startPoint : .zero,
            endPoint: annotation.type == "Line" ? annotation.endPoint : .zero,
            endLineStyle: annotation.type == "Line" ? annotation.endLineStyle : .none,
            imageSize: image?.contentSize,
            imageRotation: image?.rotationDegrees ?? 0
        )
    }

    public static func apply(_ state: PDFAnnotationState, to annotation: PDFAnnotation) {
        if let image = annotation as? PDFStudioImageAnnotation, let size = state.imageSize {
            image.setGeometry(center: PDFEditorGeometry.center(of: state.bounds), size: size, rotation: state.imageRotation)
        } else {
            annotation.bounds = state.bounds
        }
        annotation.contents = state.contents
        annotation.color = state.color
        if annotation.type == "Square" || annotation.type == "Circle" || annotation.type == "Line" {
            annotation.interiorColor = state.interiorColor
        }
        if annotation.type == "FreeText" {
            if let font = state.font { annotation.font = font }
            if let fontColor = state.fontColor { annotation.fontColor = fontColor }
        }
        if annotation.border != nil || state.lineWidth > 0 {
            let border = PDFBorder()
            border.lineWidth = state.lineWidth
            annotation.border = border
        }
        if annotation.type == "Line" {
            annotation.startPoint = state.startPoint
            annotation.endPoint = state.endPoint
            annotation.endLineStyle = state.endLineStyle
        }
    }

    // MARK: - Low-Level Mutations (must run inside `perform`)

    private func addRaw(_ annotation: PDFAnnotation, to page: PDFPage, name: String) {
        page.addAnnotation(annotation)
        registerUndo(name, undo: { [weak self] in
            page.removeAnnotation(annotation)
            if self?.selectedAnnotation === annotation { self?.selectedAnnotation = nil }
        }, redo: {
            page.addAnnotation(annotation)
        })
    }

    private func removeRaw(_ annotation: PDFAnnotation, name: String) {
        guard let page = annotation.page else { return }
        let popup = annotation.popup
        page.removeAnnotation(annotation)
        if let popup, popup.page != nil { page.removeAnnotation(popup) }
        if selectedAnnotation === annotation { selectedAnnotation = nil }
        registerUndo(name, undo: {
            page.addAnnotation(annotation)
            if let popup { page.addAnnotation(popup) }
        }, redo: { [weak self] in
            page.removeAnnotation(annotation)
            if let popup { page.removeAnnotation(popup) }
            if self?.selectedAnnotation === annotation { self?.selectedAnnotation = nil }
        })
    }

    // MARK: - Public Annotation Commands

    public func add(_ annotation: PDFAnnotation, to page: PDFPage, actionName: String, select: Bool = true) {
        perform(actionName, page: page) { addRaw(annotation, to: page, name: actionName) }
        if select { self.select(annotation) }
    }

    public func remove(_ annotation: PDFAnnotation, actionName: String = "Delete") {
        let page = annotation.page
        perform(actionName, page: page) { removeRaw(annotation, name: actionName) }
    }

    public func deleteSelection() {
        guard let annotation = selectedAnnotation else { return }
        let kind = Self.kind(of: annotation)?.rawValue ?? "Annotation"
        remove(annotation, actionName: "Delete \(kind)")
    }

    /// Applies `change` and records a single undo step (no-op changes are not recorded).
    public func modify(_ annotation: PDFAnnotation, actionName: String, _ change: (PDFAnnotation) -> Void) {
        endTextEditSession()
        let before = Self.captureState(annotation)
        change(annotation)
        commitChange(annotation, from: before, actionName: actionName)
    }

    /// Records an undo step for a change that was already applied live (e.g. during a drag).
    public func commitChange(_ annotation: PDFAnnotation, from before: PDFAnnotationState, actionName: String) {
        let after = Self.captureState(annotation)
        guard after != before else {
            canvas?.refresh(page: annotation.page)
            return
        }
        perform(actionName, page: annotation.page) {
            registerUndo(actionName, undo: {
                Self.apply(before, to: annotation)
            }, redo: {
                Self.apply(after, to: annotation)
            })
        }
    }

    // Live (non-undoable) updates used while dragging; finish with `commitChange`.
    public func liveSetBounds(_ annotation: PDFAnnotation, _ rect: CGRect) {
        annotation.bounds = rect
        canvas?.refresh(page: annotation.page)
    }

    public func liveSetImageGeometry(_ image: PDFStudioImageAnnotation, center: CGPoint, size: CGSize, rotation: CGFloat) {
        image.setGeometry(center: center, size: size, rotation: rotation)
        canvas?.refresh(page: image.page)
    }

    public func liveSetLine(_ annotation: PDFAnnotation, start: CGPoint, end: CGPoint) {
        Self.setLineEndpoints(annotation, start: start, end: end)
        canvas?.refresh(page: annotation.page)
    }

    public static func offset(_ annotation: PDFAnnotation, dx: CGFloat, dy: CGFloat) {
        if let image = annotation as? PDFStudioImageAnnotation {
            let center = image.center
            image.setGeometry(center: CGPoint(x: center.x + dx, y: center.y + dy), size: image.contentSize, rotation: image.rotationDegrees)
        } else {
            annotation.bounds = annotation.bounds.offsetBy(dx: dx, dy: dy)
        }
    }

    public func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        guard let annotation = selectedAnnotation, Self.kind(of: annotation)?.isMovable == true else { return }
        modify(annotation, actionName: "Move") { Self.offset($0, dx: dx, dy: dy) }
    }

    // MARK: - Selection

    public func select(_ annotation: PDFAnnotation?) {
        if textSession?.annotation !== annotation { endTextEditSession() }
        if annotation != nil { canvas?.clearTextSelection() }
        selectedAnnotation = annotation
        if let page = annotation?.page, let doc = document {
            let index = doc.index(for: page)
            if index != NSNotFound, index != currentPageIndex { currentPageIndex = index }
        }
        canvas?.selectionChanged()
    }

    public func requestTextEditing() {
        textEditRequest &+= 1
    }

    // MARK: - Style Helpers

    func toolNSColor(_ tool: PDFAnnotationToolType? = nil) -> NSColor {
        let color = tool.flatMap { toolColors[$0] } ?? annotationColor
        return Self.nsColor(color)
    }

    static func nsColor(_ color: Color) -> NSColor {
        let ns = NSColor(color)
        return ns.usingColorSpace(.sRGB) ?? ns
    }

    private func border(_ width: CGFloat) -> PDFBorder {
        let border = PDFBorder()
        border.lineWidth = width
        return border
    }

    var currentFont: NSFont {
        NSFont(name: textFontName, size: CGFloat(textFontSize)) ?? NSFont.systemFont(ofSize: CGFloat(textFontSize))
    }

    // MARK: - Annotation Factories

    public func makeTextBox(in rect: CGRect, text: String = "Text") -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = currentFont
        annotation.fontColor = toolNSColor(.text)
        annotation.color = .clear
        annotation.alignment = .left
        annotation.border = border(0)
        annotation.bounds = Self.fittedTextBounds(annotation)
        return annotation
    }

    public func makeShape(_ tool: PDFAnnotationToolType, in rect: CGRect) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: rect, forType: tool == .circle ? .circle : .square, withProperties: nil)
        annotation.color = toolNSColor(tool)
        annotation.border = border(CGFloat(strokeWidth))
        annotation.interiorColor = shapeFillEnabled ? Self.nsColor(shapeFillColor) : nil
        return annotation
    }

    public func makeCover(in rect: CGRect) -> PDFAnnotation {
        let fill = toolNSColor(.cover)
        let annotation = PDFAnnotation(bounds: rect, forType: .square, withProperties: nil)
        annotation.color = fill
        annotation.interiorColor = fill
        annotation.border = border(0)
        annotation.contents = "Cover region"
        annotation.setValue("1", forAnnotationKey: Self.coverKey)
        return annotation
    }

    public func makeLine(from start: CGPoint, to end: CGPoint, arrow: Bool) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: CGRect(origin: start, size: CGSize(width: 1, height: 1)), forType: .line, withProperties: nil)
        let color = toolNSColor(arrow ? .arrow : .line)
        annotation.color = color
        annotation.border = border(CGFloat(strokeWidth))
        annotation.startLineStyle = .none
        annotation.endLineStyle = arrow ? .closedArrow : .none
        if arrow { annotation.interiorColor = color }
        Self.setLineEndpoints(annotation, start: start, end: end)
        return annotation
    }

    public func makeInk(points: [CGPoint]) -> PDFAnnotation? {
        guard let first = points.first else { return nil }
        var strokePoints = points
        if strokePoints.count == 1 { strokePoints.append(CGPoint(x: first.x + 0.5, y: first.y + 0.5)) }
        let width = CGFloat(strokeWidth)
        let rect = PDFEditorGeometry.boundingRect(of: strokePoints).insetBy(dx: -(width + 2), dy: -(width + 2))
        let annotation = PDFAnnotation(bounds: rect, forType: .ink, withProperties: nil)
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: CGPoint(x: strokePoints[0].x - rect.minX, y: strokePoints[0].y - rect.minY))
        for point in strokePoints.dropFirst() {
            path.line(to: CGPoint(x: point.x - rect.minX, y: point.y - rect.minY))
        }
        annotation.add(path)
        annotation.color = toolNSColor(.pen)
        annotation.border = border(width)
        return annotation
    }

    public func makeNote(at point: CGPoint, text: String = "") -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: CGRect(x: point.x, y: point.y - 24, width: 24, height: 24), forType: .text, withProperties: nil)
        annotation.iconType = .comment
        annotation.color = toolNSColor(.stickyNote)
        annotation.contents = text
        return annotation
    }

    public func makeMarkup(_ tool: PDFAnnotationToolType, in rect: CGRect) -> PDFAnnotation {
        let subtype: PDFAnnotationSubtype = tool == .underline ? .underline : (tool == .strikeout ? .strikeOut : .highlight)
        let annotation = PDFAnnotation(bounds: rect, forType: subtype, withProperties: nil)
        let base = toolNSColor(tool)
        annotation.color = subtype == .highlight ? base.withAlphaComponent(CGFloat(annotationOpacity)) : base
        annotation.quadrilateralPoints = PDFEditorGeometry.quadPoints(for: rect.size).map { NSValue(point: $0) }
        return annotation
    }

    public static func fittedTextBounds(_ annotation: PDFAnnotation) -> CGRect {
        let font = annotation.font ?? NSFont.systemFont(ofSize: 14)
        let text = (annotation.contents?.isEmpty ?? true) ? " " : (annotation.contents ?? " ")
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let current = annotation.bounds
        let natural = attributed.boundingRect(with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
        let width = max(current.width, min(ceil(natural.width) + 12, 480), 40)
        let wrapped = attributed.boundingRect(with: NSSize(width: width - 8, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
        let height = max(ceil(wrapped.height) + 8, font.pointSize + 8)
        return CGRect(x: current.minX, y: current.maxY - height, width: width, height: height)
    }

    // MARK: - High-Level Creation Commands

    /// Programmatic API (also used by tests): creates an annotation of `type` on the current page.
    @discardableResult
    public func addAnnotation(type: PDFAnnotationToolType, bounds: CGRect, text: String? = nil, points: [CGPoint]? = nil) -> PDFAnnotation? {
        guard let page = currentPage else { return nil }
        let annotation: PDFAnnotation?
        switch type {
        case .highlight, .underline, .strikeout:
            annotation = makeMarkup(type, in: bounds)
        case .text:
            annotation = makeTextBox(in: bounds, text: text ?? "Text")
        case .rectangle, .circle:
            annotation = makeShape(type, in: bounds)
        case .cover:
            annotation = makeCover(in: bounds)
        case .line, .arrow:
            if let points, points.count >= 2 {
                annotation = makeLine(from: points[0], to: points[points.count - 1], arrow: type == .arrow)
            } else {
                annotation = makeLine(from: CGPoint(x: bounds.minX, y: bounds.minY), to: CGPoint(x: bounds.maxX, y: bounds.maxY), arrow: type == .arrow)
            }
        case .pen:
            annotation = makeInk(points: points ?? [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.maxY)])
        case .stickyNote:
            annotation = makeNote(at: CGPoint(x: bounds.minX, y: bounds.maxY), text: text ?? "")
        case .select, .signatureStamp:
            annotation = nil
        }
        guard let annotation else { return nil }
        add(annotation, to: page, actionName: "Add \(type.rawValue)")
        return annotation
    }

    /// Marks up every line of `selection`. Returns the created annotations (one undo step).
    @discardableResult
    public func applyMarkup(_ tool: PDFAnnotationToolType, to selection: PDFSelection) -> [PDFAnnotation] {
        var created: [(PDFAnnotation, PDFPage)] = []
        for line in selection.selectionsByLine() {
            for page in line.pages {
                let rect = line.bounds(for: page)
                guard rect.width > 0.5, rect.height > 0.5 else { continue }
                created.append((makeMarkup(tool, in: rect), page))
            }
        }
        guard !created.isEmpty else { return [] }
        let name = "Add \(tool.rawValue)"
        perform(name) {
            for (annotation, page) in created { addRaw(annotation, to: page, name: name) }
        }
        canvas?.clearTextSelection()
        return created.map(\.0)
    }

    /// Covers each line of `selection` and places an editable replacement text box over it.
    /// The original PDF text is not modified: it stays in the file underneath the cover.
    @discardableResult
    public func replaceText(in selection: PDFSelection, with newText: String) -> PDFAnnotation? {
        var lineRects: [(PDFPage, CGRect)] = []
        for line in selection.selectionsByLine() {
            for page in line.pages {
                let rect = line.bounds(for: page)
                if rect.width > 0.5, rect.height > 0.5 { lineRects.append((page, rect)) }
            }
        }
        guard let firstPage = lineRects.first?.0 else {
            lastError = PDFEditorAlert(title: "Select Text First", message: "Select the text you want to replace on the page (Select tool, drag across the text), then choose Replace Text.")
            return nil
        }
        let firstRects = lineRects.filter { $0.0 === firstPage }.map(\.1)
        let union = firstRects.dropFirst().reduce(firstRects[0]) { $0.union($1) }
        let lineHeight = firstRects[0].height
        let fontSize = max(6, (lineHeight * 0.8).rounded())
        let font = NSFont(name: textFontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        let textBox = PDFAnnotation(bounds: union, forType: .freeText, withProperties: nil)
        textBox.contents = newText
        textBox.font = font
        textBox.fontColor = .black
        textBox.color = .clear
        textBox.border = border(0)
        textBox.bounds = Self.fittedTextBounds(textBox)
        textBox.bounds.origin.y = union.maxY - textBox.bounds.height

        let name = "Replace Text"
        perform(name, page: firstPage) {
            for (page, rect) in lineRects {
                let cover = PDFAnnotation(bounds: rect.insetBy(dx: -1, dy: -1), forType: .square, withProperties: nil)
                cover.color = .white
                cover.interiorColor = .white
                cover.border = border(0)
                cover.contents = "Cover region"
                cover.setValue("1", forAnnotationKey: Self.coverKey)
                addRaw(cover, to: page, name: name)
            }
            addRaw(textBox, to: firstPage, name: name)
        }
        canvas?.clearTextSelection()
        select(textBox)
        return textBox
    }

    // MARK: - Images & Signatures

    @discardableResult
    public func insertImage(
        data: Data,
        role: PDFStudioImageAnnotation.Role = .image,
        on targetPage: PDFPage? = nil,
        center: CGPoint? = nil,
        size: CGSize? = nil
    ) -> PDFStudioImageAnnotation? {
        guard let page = targetPage ?? currentPage else {
            lastError = PDFEditorAlert(title: "No Document", message: "Open a PDF before inserting an image.")
            return nil
        }
        guard let image = PDFStudioImageAnnotation.decode(data) else {
            lastError = PDFEditorAlert(title: "Unsupported Image", message: "The image data could not be decoded.")
            return nil
        }
        let pageBox = page.bounds(for: .cropBox)
        let objectSize = size ?? PDFStudioImageAnnotation.defaultSize(
            forPixelSize: CGSize(width: image.width, height: image.height),
            pageSize: PDFEditorGeometry.displayedPageSize(pageBox.size, rotation: page.rotation),
            maxFraction: role == .signature ? 0.35 : 0.6
        )
        let objectCenter = center ?? canvas?.visibleCenter(on: page) ?? PDFEditorGeometry.center(of: pageBox)
        // Counter-rotate on rotated pages so the image appears upright on screen.
        let upright = PDFEditorGeometry.normalizedDegrees(CGFloat(-page.rotation))
        guard let annotation = PDFStudioImageAnnotation(imageData: data, center: objectCenter, size: objectSize, rotation: upright, role: role) else {
            return nil
        }
        add(annotation, to: page, actionName: role == .signature ? "Add Signature" : "Insert Image")
        selectedAnnotationTool = .select
        return annotation
    }

    @discardableResult
    public func insertImage(from url: URL) -> PDFStudioImageAnnotation? {
        guard let data = PDFStudioImageAnnotation.normalizedImageData(contentsOf: url) else {
            lastError = PDFEditorAlert(
                title: "Unsupported Image",
                message: "“\(url.lastPathComponent)” could not be read as an image. Supported formats: PNG, JPEG, HEIC, TIFF, GIF, BMP and WebP."
            )
            return nil
        }
        return insertImage(data: data)
    }

    public func runInsertImagePanel() {
        guard document != nil else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .gif, .bmp, .webP, .image]
        panel.allowsMultipleSelection = false
        panel.prompt = "Insert"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        insertImage(from: url)
    }

    public func addSignature(image: NSImage, bounds: CGRect? = nil) {
        guard let data = PDFStudioImageAnnotation.normalizedImageData(from: image) else {
            lastError = PDFEditorAlert(title: "Signature Failed", message: "The signature image could not be prepared.")
            return
        }
        insertImage(
            data: data,
            role: .signature,
            center: bounds.map { PDFEditorGeometry.center(of: $0) },
            size: bounds?.size
        )
    }

    public func addSignatureStamp(signatureImage: NSImage, bounds: CGRect) {
        addSignature(image: signatureImage, bounds: bounds)
    }

    /// Replaces the bitmap of an inserted image object, keeping its position and rotation.
    public func replaceImage(_ image: PDFStudioImageAnnotation, with url: URL) {
        guard let data = PDFStudioImageAnnotation.normalizedImageData(contentsOf: url),
              let decoded = PDFStudioImageAnnotation.decode(data),
              let page = image.page else {
            lastError = PDFEditorAlert(title: "Unsupported Image", message: "“\(url.lastPathComponent)” could not be read as an image.")
            return
        }
        let old = image.contentSize
        let newAspect = CGFloat(decoded.width) / CGFloat(max(1, decoded.height))
        let size = CGSize(width: old.width, height: old.width / newAspect)
        guard let replacement = PDFStudioImageAnnotation(imageData: data, center: image.center, size: size, rotation: image.rotationDegrees, role: image.role) else { return }
        let name = "Replace Image"
        perform(name, page: page) {
            removeRaw(image, name: name)
            addRaw(replacement, to: page, name: name)
        }
        select(replacement)
    }

    public func setImageGeometry(_ image: PDFStudioImageAnnotation, center: CGPoint, size: CGSize, rotation: CGFloat, actionName: String = "Transform Image") {
        let safeSize = CGSize(width: max(4, size.width), height: max(4, size.height))
        modify(image, actionName: actionName) { _ in
            image.setGeometry(center: center, size: safeSize, rotation: rotation)
        }
    }

    public func rotateSelectedImage(by degrees: CGFloat) {
        guard let image = selectedAnnotation as? PDFStudioImageAnnotation else { return }
        setImageGeometry(image, center: image.center, size: image.contentSize, rotation: image.rotationDegrees + degrees, actionName: "Rotate Image")
    }

    public func resetSelectedImageAspect() {
        guard let image = selectedAnnotation as? PDFStudioImageAnnotation, image.pixelSize.width > 0 else { return }
        let aspect = image.pixelSize.width / image.pixelSize.height
        let size = CGSize(width: image.contentSize.width, height: image.contentSize.width / aspect)
        setImageGeometry(image, center: image.center, size: size, rotation: image.rotationDegrees, actionName: "Reset Aspect Ratio")
    }

    // MARK: - Property Edits (undoable)

    public func setFrame(_ annotation: PDFAnnotation, to rect: CGRect) {
        let safe = CGRect(x: rect.minX, y: rect.minY, width: max(2, rect.width), height: max(2, rect.height))
        modify(annotation, actionName: "Change Size/Position") { $0.bounds = safe }
    }

    public func setLineEndpoints(_ annotation: PDFAnnotation, start: CGPoint, end: CGPoint) {
        modify(annotation, actionName: "Move Line Endpoint") { Self.setLineEndpoints($0, start: start, end: end) }
    }

    public func setColor(_ color: NSColor, for annotation: PDFAnnotation) {
        guard let kind = Self.kind(of: annotation) else { return }
        modify(annotation, actionName: "Change Color") { annotation in
            switch kind {
            case .freeText:
                annotation.fontColor = color
            case .highlight:
                annotation.color = color.withAlphaComponent(annotation.color.alphaComponent)
            case .arrow:
                annotation.color = color
                annotation.interiorColor = color
            case .cover:
                annotation.color = color
                annotation.interiorColor = color
            default:
                annotation.color = color
            }
        }
    }

    public func setFill(_ color: NSColor?, for annotation: PDFAnnotation) {
        guard let kind = Self.kind(of: annotation) else { return }
        modify(annotation, actionName: "Change Fill") { annotation in
            switch kind {
            case .freeText:
                annotation.color = color ?? .clear
            case .cover:
                let fill = color ?? .white
                annotation.color = fill
                annotation.interiorColor = fill
            default:
                annotation.interiorColor = color
            }
        }
    }

    public func setOpacity(_ alpha: CGFloat, for annotation: PDFAnnotation) {
        modify(annotation, actionName: "Change Opacity") { $0.color = $0.color.withAlphaComponent(max(0.05, min(1, alpha))) }
    }

    public func setLineWidth(_ width: CGFloat, for annotation: PDFAnnotation) {
        let isLine = annotation.type == "Line"
        let endpoints = isLine ? Self.lineEndpoints(of: annotation) : nil
        modify(annotation, actionName: "Change Line Width") { annotation in
            let border = PDFBorder()
            border.lineWidth = max(0.25, width)
            annotation.border = border
            if let endpoints { Self.setLineEndpoints(annotation, start: endpoints.0, end: endpoints.1) }
        }
    }

    public func setArrowHead(_ enabled: Bool, for annotation: PDFAnnotation) {
        modify(annotation, actionName: enabled ? "Add Arrow Head" : "Remove Arrow Head") { annotation in
            annotation.endLineStyle = enabled ? .closedArrow : .none
            annotation.interiorColor = enabled ? annotation.color : nil
        }
    }

    public func setFont(name: String? = nil, size: CGFloat? = nil, for annotation: PDFAnnotation) {
        guard annotation.type == "FreeText" else { return }
        let current = annotation.font ?? NSFont.systemFont(ofSize: 14)
        let fontName = name ?? current.fontName
        let fontSize = max(4, min(288, size ?? current.pointSize))
        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        modify(annotation, actionName: "Change Font") { annotation in
            annotation.font = font
            annotation.bounds = Self.fittedTextBounds(annotation)
        }
    }

    /// Live text editing from the inspector; consecutive edits are coalesced into one undo step.
    public func updateText(_ text: String, for annotation: PDFAnnotation) {
        liveModify(annotation, actionName: "Edit Text", commitDelay: nil) { annotation in
            annotation.contents = text
            if annotation.type == "FreeText" {
                annotation.bounds = Self.fittedTextBounds(annotation)
            }
        }
    }

    /// Applies a continuous change (color well drags, sliders, typing). Consecutive changes with
    /// the same action name on the same annotation become a single undo step, committed when
    /// another command runs, the selection changes, or after `commitDelay` seconds of inactivity.
    public func liveModify(_ annotation: PDFAnnotation, actionName: String, commitDelay: Double? = 0.8, _ change: (PDFAnnotation) -> Void) {
        if let session = textSession, session.annotation !== annotation || session.name != actionName {
            endTextEditSession()
        }
        if textSession == nil {
            textSession = (annotation, Self.captureState(annotation), actionName)
        }
        change(annotation)
        hasUnsavedChanges = true
        revision &+= 1
        refreshUndoState()
        canvas?.refresh(page: annotation.page)
        sessionGeneration &+= 1
        if let commitDelay {
            let generation = sessionGeneration
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(commitDelay * 1_000_000_000))
                guard let self, self.sessionGeneration == generation else { return }
                self.endTextEditSession()
            }
        }
    }

    public func endTextEditSession() {
        guard let session = textSession else { return }
        textSession = nil
        commitChange(session.annotation, from: session.before, actionName: session.name)
    }

    // MARK: - Clipboard

    public var canPaste: Bool {
        guard document != nil else { return false }
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount == clipboardChangeCount, clipboardTemplate != nil { return true }
        return pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) || pasteboard.string(forType: .string) != nil
    }

    public func copySelection() {
        guard let annotation = selectedAnnotation, let template = Self.duplicate(annotation) else { return }
        clipboardTemplate = template
        pasteCount = 0
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let image = annotation as? PDFStudioImageAnnotation,
           let data = image.imageData,
           let rep = NSBitmapImageRep(data: data),
           let png = rep.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
        } else if let text = annotation.contents, !text.isEmpty {
            pasteboard.setString(text, forType: .string)
        }
        pasteboard.setData(Data(), forType: Self.annotationPasteboardType)
        clipboardChangeCount = pasteboard.changeCount
        statusMessage = "Copied \(Self.kind(of: annotation)?.rawValue ?? "annotation")"
    }

    public func cutSelection() {
        guard selectedAnnotation != nil else { return }
        copySelection()
        if let annotation = selectedAnnotation { remove(annotation, actionName: "Cut") }
    }

    public func paste() {
        guard let page = currentPage else { return }
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount == clipboardChangeCount, let template = clipboardTemplate, let copy = Self.duplicate(template) {
            pasteCount += 1
            let step = CGFloat(12 * pasteCount)
            Self.offset(copy, dx: step, dy: -step)
            add(copy, to: page, actionName: "Paste")
            return
        }
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let normalized = PDFStudioImageAnnotation.normalizedImageData(from: data) {
            insertImage(data: normalized, on: page)
            return
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let center = canvas?.visibleCenter(on: page) ?? PDFEditorGeometry.center(of: page.bounds(for: .cropBox))
            let box = makeTextBox(in: CGRect(x: center.x - 100, y: center.y, width: 200, height: 24), text: text)
            add(box, to: page, actionName: "Paste Text")
        }
    }

    public func duplicateSelection() {
        guard let annotation = selectedAnnotation, let page = annotation.page, let copy = Self.duplicate(annotation) else { return }
        Self.offset(copy, dx: 12, dy: -12)
        add(copy, to: page, actionName: "Duplicate")
    }

    public static func duplicate(_ annotation: PDFAnnotation) -> PDFAnnotation? {
        if let image = annotation as? PDFStudioImageAnnotation, let data = image.imageData {
            return PDFStudioImageAnnotation(imageData: data, center: image.center, size: image.contentSize, rotation: image.rotationDegrees, role: image.role)
        }
        return annotation.copy() as? PDFAnnotation
    }

    // MARK: - Page Operations

    private func insertPage(_ page: PDFPage, at index: Int, name: String) {
        guard let doc = document else { return }
        let target = max(0, min(index, doc.pageCount))
        perform(name, page: page) {
            doc.insert(page, at: target)
            registerUndo(name, undo: { [weak self] in
                let idx = doc.index(for: page)
                if idx != NSNotFound { doc.removePage(at: idx) }
                self?.clampCurrentPage()
            }, redo: { [weak self] in
                doc.insert(page, at: min(target, doc.pageCount))
                self?.currentPageIndex = min(target, doc.pageCount - 1)
            })
        }
        detectInteractiveForms()
        goToPage(target)
    }

    public func insertBlankPage(at index: Int? = nil) {
        guard let doc = document else { return }
        let size = currentPage?.bounds(for: .mediaBox).size ?? Self.defaultPageSize
        let page = PDFPage()
        page.setBounds(CGRect(origin: .zero, size: size), for: .mediaBox)
        insertPage(page, at: index ?? min(currentPageIndex + 1, doc.pageCount), name: "Insert Page")
    }

    public func duplicateCurrentPage() {
        guard let page = currentPage, let copy = page.copy() as? PDFPage else { return }
        PDFStudioImageAnnotation.rehydrate(page: copy)
        insertPage(copy, at: currentPageIndex + 1, name: "Duplicate Page")
    }

    public func deleteCurrentPage() {
        guard let doc = document, let page = currentPage else { return }
        guard doc.pageCount > 1 else {
            lastError = PDFEditorAlert(title: "Cannot Delete Page", message: "A PDF must keep at least one page.")
            return
        }
        let index = currentPageIndex
        if selectedAnnotation?.page === page { selectedAnnotation = nil }
        let name = "Delete Page"
        perform(name) {
            doc.removePage(at: index)
            registerUndo(name, undo: { [weak self] in
                doc.insert(page, at: min(index, doc.pageCount))
                self?.currentPageIndex = min(index, doc.pageCount - 1)
            }, redo: { [weak self] in
                let idx = doc.index(for: page)
                if idx != NSNotFound { doc.removePage(at: idx) }
                self?.clampCurrentPage()
            })
        }
        clampCurrentPage()
        detectInteractiveForms()
    }

    public func rotateCurrentPage(delta: Int = 90) {
        guard let page = currentPage else { return }
        let name = delta < 0 ? "Rotate Page Left" : "Rotate Page Right"
        perform(name, page: page) {
            page.rotation = Self.normalizedRotation(page.rotation + delta)
            registerUndo(name, undo: {
                page.rotation = Self.normalizedRotation(page.rotation - delta)
            }, redo: {
                page.rotation = Self.normalizedRotation(page.rotation + delta)
            })
        }
        canvas?.layoutDocumentView()
    }

    static func normalizedRotation(_ value: Int) -> Int {
        ((value % 360) + 360) % 360
    }

    private func clampCurrentPage() {
        guard let doc = document else { return }
        currentPageIndex = max(0, min(currentPageIndex, doc.pageCount - 1))
    }

    // MARK: - Navigation & Zoom

    public func goToPage(_ index: Int) {
        guard let doc = document, doc.pageCount > 0 else { return }
        let clamped = max(0, min(index, doc.pageCount - 1))
        currentPageIndex = clamped
        if let page = doc.page(at: clamped) { canvas?.goToPageIfNeeded(page, force: true) }
    }

    public func zoomIn() { canvas?.zoomStep(inward: true) }
    public func zoomOut() { canvas?.zoomStep(inward: false) }
    public func zoomToFitPage() { canvas?.fit(.page) }
    public func zoomToFitWidth() { canvas?.fit(.width) }
    public func zoomToActualSize() { canvas?.setZoomScale(1) }
    public func setZoomPercent(_ percent: Int) { canvas?.setZoomScale(CGFloat(percent) / 100) }

    // MARK: - Interactive Forms

    public func detectInteractiveForms() {
        guard let doc = document else {
            formFields = []
            detectedFormFields = []
            return
        }
        var fields: [PDFFormFieldInfo] = []
        for pageIndex in 0..<doc.pageCount {
            guard let page = doc.page(at: pageIndex) else { continue }
            for annotation in page.annotations where annotation.type == "Widget" {
                let kind: PDFFormFieldInfo.Kind
                switch annotation.widgetFieldType {
                case .text: kind = .text
                case .choice: kind = .choice
                case .signature: kind = .signature
                case .button:
                    switch annotation.widgetControlType {
                    case .checkBoxControl: kind = .checkbox
                    case .radioButtonControl: kind = .radio
                    default: kind = .pushButton
                    }
                default: kind = .text
                }
                let name = annotation.fieldName ?? "Field \(fields.count + 1)"
                fields.append(PDFFormFieldInfo(id: ObjectIdentifier(annotation), annotation: annotation, name: name, pageIndex: pageIndex, kind: kind))
            }
        }
        formFields = fields
        detectedFormFields = fields.map { "\($0.name) (p. \($0.pageIndex + 1))" }
    }

    public func formTextValue(_ field: PDFFormFieldInfo) -> String {
        field.annotation.widgetStringValue ?? ""
    }

    public func formIsChecked(_ field: PDFFormFieldInfo) -> Bool {
        field.annotation.buttonWidgetState == .onState
    }

    public func setFormText(_ value: String, for field: PDFFormFieldInfo) {
        let annotation = field.annotation
        let old = annotation.widgetStringValue ?? ""
        guard old != value else { return }
        let name = "Fill “\(field.name)”"
        perform(name, page: annotation.page) {
            annotation.widgetStringValue = value
            registerUndo(name, undo: { annotation.widgetStringValue = old }, redo: { annotation.widgetStringValue = value })
        }
    }

    public func setFormChecked(_ checked: Bool, for field: PDFFormFieldInfo) {
        let annotation = field.annotation
        let old = annotation.buttonWidgetState
        let new: PDFWidgetCellState = checked ? .onState : .offState
        guard old != new else { return }
        let name = "Toggle “\(field.name)”"
        perform(name, page: annotation.page) {
            annotation.buttonWidgetState = new
            registerUndo(name, undo: { annotation.buttonWidgetState = old }, redo: { annotation.buttonWidgetState = new })
        }
    }
}
