//
//  PDFStudioTests.swift
//  Borno Pulse
//
//  PDF Studio behavior tests. All fixtures are generated into a temporary folder; no user
//  document is opened or modified. Saved results are always verified by reopening the file.
//

import AppKit
import CoreText
import Foundation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

private enum PDFFixtures {
    static func makeFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BornoPDFTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes a PDF whose pages contain real (selectable) text: one marker string per page.
    @discardableResult
    static func textPDF(_ markers: [String], at url: URL, size: CGSize = CGSize(width: 612, height: 792), rotations: [Int: Int] = [:]) -> URL {
        var box = CGRect(origin: .zero, size: size)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return url }
        let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        for marker in markers {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(box)
            let attributed = NSAttributedString(string: marker, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): NSColor.black.cgColor
            ])
            let line = CTLineCreateWithAttributedString(attributed)
            context.textPosition = CGPoint(x: 72, y: size.height - 100)
            CTLineDraw(line, context)
            context.endPDFPage()
        }
        context.closePDF()
        if !rotations.isEmpty, let doc = PDFDocument(url: url) {
            for (index, rotation) in rotations { doc.page(at: index)?.rotation = rotation }
            doc.write(to: url)
        }
        return url
    }

    /// PNG with a red top half and a blue bottom half, so orientation can be checked after rendering.
    static func twoTonePNG(width: Int = 80, height: Int = 40) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: height / 2, width: width, height: height - height / 2))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        return rep.representation(using: .png, properties: [:])!
    }

    struct RGBA { let r: UInt8, g: UInt8, b: UInt8, a: UInt8 }

    /// Pixel buffer of `image`, row 0 = top row.
    final class Pixels {
        let width: Int, height: Int
        private var data: [UInt8]

        init(_ image: CGImage) {
            width = image.width
            height = image.height
            data = [UInt8](repeating: 0, count: width * height * 4)
            data.withUnsafeMutableBytes { buffer in
                let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }

        func at(_ x: Int, _ yFromTop: Int) -> RGBA {
            let x = max(0, min(width - 1, x)), y = max(0, min(height - 1, yFromTop))
            let i = (y * width + x) * 4
            return RGBA(r: data[i], g: data[i + 1], b: data[i + 2], a: data[i + 3])
        }

        /// Centroid (x, y-from-top) of pixels matching `predicate` inside `region` (pixel coordinates,
        /// y from top; whole image when nil), and their count.
        func centroid(in region: CGRect? = nil, where predicate: (RGBA) -> Bool) -> (CGPoint, Int) {
            let area = (region ?? CGRect(x: 0, y: 0, width: width, height: height)).intersection(CGRect(x: 0, y: 0, width: width, height: height))
            var sx = 0, sy = 0, n = 0
            for y in stride(from: Int(area.minY), to: Int(area.maxY), by: 2) {
                for x in stride(from: Int(area.minX), to: Int(area.maxX), by: 2) where predicate(at(x, y)) {
                    sx += x; sy += y; n += 1
                }
            }
            return n == 0 ? (.zero, 0) : (CGPoint(x: Double(sx) / Double(n), y: Double(sy) / Double(n)), n)
        }
    }

    static func isRed(_ p: RGBA) -> Bool { p.r > 180 && p.g < 80 && p.b < 80 }
    static func isBlue(_ p: RGBA) -> Bool { p.b > 180 && p.r < 80 && p.g < 80 }

    static func render(_ page: PDFPage) -> Pixels? {
        PDFToImagesService.renderImage(of: page, dpi: 72).map(Pixels.init)
    }
}

private func near(_ a: CGFloat, _ b: CGFloat, _ tolerance: CGFloat = 0.6) -> Bool { abs(a - b) <= tolerance }
private func near(_ a: CGPoint, _ b: CGPoint, _ tolerance: CGFloat = 0.6) -> Bool { near(a.x, b.x, tolerance) && near(a.y, b.y, tolerance) }
private func near(_ a: CGSize, _ b: CGSize, _ tolerance: CGFloat = 0.6) -> Bool { near(a.width, b.width, tolerance) && near(a.height, b.height, tolerance) }
private func near(_ a: CGRect, _ b: CGRect, _ tolerance: CGFloat = 0.6) -> Bool { near(a.origin, b.origin, tolerance) && near(a.size, b.size, tolerance) }

extension SmartToolTests {
    @MainActor
    static func runPDFStudioTests(_ assert: (Bool, String) -> Void) {
        let folder = PDFFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let png = PDFFixtures.twoTonePNG()

        runGeometryTests(assert)
        runSafeWriterTests(assert, folder: folder)
        runEditorModelTests(assert, folder: folder, png: png)
        runCanvasInteractionTests(assert, folder: folder, png: png)
        runStudioToolTests(assert, folder: folder, png: png)
        if let snapshotFolder = ProcessInfo.processInfo.environment["BORNO_PDF_SNAPSHOTS"] {
            writeSnapshots(to: URL(fileURLWithPath: snapshotFolder, isDirectory: true), fixtures: folder, png: png)
        }
    }

    /// Renders the real tool screens to PNG for visual review (opt-in via BORNO_PDF_SNAPSHOTS).
    @MainActor
    private static func writeSnapshots(to output: URL, fixtures: URL, png: Data) {
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let editor = PDFEditorService.shared
        let source = PDFFixtures.textPDF(["Quarterly Report", "Appendix"], at: fixtures.appendingPathComponent("snapshot.pdf"))
        editor.loadDocument(url: source)
        if let page = editor.document?.page(at: 0) {
            editor.addAnnotation(type: .highlight, bounds: CGRect(x: 70, y: 686, width: 200, height: 28))
            editor.addAnnotation(type: .arrow, bounds: .zero, points: [CGPoint(x: 330, y: 560), CGPoint(x: 260, y: 650)])
            editor.insertImage(data: png, on: page, center: CGPoint(x: 330, y: 450), size: CGSize(width: 200, height: 100))
        }
        let assembly = PDFAssemblyService.workspace(for: .mergeMixed)
        assembly.addFiles(urls: [source, fixtures.appendingPathComponent("photo.png")])

        let screens: [(String, AnyView)] = [
            ("editor", AnyView(PDFEditorWorkspaceView())),
            ("merge-mixed", AnyView(PDFAssemblyWorkspaceView(tool: .mergeMixed))),
            ("office", AnyView(PDFOfficeConvertView())),
            ("ocr", AnyView(PDFOCRToolView())),
            ("split", AnyView(PDFSplitterToolView())),
            ("metadata", AnyView(PDFMetadataToolView())),
            ("export-print", AnyView(PDFExportPrintToolView())),
            ("studio-shell", AnyView(PDFStudioWorkspaceView()))
        ]
        for (name, view) in screens {
            for (appearanceName, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                for (sizeName, size) in [("wide", NSSize(width: 1280, height: 820)), ("narrow", NSSize(width: 760, height: 720))] {
                    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.appearance = NSAppearance(named: appearance)
                    let host = NSHostingView(rootView: view.environment(\.colorScheme, appearance == .darkAqua ? .dark : .light))
                    host.frame = NSRect(origin: .zero, size: size)
                    window.contentView = host
                    window.displayIfNeeded()
                    if host.needsLayout { host.layoutSubtreeIfNeeded() }
                    if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                        host.cacheDisplay(in: host.bounds, to: rep)
                        try? rep.representation(using: .png, properties: [:])?
                            .write(to: output.appendingPathComponent("\(name)-\(appearanceName)-\(sizeName).png"))
                    }
                    window.close()
                }
            }
        }
        assembly.clearAllPages()
        editor.closeDocument()
    }

    // MARK: - 125. Geometry

    @MainActor
    private static func runGeometryTests(_ assert: (Bool, String) -> Void) {
        let corners = PDFEditorGeometry.rotatedCorners(center: CGPoint(x: 100, y: 100), size: CGSize(width: 100, height: 50), degrees: 0)
        assert(corners.count == 4 && near(corners[0], CGPoint(x: 50, y: 75)) && near(corners[2], CGPoint(x: 150, y: 125)),
               "PDF geometry: unrotated corners are BL…TR of the object rect")

        let swapped = PDFEditorGeometry.rotatedBounds(center: CGPoint(x: 100, y: 100), size: CGSize(width: 100, height: 50), degrees: 90)
        assert(near(swapped.size, CGSize(width: 50, height: 100)), "PDF geometry: 90° rotation swaps the bounding box")

        assert(PDFEditorGeometry.contains(CGPoint(x: 100, y: 140), center: CGPoint(x: 100, y: 100), size: CGSize(width: 100, height: 20), degrees: 90)
               && !PDFEditorGeometry.contains(CGPoint(x: 140, y: 100), center: CGPoint(x: 100, y: 100), size: CGSize(width: 100, height: 20), degrees: 90),
               "PDF geometry: hit-testing follows the rotated shape, not its bounding box")

        let resized = PDFEditorGeometry.resize(center: CGPoint(x: 100, y: 100), size: CGSize(width: 100, height: 50), degrees: 0,
                                               corner: 2, to: CGPoint(x: 200, y: 150), lockAspect: false)
        let anchor = PDFEditorGeometry.rotatedCorners(center: resized.center, size: resized.size, degrees: 0)[0]
        assert(near(resized.size, CGSize(width: 150, height: 75)) && near(anchor, CGPoint(x: 50, y: 75)),
               "PDF geometry: corner resize keeps the opposite corner anchored")

        let locked = PDFEditorGeometry.resize(center: CGPoint(x: 100, y: 100), size: CGSize(width: 100, height: 50), degrees: 0,
                                              corner: 2, to: CGPoint(x: 250, y: 130), lockAspect: true)
        assert(near(locked.size.width / locked.size.height, 2, 0.01), "PDF geometry: aspect-locked resize preserves the 2:1 ratio")

        let before = PDFEditorGeometry.rotatedCorners(center: CGPoint(x: 300, y: 300), size: CGSize(width: 120, height: 60), degrees: 30)
        let rotatedResize = PDFEditorGeometry.resize(center: CGPoint(x: 300, y: 300), size: CGSize(width: 120, height: 60), degrees: 30,
                                                     corner: 1, to: CGPoint(x: before[1].x + 20, y: before[1].y - 10), lockAspect: false)
        let after = PDFEditorGeometry.rotatedCorners(center: rotatedResize.center, size: rotatedResize.size, degrees: 30)
        assert(near(after[3], before[3], 0.01), "PDF geometry: resizing a rotated object anchors the opposite corner in page space")

        assert(PDFEditorGeometry.displayedPageSize(CGSize(width: 612, height: 792), rotation: 90) == CGSize(width: 792, height: 612)
               && PDFEditorGeometry.displayedPageSize(CGSize(width: 612, height: 792), rotation: 180) == CGSize(width: 612, height: 792),
               "PDF geometry: displayed page size accounts for /Rotate")

        let widthScale = PDFEditorGeometry.fitScale(pageSize: CGSize(width: 612, height: 792), rotation: 0, viewport: CGSize(width: 644, height: 400), mode: .width, padding: 16)
        let pageScale = PDFEditorGeometry.fitScale(pageSize: CGSize(width: 612, height: 792), rotation: 90, viewport: CGSize(width: 824, height: 2000), mode: .page, padding: 16)
        assert(near(widthScale, 1, 0.001) && near(pageScale, 1, 0.001), "PDF geometry: fit-to-width and fit-to-page scales (including rotated pages)")

        let kept = PDFEditorGeometry.keepVisible(CGRect(x: -500, y: 900, width: 100, height: 100), in: CGRect(x: 0, y: 0, width: 612, height: 792))
        assert(kept.intersects(CGRect(x: 0, y: 0, width: 612, height: 792)), "PDF geometry: dragged objects cannot be lost off the page")
        assert(PDFEditorGeometry.quadPoints(for: CGSize(width: 10, height: 5)).count == 4, "PDF geometry: markup quad points have four corners")
    }

    // MARK: - 126. Safe Writing & Validation

    @MainActor
    private static func runSafeWriterTests(_ assert: (Bool, String) -> Void, folder: URL) {
        let ranges = try? PDFSafeWriter.parsePageRanges("1-3, 5", pageCount: 6)
        assert(ranges == [[0, 1, 2], [4]], "Page ranges: “1-3, 5” parses to pages 1–3 and 5")
        let invalid = ["0", "7", "3-1", "abc", "", "2-"].filter { (try? PDFSafeWriter.parsePageRanges($0, pageCount: 6)) == nil }
        assert(invalid.count == 6, "Page ranges: zero, out-of-range, backwards, non-numeric and empty input are rejected (not clamped)")

        let source = PDFFixtures.textPDF(["Alpha page", "Beta page"], at: folder.appendingPathComponent("writer.pdf"))
        let doc = PDFDocument(url: source)!

        let missingFolder = folder.appendingPathComponent("missing/out.pdf")
        assert((try? PDFSafeWriter.write(doc, to: missingFolder)) == nil, "Safe writer: a missing destination folder is reported as an error")

        let lockedFolder = folder.appendingPathComponent("readonly", isDirectory: true)
        try? FileManager.default.createDirectory(at: lockedFolder, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: lockedFolder.path)
        var lockedError: Error?
        do { try PDFSafeWriter.write(doc, to: lockedFolder.appendingPathComponent("out.pdf")) } catch { lockedError = error }
        assert(lockedError != nil && !(lockedError?.localizedDescription.isEmpty ?? true), "Safe writer: an unwritable destination fails with a readable message")
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: lockedFolder.path)

        let existing = folder.appendingPathComponent("existing.pdf")
        try? PDFSafeWriter.write(doc, to: existing)
        assert((try? PDFSafeWriter.write(data: Data("not a pdf".utf8), to: existing)) == nil && PDFDocument(url: existing)?.pageCount == 2,
               "Safe writer: invalid output is rejected and the existing file stays intact")

        assert(PDFSafeWriter.uniqueURL(for: existing).lastPathComponent == "existing 2.pdf", "Safe writer: unique names never overwrite existing files")

        let garbage = folder.appendingPathComponent("garbage.pdf")
        try? Data("%PDF-garbage".utf8).write(to: garbage)
        var garbageError: PDFStudioError?
        do { _ = try PDFSafeWriter.openReadable(garbage) } catch { garbageError = error as? PDFStudioError }
        assert(garbageError == .unreadableFile("garbage.pdf"), "Invalid files: a damaged PDF is reported as unreadable")

        let encrypted = folder.appendingPathComponent("locked.pdf")
        doc.write(to: encrypted, withOptions: [.userPasswordOption: "secret", .ownerPasswordOption: "secret"])
        var lockedPDFError: PDFStudioError?
        do { _ = try PDFSafeWriter.openReadable(encrypted) } catch { lockedPDFError = error as? PDFStudioError }
        if case .passwordProtected = lockedPDFError {
            assert(true, "Invalid files: a password-protected PDF is reported as locked")
        } else {
            assert(false, "Invalid files: a password-protected PDF is reported as locked")
        }

        assert(FileDropZoneView.accepts(source, allowedTypes: [.pdf])
               && !FileDropZoneView.accepts(folder.appendingPathComponent("notes.txt"), allowedTypes: [.pdf])
               && FileDropZoneView.accepts(folder.appendingPathComponent("photo.png"), allowedTypes: [.image]),
               "Drop zone: unsupported file types are filtered out instead of passed to the tool")
    }

    // MARK: - 127. Editor Model: Images, Annotations, Undo, Save & Reopen

    @MainActor
    private static func runEditorModelTests(_ assert: (Bool, String) -> Void, folder: URL, png: Data) {
        let original = PDFFixtures.textPDF(["Page One Marker", "Page Two Marker", "Page Three Marker"], at: folder.appendingPathComponent("source.pdf"))
        let originalBytes = try? Data(contentsOf: original)
        let editor = PDFEditorService()

        guard case .opened = editor.loadDocument(url: original), let doc = editor.document, let page = doc.page(at: 0) else {
            assert(false, "Editor: multi-page fixture opens")
            return
        }
        assert(doc.pageCount == 3 && !editor.hasUnsavedChanges && !editor.canUndo, "Editor: multi-page PDF opens clean with 3 pages")

        if case .failed = editor.loadDocument(url: folder.appendingPathComponent("garbage.pdf")) {
            assert(editor.document === doc, "Editor: a damaged file is rejected and the open document is kept")
        } else {
            assert(false, "Editor: a damaged file is rejected and the open document is kept")
        }

        // Image insert / select / hit priority
        guard let image = editor.insertImage(data: png, on: page, center: CGPoint(x: 200, y: 300), size: CGSize(width: 100, height: 50)) else {
            assert(false, "Editor: image inserts as a PDF object")
            return
        }
        assert(page.annotations.contains { $0 === image } && editor.selectedAnnotation === image && editor.selectedKind == .image,
               "Editor: inserted image is a page object and becomes the selection")
        assert(editor.hasUnsavedChanges && editor.canUndo && editor.undoActionName == "Insert Image", "Editor: inserting marks the document edited and is undoable")

        let overlay = editor.addAnnotation(type: .rectangle, bounds: CGRect(x: 150, y: 250, width: 120, height: 120))
        let hits = editor.hitTest(page: page, point: CGPoint(x: 200, y: 300))
        assert(hits.first === image && hits.contains { $0 === overlay }, "Editor: hit priority puts images above overlapping annotations")
        if let overlay { editor.remove(overlay) }

        // Move / resize / rotate with undo and redo
        editor.select(image)
        editor.setImageGeometry(image, center: CGPoint(x: 250, y: 350), size: image.contentSize, rotation: 0, actionName: "Move Image")
        assert(near(image.center, CGPoint(x: 250, y: 350)), "Editor: image moves to the requested page position")
        editor.undo()
        assert(near(image.center, CGPoint(x: 200, y: 300)), "Editor: undo restores the image position")
        editor.redo()
        assert(near(image.center, CGPoint(x: 250, y: 350)), "Editor: redo re-applies the move")

        editor.setImageGeometry(image, center: image.center, size: CGSize(width: 160, height: 80), rotation: 0, actionName: "Resize Image")
        assert(near(image.contentSize, CGSize(width: 160, height: 80)), "Editor: image resizes")
        editor.rotateSelectedImage(by: 90)
        assert(near(image.rotationDegrees, 90) && near(image.bounds.size, CGSize(width: 80, height: 160), 1), "Editor: rotating 90° turns the object and its bounds")
        editor.undo()
        assert(near(image.rotationDegrees, 0) && near(image.contentSize, CGSize(width: 160, height: 80)), "Editor: undo reverses the rotation only")
        editor.redo()

        // Delete and undo
        editor.select(image)
        editor.deleteSelection()
        assert(!page.annotations.contains { $0 === image } && editor.selectedAnnotation == nil, "Editor: Delete removes the selected image")
        editor.undo()
        assert(page.annotations.contains { $0 === image }, "Editor: undo restores a deleted image")

        // Duplicate (copy/paste without touching the user's clipboard)
        editor.select(image)
        editor.duplicateSelection()
        let studioImages = page.annotations.compactMap { $0 as? PDFStudioImageAnnotation }
        assert(studioImages.count == 2 && studioImages.contains { near($0.center, CGPoint(x: image.center.x + 12, y: image.center.y - 12)) },
               "Editor: duplicate creates an offset copy of the image")
        editor.undo()

        // Annotations
        let text = editor.addAnnotation(type: .text, bounds: CGRect(x: 72, y: 500, width: 200, height: 30), text: "Hello")
        assert(text?.type == "FreeText" && text?.contents == "Hello", "Editor: text box is created with its content")
        if let text {
            editor.select(text)
            editor.updateText("Hello World", for: text)
            editor.updateText("Hello World!", for: text)
            editor.endTextEditSession()
            assert(text.contents == "Hello World!", "Editor: text content edits apply live")
            editor.undo()
            assert(text.contents == "Hello", "Editor: consecutive text edits undo as one step")
            editor.redo()
            editor.setFont(name: "Helvetica-Bold", size: 20, for: text)
            assert(text.font?.pointSize == 20 && text.font?.fontName == "Helvetica-Bold", "Editor: font family and size apply to a text box")
            editor.setColor(.systemGreen, for: text)
        }

        let arrow = editor.addAnnotation(type: .arrow, bounds: .zero, points: [CGPoint(x: 100, y: 100), CGPoint(x: 220, y: 160)])
        if let arrow {
            let (start, end) = PDFEditorService.lineEndpoints(of: arrow)
            assert(near(start, CGPoint(x: 100, y: 100)) && near(end, CGPoint(x: 220, y: 160)), "Editor: arrow stores page-space endpoints")
            editor.setLineEndpoints(arrow, start: CGPoint(x: 110, y: 90), end: CGPoint(x: 300, y: 200))
        } else {
            assert(false, "Editor: arrow stores page-space endpoints")
        }

        let highlight = editor.addAnnotation(type: .highlight, bounds: CGRect(x: 72, y: 680, width: 150, height: 20))
        assert(highlight?.type == "Highlight" && highlight?.quadrilateralPoints?.count == 4, "Editor: highlight markup has quad points")
        let ink = editor.addAnnotation(type: .pen, bounds: .zero, points: [CGPoint(x: 300, y: 600), CGPoint(x: 320, y: 620), CGPoint(x: 340, y: 600)])
        assert(ink?.type == "Ink" && !(ink?.paths?.isEmpty ?? true), "Editor: freehand drawing creates an ink path")
        let note = editor.addAnnotation(type: .stickyNote, bounds: CGRect(x: 500, y: 700, width: 20, height: 20), text: "Review this")
        assert(note?.type == "Text" && note?.contents == "Review this", "Editor: sticky note keeps its comment")
        let cover = editor.addAnnotation(type: .cover, bounds: CGRect(x: 70, y: 690, width: 200, height: 30))
        assert(cover.map { PDFEditorService.kind(of: $0) } == .cover, "Editor: cover region is classified as a cover, not a shape")

        // Undo stack depth
        func onPage(_ annotation: PDFAnnotation?) -> Bool { page.annotations.contains { $0 === annotation } }
        editor.undo()
        assert(!onPage(cover) && onPage(note), "Editor: first undo removes only the most recent annotation")
        editor.undo()
        assert(!onPage(note) && !page.annotations.contains { $0.type == "Popup" } && onPage(ink),
               "Editor: second undo removes the sticky note together with its popup")
        editor.redo(); editor.redo()
        assert(onPage(note) && onPage(cover), "Editor: redo restores them")

        // Page operations
        editor.goToPage(1)
        editor.rotateCurrentPage(delta: 90)
        assert(doc.page(at: 1)?.rotation == 90, "Editor: rotate page")
        editor.insertBlankPage(at: 3)
        assert(doc.pageCount == 4, "Editor: insert blank page")
        editor.undo()
        assert(doc.pageCount == 3, "Editor: undo insert page")

        // Save failure keeps state
        let lockedFolder = folder.appendingPathComponent("readonly", isDirectory: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: lockedFolder.path)
        let failed = editor.save(as: lockedFolder.appendingPathComponent("edited.pdf"))
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: lockedFolder.path)
        if case .failure = failed {
            assert(editor.hasUnsavedChanges && editor.sourceURL == original && editor.lastError != nil, "Save: failure is reported and the document stays dirty")
        } else {
            assert(false, "Save: failure is reported and the document stays dirty")
        }

        // Save As and reopen
        let saved = folder.appendingPathComponent("edited.pdf")
        let savedImageCenter = image.center
        guard case .success = editor.save(as: saved) else {
            assert(false, "Save As: writes the edited document")
            return
        }
        assert(!editor.hasUnsavedChanges && editor.sourceURL == saved, "Save As: document becomes clean and adopts the new location")
        assert((try? Data(contentsOf: original)) == originalBytes, "Save As: the original source PDF is untouched")

        guard let reopened = PDFDocument(url: saved), let reopenedPage = reopened.page(at: 0) else {
            assert(false, "Save As: saved file reopens")
            return
        }
        PDFStudioImageAnnotation.rehydrate(document: reopened)
        let reImages = reopenedPage.annotations.compactMap { $0 as? PDFStudioImageAnnotation }
        assert(reImages.count == 1 && near(reImages[0].center, savedImageCenter) && near(reImages[0].contentSize, CGSize(width: 160, height: 80))
               && near(reImages[0].rotationDegrees, 90), "Reopen: image keeps position, size and rotation and is editable again")
        assert(reopened.pageCount == 3 && reopened.page(at: 1)?.rotation == 90, "Reopen: page rotation persists")
        let reText = reopenedPage.annotations.first { $0.type == "FreeText" }
        assert(reText?.contents == "Hello World!" && reText?.font?.pointSize == 20, "Reopen: text box content and font persist")
        if let reArrow = reopenedPage.annotations.first(where: { $0.type == "Line" }) {
            let (s, e) = PDFEditorService.lineEndpoints(of: reArrow)
            assert(near(s, CGPoint(x: 110, y: 90), 1) && near(e, CGPoint(x: 300, y: 200), 1), "Reopen: edited arrow endpoints persist")
        } else {
            assert(false, "Reopen: edited arrow endpoints persist")
        }
        assert(reopenedPage.annotations.contains { $0.type == "Highlight" } && reopenedPage.annotations.contains { $0.type == "Ink" }
               && reopenedPage.annotations.contains { $0.type == "Text" && $0.contents == "Review this" },
               "Reopen: highlight, ink and sticky note persist")
        assert(reopenedPage.string?.contains("Page One Marker") == true && (reopenedPage.string?.components(separatedBy: "Page One Marker").count ?? 0) == 2,
               "Reopen: original page text is preserved once (no duplicate text layer)")

        if let pixels = PDFFixtures.render(reopenedPage) {
            let expectedX = savedImageCenter.x
            let expectedY = 792 - savedImageCenter.y
            let imageArea = CGRect(x: expectedX - 90, y: expectedY - 90, width: 180, height: 180)
            let (red, redCount) = pixels.centroid(in: imageArea, where: PDFFixtures.isRed)
            let (blue, blueCount) = pixels.centroid(in: imageArea, where: PDFFixtures.isBlue)
            assert(redCount > 50 && blueCount > 50 && near(CGPoint(x: (red.x + blue.x) / 2, y: (red.y + blue.y) / 2), CGPoint(x: expectedX, y: expectedY), 4),
                   "Reopen: rendered image pixels appear at the saved page position")
            // Rotated 90° clockwise: the image's top (red) points right on the page.
            assert(red.x > blue.x + 10 && abs(red.y - blue.y) < 4, "Reopen: rendered image keeps its 90° clockwise rotation")
        } else {
            assert(false, "Reopen: rendered image pixels appear at the saved page position")
        }

        let editor2 = PDFEditorService()
        editor2.loadDocument(url: saved)
        let editorImage = editor2.document?.page(at: 0)?.annotations.first { $0 is PDFStudioImageAnnotation }
        assert(editorImage != nil && !editor2.hasUnsavedChanges, "Reopen in editor: inserted images are rehydrated as selectable objects")

        // Flattened export
        let flat = folder.appendingPathComponent("flat.pdf")
        if case .success = editor.exportCopy(to: flat, flatten: true), let flatDoc = PDFDocument(url: flat), let flatPage = flatDoc.page(at: 0) {
            let editableLeft = flatPage.annotations.filter { $0.type != "Popup" && $0.type != "Link" }
            let pixels = PDFFixtures.render(flatPage)
            assert(editableLeft.isEmpty && (pixels?.centroid(where: PDFFixtures.isRed).1 ?? 0) > 50,
                   "Export flattened: annotations are burned into page content and still visible")
            assert(editor.sourceURL == saved, "Export flattened: exporting a copy does not change the open document's location")
        } else {
            assert(false, "Export flattened: annotations are burned into page content and still visible")
        }

        // Rotated page: image is inserted upright and saved upright
        let rotatedURL = PDFFixtures.textPDF(["Rotated"], at: folder.appendingPathComponent("rotated.pdf"), rotations: [0: 90])
        let editor3 = PDFEditorService()
        editor3.loadDocument(url: rotatedURL)
        if let rPage = editor3.document?.page(at: 0),
           let rImage = editor3.insertImage(data: png, on: rPage, center: CGPoint(x: 300, y: 400), size: CGSize(width: 120, height: 60)) {
            assert(near(rImage.rotationDegrees, 270), "Rotated page: inserted image is counter-rotated to appear upright")
            let rSaved = folder.appendingPathComponent("rotated-edited.pdf")
            if case .success = editor3.save(as: rSaved), let rDoc = PDFDocument(url: rSaved), let rp = rDoc.page(at: 0), let pixels = PDFFixtures.render(rp) {
                let (red, redCount) = pixels.centroid(where: PDFFixtures.isRed)
                let (blue, blueCount) = pixels.centroid(where: PDFFixtures.isBlue)
                assert(pixels.width == 792 && pixels.height == 612, "Rotated page: render uses the rotated (landscape) size")
                assert(redCount > 50 && blueCount > 50 && red.y < blue.y - 10 && abs(red.x - blue.x) < 4,
                       "Rotated page: saved image renders upright (red top above blue bottom)")
                let mid = CGPoint(x: (red.x + blue.x) / 2, y: (red.y + blue.y) / 2)
                assert(near(mid, CGPoint(x: 400, y: 300), 4), "Rotated page: page-space position maps to the correct on-screen spot")
            } else {
                assert(false, "Rotated page: saved image renders upright (red top above blue bottom)")
            }
        } else {
            assert(false, "Rotated page: inserted image is counter-rotated to appear upright")
        }

        assert(!editor3.hasUnsavedChanges && editor3.confirmProceedWithUnsavedChanges(before: "testing"),
               "Unsaved changes: a saved document closes without prompting")
        editor.closeDocument()
        editor2.closeDocument()
        editor3.closeDocument()
    }

    // MARK: - 128. Canvas: real mouse events at different zoom levels and rotations

    @MainActor
    private static func runCanvasInteractionTests(_ assert: (Bool, String) -> Void, folder: URL, png: Data) {
        let url = PDFFixtures.textPDF(["Canvas Page", "Rotated Canvas Page"], at: folder.appendingPathComponent("canvas.pdf"), rotations: [1: 90])
        let editor = PDFEditorService()
        editor.loadDocument(url: url)
        guard let doc = editor.document, let page = doc.page(at: 0), let rotatedPage = doc.page(at: 1) else {
            assert(false, "Canvas: fixture opens")
            return
        }

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 1000), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let canvas = PDFEditorCanvasView(frame: NSRect(x: 0, y: 0, width: 900, height: 1000))
        canvas.autoresizingMask = [.width, .height]
        window.contentView = canvas
        canvas.service = editor
        editor.canvas = canvas
        canvas.document = doc
        canvas.setZoomScale(1)
        canvas.layoutDocumentView()
        defer {
            editor.canvas = nil
            window.close()
        }

        // Regression invariant: PDFKit's background page analyzer (PDFPageAnalyzerV2 on macOS)
        // queries [canvas document] from a background dispatch queue. Verify that calling the
        // Objective-C document getter off the main thread does not trigger a Swift 6 MainActor
        // assertion failure / SIGTRAP crash.
        let bgDoc: PDFDocument? = DispatchQueue.global(qos: .userInitiated).sync {
            let view = canvas as PDFView
            return view.perform(Selector(("document")))?.takeUnretainedValue() as? PDFDocument
        }
        assert(bgDoc === doc, "Canvas: background thread access to document getter is safe from actor assertions")

        func event(_ type: NSEvent.EventType, _ point: CGPoint, on page: PDFPage, flags: NSEvent.ModifierFlags = []) -> NSEvent {
            let viewPoint = canvas.convert(point, from: page)
            let windowPoint = canvas.convert(viewPoint, to: nil)
            return NSEvent.mouseEvent(with: type, location: windowPoint, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
                                      windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }

        func drag(from a: CGPoint, to b: CGPoint, on page: PDFPage, flags: NSEvent.ModifierFlags = []) {
            canvas.go(to: CGRect(x: min(a.x, b.x) - 40, y: min(a.y, b.y) - 40, width: abs(b.x - a.x) + 80, height: abs(b.y - a.y) + 80), on: page)
            canvas.layoutDocumentView()
            canvas.mouseDown(with: event(.leftMouseDown, a, on: page, flags: flags))
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            canvas.mouseDragged(with: event(.leftMouseDragged, mid, on: page, flags: flags))
            canvas.mouseDragged(with: event(.leftMouseDragged, b, on: page, flags: flags))
            canvas.mouseUp(with: event(.leftMouseUp, b, on: page, flags: flags))
        }

        let roundTrip = canvas.convert(canvas.convert(CGPoint(x: 123, y: 456), from: page), to: page)
        assert(near(roundTrip, CGPoint(x: 123, y: 456), 0.01), "Canvas: page ↔ view conversion round-trips at 100%")

        guard let image = editor.insertImage(data: png, on: page, center: CGPoint(x: 300, y: 500), size: CGSize(width: 100, height: 50)) else {
            assert(false, "Canvas: image inserted for interaction tests")
            return
        }
        editor.select(nil)

        for zoom in [CGFloat(1), 2, 0.5] {
            canvas.setZoomScale(zoom)
            canvas.layoutDocumentView()
            let start = image.center
            drag(from: start, to: CGPoint(x: start.x + 40, y: start.y - 30), on: page)
            assert(editor.selectedAnnotation === image && near(image.center, CGPoint(x: start.x + 40, y: start.y - 30), 1.5),
                   "Canvas: dragging an image moves it by the same page distance at \(Int(zoom * 100))% zoom")
        }
        assert(editor.undoActionName == "Move Image", "Canvas: a drag is recorded as one undoable move")
        let beforeUndo = image.center
        editor.undo()
        assert(near(image.center, CGPoint(x: beforeUndo.x - 40, y: beforeUndo.y + 30), 1.5), "Canvas: undo reverts the whole drag")
        editor.redo()

        canvas.setZoomScale(1)
        canvas.layoutDocumentView()
        editor.select(image)
        let anchor = image.rotatedCorners[0]
        let topRight = image.rotatedCorners[2]
        drag(from: topRight, to: CGPoint(x: topRight.x + 50, y: topRight.y + 25), on: page)
        assert(near(image.rotatedCorners[0], anchor, 1.5) && near(image.contentSize, CGSize(width: 150, height: 75), 2),
               "Canvas: dragging a corner handle resizes with the aspect ratio locked and the opposite corner fixed")

        editor.rotateSelectedImage(by: 45)
        let rotatedCenter = image.center
        drag(from: rotatedCenter, to: CGPoint(x: rotatedCenter.x - 20, y: rotatedCenter.y + 20), on: page)
        assert(near(image.center, CGPoint(x: rotatedCenter.x - 20, y: rotatedCenter.y + 20), 1.5) && near(image.rotationDegrees, 45),
               "Canvas: a rotated image can be selected and moved")

        editor.selectedAnnotationTool = .rectangle
        drag(from: CGPoint(x: 80, y: 150), to: CGPoint(x: 200, y: 250), on: page)
        let rect = page.annotations.last
        assert(rect?.type == "Square" && near(rect?.bounds.origin ?? .zero, CGPoint(x: 80, y: 150), 3) && near(rect?.bounds.size ?? .zero, CGSize(width: 120, height: 100), 3),
               "Canvas: drawing a rectangle creates it at the dragged page rectangle")

        editor.selectedAnnotationTool = .line
        drag(from: CGPoint(x: 100, y: 300), to: CGPoint(x: 260, y: 340), on: page)
        if let line = page.annotations.last, line.type == "Line" {
            let (s, e) = PDFEditorService.lineEndpoints(of: line)
            assert(near(s, CGPoint(x: 100, y: 300), 1.5) && near(e, CGPoint(x: 260, y: 340), 1.5), "Canvas: drawing a line stores the dragged endpoints")
        } else {
            assert(false, "Canvas: drawing a line stores the dragged endpoints")
        }

        editor.selectedAnnotationTool = .pen
        drag(from: CGPoint(x: 400, y: 200), to: CGPoint(x: 480, y: 260), on: page)
        assert(page.annotations.last?.type == "Ink", "Canvas: freehand drawing creates an ink annotation")

        // Overlap: image wins; option-click cycles to the annotation underneath.
        editor.selectedAnnotationTool = .select
        let overlapRect = editor.addAnnotation(type: .rectangle, bounds: CGRect(x: image.center.x - 20, y: image.center.y - 20, width: 40, height: 40))
        editor.select(nil)
        canvas.mouseDown(with: event(.leftMouseDown, image.center, on: page))
        canvas.mouseUp(with: event(.leftMouseUp, image.center, on: page))
        assert(editor.selectedAnnotation === image, "Canvas: clicking where an image overlaps an annotation selects the image")
        canvas.mouseDown(with: event(.leftMouseDown, image.center, on: page, flags: .option))
        canvas.mouseUp(with: event(.leftMouseUp, image.center, on: page, flags: .option))
        assert(editor.selectedAnnotation === overlapRect, "Canvas: ⌥-click cycles to the overlapping annotation underneath")

        // Rotated page interactions
        editor.goToPage(1)
        canvas.go(to: rotatedPage)
        canvas.layoutDocumentView()
        assert(near(canvas.convert(canvas.convert(CGPoint(x: 200, y: 300), from: rotatedPage), to: rotatedPage), CGPoint(x: 200, y: 300), 0.01),
               "Canvas: conversion round-trips on a 90°-rotated page")
        editor.selectedAnnotationTool = .rectangle
        drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 220, y: 180), on: rotatedPage)
        let rotatedRect = rotatedPage.annotations.last
        assert(rotatedRect?.type == "Square" && near(rotatedRect?.bounds ?? .zero, CGRect(x: 100, y: 100, width: 120, height: 80), 3),
               "Canvas: shapes drawn on a rotated page land at the dragged page coordinates")
        if let rImage = editor.insertImage(data: png, on: rotatedPage, center: CGPoint(x: 300, y: 300), size: CGSize(width: 80, height: 40)) {
            editor.selectedAnnotationTool = .select
            drag(from: CGPoint(x: 300, y: 300), to: CGPoint(x: 330, y: 360), on: rotatedPage)
            assert(near(rImage.center, CGPoint(x: 330, y: 360), 1.5), "Canvas: images on a rotated page move in page space")
        } else {
            assert(false, "Canvas: images on a rotated page move in page space")
        }

        // Window resize and zoom controls
        window.setContentSize(NSSize(width: 600, height: 700))
        canvas.layoutDocumentView()
        assert(near(canvas.convert(canvas.convert(CGPoint(x: 50, y: 60), from: page), to: page), CGPoint(x: 50, y: 60), 0.01),
               "Canvas: conversion stays correct after the window is resized")
        canvas.setZoomScale(1)
        editor.zoomIn()
        assert(canvas.scaleFactor > 1.05 && editor.zoomPercent == Int((canvas.scaleFactor * 100).rounded()), "Canvas: zoom in steps up and updates the zoom percentage")
        editor.zoomOut(); editor.zoomOut()
        assert(canvas.scaleFactor < 0.95, "Canvas: zoom out steps down")
        editor.goToPage(0)
        editor.zoomToFitWidth()
        let fitWidth = canvas.scaleFactor
        editor.zoomToFitPage()
        assert(fitWidth > 0.3 && canvas.scaleFactor > 0.3 && canvas.scaleFactor <= fitWidth + 0.001, "Canvas: fit-to-width and fit-to-page produce sensible scales")

        // Selection overlay draws in both Light and Dark appearances
        editor.select(image)
        canvas.setZoomScale(1)
        canvas.go(to: page)
        canvas.layoutDocumentView()
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            window.appearance = NSAppearance(named: name)
            canvas.overlay.frame = canvas.bounds
            guard let rep = canvas.overlay.bitmapImageRepForCachingDisplay(in: canvas.overlay.bounds) else { continue }
            canvas.overlay.cacheDisplay(in: canvas.overlay.bounds, to: rep)
            var drawn = 0, bright = 0
            for y in stride(from: 0, to: rep.pixelsHigh, by: 3) {
                for x in stride(from: 0, to: rep.pixelsWide, by: 3) {
                    guard let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.5 else { continue }
                    drawn += 1
                    if color.brightnessComponent > 0.9 { bright += 1 }
                }
            }
            assert(drawn > 20 && bright > 0, "Canvas: selection outline and handles render with a white under-stroke in \(name == .aqua ? "Light" : "Dark") mode")
        }
        editor.closeDocument()
    }

    // MARK: - 129. Studio Tools

    @MainActor
    private static func runStudioToolTests(_ assert: (Bool, String) -> Void, folder: URL, png: Data) {
        let pdfA = PDFFixtures.textPDF(["Merge A1", "Merge A2"], at: folder.appendingPathComponent("A.pdf"))
        if let doc = PDFDocument(url: pdfA), let first = doc.page(at: 0) {
            let note = PDFAnnotation(bounds: CGRect(x: 72, y: 600, width: 200, height: 30), forType: .freeText, withProperties: nil)
            note.contents = "Annotated A1"
            note.font = NSFont(name: "Helvetica", size: 12)
            first.addAnnotation(note)
            doc.write(to: pdfA)
        }
        let pdfB = PDFFixtures.textPDF(["Merge B1"], at: folder.appendingPathComponent("B.pdf"), rotations: [0: 90])
        let pngURL = folder.appendingPathComponent("photo.png")
        try? png.write(to: pngURL)
        let fakePDF = folder.appendingPathComponent("fake.pdf")
        try? Data("garbage".utf8).write(to: fakePDF)

        // Merge mixed
        let mixed = PDFAssemblyService()
        mixed.acceptedTypes = PDFAssemblyService.acceptedTypes(for: .mergeMixed)
        let report = mixed.addFiles(urls: [pdfA, pdfB, pngURL, fakePDF])
        assert(mixed.pages.count == 4 && report.failed.count == 1 && mixed.importIssues != nil, "Merge: PDFs and images import; a damaged PDF is reported, not ignored")
        assert(mixed.pages.first { $0.sourceURL == pdfB }?.rotationAngle == 90, "Merge: imported pages keep their existing rotation")

        let pdfOnly = PDFAssemblyService()
        pdfOnly.acceptedTypes = PDFAssemblyService.acceptedTypes(for: .mergePDFs)
        let skipped = pdfOnly.addFiles(urls: [pngURL])
        assert(pdfOnly.pages.isEmpty && skipped.skippedUnsupported == ["photo.png"], "Merge PDFs: images are rejected with a message, not silently dropped")

        if let imageItem = mixed.pages.first(where: { $0.sourceType == .image }) {
            mixed.movePage(id: imageItem.id, before: mixed.pages[0].id)
        }
        if let a2 = mixed.pages.first(where: { $0.originalPageIndex == 1 && $0.sourceURL == pdfA }) {
            mixed.rotatePage(id: a2.id, delta: 90)
        }
        let mergedURL = folder.appendingPathComponent("merged.pdf")
        if case .success = mixed.exportMergedDocument(to: mergedURL), let merged = PDFDocument(url: mergedURL) {
            assert(merged.pageCount == 4, "Merge: exported file reopens with every page")
            assert(merged.page(at: 0)?.string?.isEmpty ?? true, "Merge: reordered image page comes first")
            assert(merged.page(at: 1)?.string?.contains("Merge A1") == true && merged.page(at: 3)?.string?.contains("Merge B1") == true,
                   "Merge: PDF pages keep their text in the chosen order")
            assert(merged.page(at: 2)?.rotation == 90 && merged.page(at: 3)?.rotation == 90, "Merge: rotation edits and original rotation are kept")
            assert(merged.page(at: 1)?.annotations.contains { $0.contents == "Annotated A1" } == true, "Merge: page annotations are preserved")
            if let imagePage = merged.page(at: 0), let pixels = PDFFixtures.render(imagePage) {
                let (red, _) = pixels.centroid(where: PDFFixtures.isRed)
                let (blue, _) = pixels.centroid(where: PDFFixtures.isBlue)
                assert(red.y < blue.y, "Images to PDF: image pages are upright")
            }
        } else {
            assert(false, "Merge: exported file reopens with every page")
        }
        assert(PDFDocument(url: pdfA)?.pageCount == 2, "Merge: source PDFs are not modified")

        // Split & extract
        let pdfC = PDFFixtures.textPDF(["Split 1", "Split 2", "Split 3", "Split 4", "Split 5"], at: folder.appendingPathComponent("C.pdf"))
        let splitFolder = folder.appendingPathComponent("split", isDirectory: true)
        try? FileManager.default.createDirectory(at: splitFolder, withIntermediateDirectories: true)
        let each = (try? PDFAssemblyService.split(sourceURL: pdfC, mode: "each", interval: 1, rangesText: "", destinationFolder: splitFolder)) ?? []
        assert(each.count == 5 && each.allSatisfy { PDFDocument(url: $0)?.pageCount == 1 }, "Split: every page becomes its own verified PDF")
        let ranges = (try? PDFAssemblyService.split(sourceURL: pdfC, mode: "range", interval: 1, rangesText: "1-2, 5", destinationFolder: splitFolder)) ?? []
        assert(ranges.map { PDFDocument(url: $0)?.pageCount ?? 0 } == [2, 1] && Set(ranges).isDisjoint(with: Set(each)),
               "Split: custom ranges produce one file per range without overwriting earlier output")
        let chunks = (try? PDFAssemblyService.split(sourceURL: pdfC, mode: "interval", interval: 2, rangesText: "", destinationFolder: splitFolder)) ?? []
        assert(chunks.map { PDFDocument(url: $0)?.pageCount ?? 0 } == [2, 2, 1], "Split: every-N mode groups pages")
        assert((try? PDFAssemblyService.split(sourceURL: pdfC, mode: "range", interval: 1, rangesText: "4-9", destinationFolder: splitFolder)) == nil,
               "Split: an out-of-range request fails instead of being clamped")

        let extracted = folder.appendingPathComponent("extracted.pdf")
        let extractedCount = try? PDFAssemblyService.extract(sourceURL: pdfC, pageRangesText: "3, 1", destinationURL: extracted)
        let extractedDoc = PDFDocument(url: extracted)
        assert(extractedCount == 2 && extractedDoc?.page(at: 0)?.string?.contains("Split 3") == true && extractedDoc?.page(at: 1)?.string?.contains("Split 1") == true,
               "Extract: pages are copied in the requested order")
        assert((try? PDFAssemblyService.extract(sourceURL: pdfC, pageRangesText: "1", destinationURL: pdfC)) == nil && PDFDocument(url: pdfC)?.pageCount == 5,
               "Extract: refusing to overwrite the source document")

        // Compressor
        let compressFolder = folder.appendingPathComponent("compressed", isDirectory: true)
        try? FileManager.default.createDirectory(at: compressFolder, withIntermediateDirectories: true)
        let heavy = folder.appendingPathComponent("heavy.pdf")
        do {
            var box = CGRect(x: 0, y: 0, width: 612, height: 792)
            let context = CGContext(heavy as CFURL, mediaBox: &box, nil)!
            context.beginPDFPage(nil)
            let side = 900
            var bytes = [UInt8](repeating: 0, count: side * side * 4)
            var seed: UInt32 = 12345
            for i in stride(from: 0, to: bytes.count, by: 4) {
                seed = seed &* 1664525 &+ 1013904223
                bytes[i] = UInt8(truncatingIfNeeded: seed >> 24); bytes[i + 1] = UInt8(truncatingIfNeeded: seed >> 16); bytes[i + 2] = UInt8(truncatingIfNeeded: seed >> 8); bytes[i + 3] = 255
            }
            let provider = CGDataProvider(data: Data(bytes) as CFData)!
            let noise = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
            context.draw(noise, in: CGRect(x: 72, y: 72, width: 468, height: 468))
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Compressed Text Survives", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 20, nil)
            ]))
            context.textPosition = CGPoint(x: 72, y: 700)
            CTLineDraw(line, context)
            context.endPDFPage()
            context.closePDF()
        }
        switch PDFCompressorService.compress(inputURL: heavy, outputDir: compressFolder, preset: .balanced) {
        case .success(let output):
            let text = PDFDocument(url: output.url)?.page(at: 0)?.string ?? ""
            assert(output.bytes < output.originalBytes && text.contains("Compressed Text Survives"), "Compressor: balanced preset shrinks images and keeps real text")
        case .failure(let error):
            assert(false, "Compressor: balanced preset shrinks images and keeps real text (\(error.localizedDescription))")
        }
        let tiny = PDFFixtures.textPDF(["Tiny"], at: folder.appendingPathComponent("tiny.pdf"))
        let before = (try? FileManager.default.contentsOfDirectory(atPath: compressFolder.path))?.count ?? 0
        switch PDFCompressorService.compress(inputURL: tiny, outputDir: compressFolder, preset: .highQuality) {
        case .success(let output):
            assert(output.bytes < output.originalBytes, "Compressor: output is only kept when it is actually smaller")
        case .failure(let error):
            if let studioError = error as? PDFStudioError, case .emptyResult = studioError {
                assert(((try? FileManager.default.contentsOfDirectory(atPath: compressFolder.path))?.count ?? 0) == before,
                       "Compressor: when a preset cannot shrink a file, nothing is written and the user is told")
            } else {
                assert(false, "Compressor: unexpected failure on a valid PDF (\(error.localizedDescription))")
            }
        }

        // PDF to Images
        if let rotated = PDFDocument(url: pdfB)?.page(at: 0), let image = PDFToImagesService.renderImage(of: rotated, dpi: 144) {
            assert(image.width == 1584 && image.height == 1224, "PDF to Images: rotated pages export with rotated dimensions at the chosen DPI")
        } else {
            assert(false, "PDF to Images: rotated pages export with rotated dimensions at the chosen DPI")
        }
        let pngOut = folder.appendingPathComponent("page.png")
        if let page = PDFDocument(url: pdfA)?.page(at: 0), PDFToImagesService.writeImage(of: page, dpi: 72, format: .png, to: pngOut),
           let source = CGImageSourceCreateWithURL(pngOut as CFURL, nil), let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            assert((props[kCGImagePropertyPixelWidth] as? Int) == 612, "PDF to Images: exported PNG is a valid image file")
        } else {
            assert(false, "PDF to Images: exported PNG is a valid image file")
        }
        if case .failure = PDFToImagesService.pageIndices(exportAll: false, start: 4, end: 2, pageCount: 5) {
            assert(true, "PDF to Images: an inverted page range is rejected")
        } else {
            assert(false, "PDF to Images: an inverted page range is rejected")
        }

        // OCR searchable PDF
        let scan = folder.appendingPathComponent("scan.pdf")
        do {
            let width = 1224, height = 1584
            let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            bitmap.setFillColor(.white)
            bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
            bitmap.textPosition = CGPoint(x: 140, y: 1200)
            CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: "SCANNED INVOICE 2048", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica-Bold" as CFString, 64, nil),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor.black
            ])), bitmap)
            let scanImage = bitmap.makeImage()!
            let textDoc = PDFDocument(url: PDFFixtures.textPDF(["Digital Text Page"], at: folder.appendingPathComponent("digital.pdf")))!
            var box = CGRect(x: 0, y: 0, width: 612, height: 792)
            let data = NSMutableData()
            let context = CGContext(consumer: CGDataConsumer(data: data as CFMutableData)!, mediaBox: &box, nil)!
            context.beginPDFPage(nil)
            context.draw(scanImage, in: box)
            context.endPDFPage()
            context.closePDF()
            let scanDoc = PDFDocument(data: data as Data)!
            if let digital = textDoc.page(at: 0)?.copy() as? PDFPage { scanDoc.insert(digital, at: 1) }
            scanDoc.write(to: scan)
        }
        let searchable = folder.appendingPathComponent("searchable.pdf")
        do {
            let result = try PDFOCRService.buildSearchablePDF(source: scan, destination: searchable, language: "en-US", forceOCR: false)
            let doc = PDFDocument(url: searchable)
            let scannedText = doc?.page(at: 0)?.string ?? ""
            let digitalText = doc?.page(at: 1)?.string ?? ""
            assert(result.recognizedPages == 1 && result.preservedTextPages == 1, "OCR: only pages without text are recognized")
            assert(scannedText.uppercased().contains("INVOICE"), "OCR: the scanned page becomes searchable")
            assert(digitalText.components(separatedBy: "Digital Text Page").count == 2, "OCR: pages that already had text are not given a duplicate text layer")
            if let page = doc?.page(at: 0), let pixels = PDFFixtures.render(page) {
                let dark = pixels.centroid { $0.r < 60 && $0.g < 60 && $0.b < 60 }.1
                assert(dark > 100, "OCR: the original scan remains visible beneath the invisible text")
            }
            if let selection = doc?.findString("INVOICE", withOptions: .caseInsensitive).first, let page = doc?.page(at: 0) {
                let bounds = selection.bounds(for: page)
                assert(bounds.minY > 400 && bounds.minX > 40 && bounds.minX < 300, "OCR: the invisible text is positioned over the visible words")
            } else {
                assert(false, "OCR: the invisible text is positioned over the visible words")
            }
        } catch {
            assert(false, "OCR: only pages without text are recognized (\(error.localizedDescription))")
        }
        assert((try? PDFOCRService.buildSearchablePDF(source: scan, destination: scan, language: "en-US", forceOCR: false)) == nil
               && PDFDocument(url: scan)?.page(at: 0)?.string?.isEmpty ?? true, "OCR: the source document is never overwritten")

        // Office conversion
        let office = PDFOfficeConverterService()
        let markdown = folder.appendingPathComponent("notes.md")
        try? "# Project Plan\n\nSome **bold** and *italic* text.\n\n- First item\n- Second item\n\n```\ncode block\n```\n".write(to: markdown, atomically: true, encoding: .utf8)
        let mdPDF = folder.appendingPathComponent("notes.pdf")
        if case .success = office.convertOfficeDocument(from: markdown, to: mdPDF), let text = PDFDocument(url: mdPDF)?.string {
            assert(text.contains("Project Plan") && text.contains("First item") && !text.contains("**") && !text.contains("# "),
                   "Office: Markdown is rendered (headings, emphasis, lists) instead of printed as raw syntax")
            assert(text.contains("• First item") || text.contains("•"), "Office: Markdown bullet lists keep their bullets")
        } else {
            assert(false, "Office: Markdown is rendered (headings, emphasis, lists) instead of printed as raw syntax")
        }

        let docx = folder.appendingPathComponent("report.docx")
        let longBody = (1...160).map { "Paragraph \($0): The quarterly report text continues here." }.joined(separator: "\n")
        let attributed = NSAttributedString(string: "Quarterly Report\n" + longBody, attributes: [.font: NSFont.systemFont(ofSize: 12)])
        if let data = try? attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]) {
            try? data.write(to: docx)
        }
        let docxPDF = folder.appendingPathComponent("report.pdf")
        if case .success = office.convertOfficeDocument(from: docx, to: docxPDF), let doc = PDFDocument(url: docxPDF) {
            assert(doc.string?.contains("Quarterly Report") == true && doc.string?.contains("Paragraph 160") == true, "Office: DOCX converts with all of its text")
            assert(doc.pageCount > 1, "Office: long documents paginate across multiple pages")
        } else {
            assert(false, "Office: DOCX converts with all of its text")
        }
        let unknown = folder.appendingPathComponent("data.xyz")
        try? Data("x".utf8).write(to: unknown)
        if case .failure = office.convertOfficeDocument(from: unknown, to: folder.appendingPathComponent("data.pdf")) {
            assert(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("data.pdf").path), "Office: unsupported formats fail with an error and write nothing")
        } else {
            assert(false, "Office: unsupported formats fail with an error and write nothing")
        }

        // Metadata & privacy
        let private1 = folder.appendingPathComponent("private.pdf")
        if let doc = PDFDocument(url: PDFFixtures.textPDF(["Private"], at: private1)), let page = doc.page(at: 0) {
            doc.documentAttributes = [PDFDocumentAttribute.titleAttribute: "Secret Plan", PDFDocumentAttribute.authorAttribute: "Jane Doe",
                                      PDFDocumentAttribute.keywordsAttribute: ["merger", "q3"]]
            let comment = PDFAnnotation(bounds: CGRect(x: 100, y: 100, width: 20, height: 20), forType: .text, withProperties: nil)
            comment.contents = "Check numbers"
            comment.userName = "Jane Doe"
            page.addAnnotation(comment)
            doc.write(to: private1)
        }
        let inspector = PDFMetadataInspectorService()
        let meta = inspector.inspect(url: private1)
        assert(meta.title == "Secret Plan" && meta.author == "Jane Doe" && meta.annotationAuthors == ["Jane Doe"] && meta.annotationCount == 1,
               "Metadata: report includes document properties and annotation authors")
        let clean = folder.appendingPathComponent("clean.pdf")
        if inspector.sanitizeAndExport(to: clean, options: PDFSanitizeOptions(removeAnnotationAuthors: true, removeAllAnnotations: false)),
           let cleanDoc = PDFDocument(url: clean) {
            let cleanMeta = PDFMetadataInspectorService.inspect(document: cleanDoc)
            assert(cleanMeta.title == nil && cleanMeta.author == nil && cleanMeta.keywords.isEmpty, "Metadata: sanitized copy has no title, author or keywords")
            assert(cleanMeta.annotationCount == 1 && cleanMeta.annotationAuthors.isEmpty, "Metadata: annotation author names are stripped while comments stay")
        } else {
            assert(false, "Metadata: sanitized copy has no title, author or keywords")
        }
        let stripped = folder.appendingPathComponent("stripped.pdf")
        if inspector.sanitizeAndExport(to: stripped, options: PDFSanitizeOptions(removeAnnotationAuthors: true, removeAllAnnotations: true)),
           let strippedDoc = PDFDocument(url: stripped) {
            assert(PDFMetadataInspectorService.inspect(document: strippedDoc).annotationCount == 0, "Metadata: optional removal of all comments")
        } else {
            assert(false, "Metadata: optional removal of all comments")
        }
        assert(!inspector.sanitizeAndExport(to: private1) && PDFMetadataInspectorService.inspect(document: PDFDocument(url: private1)!).title == "Secret Plan",
               "Metadata: sanitizing never replaces the original file")
        let edited = folder.appendingPathComponent("edited-meta.pdf")
        if inspector.saveEditedCopy(to: edited, title: "Public Plan", author: "", subject: "Overview", keywords: "a, b"), let editedDoc = PDFDocument(url: edited) {
            let editedMeta = PDFMetadataInspectorService.inspect(document: editedDoc)
            assert(editedMeta.title == "Public Plan" && editedMeta.author == nil && editedMeta.subject == "Overview" && editedMeta.keywords == ["a", "b"],
                   "Metadata: edited properties are saved to a copy")
        } else {
            assert(false, "Metadata: edited properties are saved to a copy")
        }
    }
}
