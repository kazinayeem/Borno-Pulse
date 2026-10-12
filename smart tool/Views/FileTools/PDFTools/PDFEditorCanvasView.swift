//
//  PDFEditorCanvasView.swift
//  Borno Pulse
//
//  Interactive PDF canvas for the Advanced PDF Editor.
//
//  Coordinate rules: mouse locations are converted window -> view with NSView.convert,
//  then view -> page with PDFView.convert(_:to:). Everything stored on annotations is in
//  PDF page space, so zoom, scrolling, Retina scale, page rotation and window resizing
//  never change saved positions. The selection overlay converts page points back to the
//  view per corner, which keeps borders correct on rotated pages.
//

import AppKit
import PDFKit
import SwiftUI

@MainActor
final class PDFEditorCanvasView: PDFView, NSMenuItemValidation {

    enum Interaction {
        case idle
        case moving(PDFAnnotation, PDFPage, start: CGPoint, before: PDFAnnotationState)
        case resizing(PDFAnnotation, PDFPage, corner: Int, before: PDFAnnotationState)
        case lineEndpoint(PDFAnnotation, PDFPage, isStart: Bool, before: PDFAnnotationState)
        case creating(PDFAnnotationToolType, PDFPage, start: CGPoint, current: CGPoint)
        case inking(PDFPage, [CGPoint])
        case markup(PDFAnnotationToolType, PDFPage, start: CGPoint, current: CGPoint)
    }

    weak var service: PDFEditorService?
    let overlay = PDFEditorOverlayView()
    private(set) var interaction: Interaction = .idle
    private var observers: [NSObjectProtocol] = []
    private weak var observedClipView: NSClipView?
    static let handleRadius: CGFloat = 6
    static let zoomSteps: [CGFloat] = [0.25, 0.33, 0.5, 0.67, 0.75, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5, 6, 8]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        autoScales = true
        displayMode = .singlePageContinuous
        displaysPageBreaks = true
        displayDirection = .vertical
        backgroundColor = .underPageBackgroundColor
        minScaleFactor = 0.1
        maxScaleFactor = 8
        overlay.canvas = self
        overlay.frame = bounds
        overlay.autoresizingMask = [.width, .height]
        addSubview(overlay)

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .PDFViewScaleChanged, object: self, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.service?.zoomPercent = Int((self.scaleFactor * 100).rounded())
                self.overlay.needsDisplay = true
            }
        })
        observers.append(center.addObserver(forName: .PDFViewPageChanged, object: self, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncCurrentPage()
            }
        })
        observers.append(center.addObserver(forName: .PDFViewDocumentChanged, object: self, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.interaction = .idle
                self?.attachScrollObserverIfNeeded()
                self?.overlay.needsDisplay = true
            }
        })
        observers.append(center.addObserver(forName: .PDFViewAnnotationWillHit, object: self, queue: .main) { [weak self] note in
            let isWidget = (note.userInfo?["PDFAnnotationHit"] as? PDFAnnotation)?.type == "Widget"
            if isWidget {
                MainActor.assumeIsolated {
                    self?.service?.markDocumentEdited()
                }
            }
        })
        observers.append(center.addObserver(forName: NSControl.textDidChangeNotification, object: nil, queue: .main) { [weak self] note in
            let field = note.object as? NSView
            MainActor.assumeIsolated {
                guard let self, let field, field.isDescendant(of: self) else { return }
                self.service?.markDocumentEdited()
            }
        })
    }

    func cleanup() {
        for token in observers {
            NotificationCenter.default.removeObserver(token)
        }
        observers.removeAll()
    }

    // MARK: - View Lifecycle

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        guard subview !== overlay, overlay.superview === self else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.overlay.superview === self else { return }
            if self.subviews.last !== self.overlay {
                self.addSubview(self.overlay, positioned: .above, relativeTo: nil)
            }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachScrollObserverIfNeeded()
    }

    override func layout() {
        super.layout()
        overlay.frame = bounds
        attachScrollObserverIfNeeded()
        overlay.needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        overlay.needsDisplay = true
    }

    private func attachScrollObserverIfNeeded() {
        guard let clip = documentView?.enclosingScrollView?.contentView, clip !== observedClipView else { return }
        observedClipView = clip
        clip.postsBoundsChangedNotifications = true
        observers.append(NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: clip, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.overlay.needsDisplay = true
            }
        })
    }

    private func syncCurrentPage() {
        overlay.needsDisplay = true
        guard let service, let doc = document, let page = currentPage else { return }
        let index = doc.index(for: page)
        if index != NSNotFound, index != service.currentPageIndex {
            service.currentPageIndex = index
        }
    }

    // MARK: - Service Callbacks

    func refresh(page: PDFPage?) {
        if let page, page.document === document { annotationsChanged(on: page) }
        overlay.needsDisplay = true
    }

    func refreshVisiblePages() {
        for page in visiblePages { annotationsChanged(on: page) }
        overlay.needsDisplay = true
    }

    func selectionChanged() {
        overlay.needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    func toolChanged() {
        interaction = .idle
        overlay.needsDisplay = true
    }

    func clearTextSelection() {
        if currentSelection != nil { clearSelection() }
    }

    func goToPageIfNeeded(_ page: PDFPage, force: Bool = false) {
        guard page.document === document else { return }
        if force || currentPage !== page { go(to: page) }
    }

    func visibleCenter(on page: PDFPage) -> CGPoint? {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard self.page(for: center, nearest: false) === page else { return nil }
        let point = convert(center, to: page)
        return page.bounds(for: displayBox).contains(point) ? point : nil
    }

    // MARK: - Zoom

    func setZoomScale(_ scale: CGFloat) {
        autoScales = false
        scaleFactor = max(minScaleFactor, min(maxScaleFactor, scale))
    }

    func zoomStep(inward: Bool) {
        let current = scaleFactor
        let next: CGFloat
        if inward {
            next = Self.zoomSteps.first { $0 > current + 0.001 } ?? maxScaleFactor
        } else {
            next = Self.zoomSteps.last { $0 < current - 0.001 } ?? minScaleFactor
        }
        setZoomScale(next)
    }

    func fit(_ mode: PDFEditorGeometry.FitMode) {
        guard let page = currentPage ?? document?.page(at: 0) else { return }
        let viewport = documentView?.enclosingScrollView?.contentSize ?? bounds.size
        let scale = PDFEditorGeometry.fitScale(
            pageSize: page.bounds(for: displayBox).size,
            rotation: page.rotation,
            viewport: viewport,
            mode: mode,
            padding: 14
        )
        setZoomScale(scale)
        go(to: page)
    }

    // MARK: - Coordinate Helpers

    func pageLocation(for event: NSEvent) -> (PDFPage, CGPoint, CGPoint)? {
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: true) else { return nil }
        return (page, convert(viewPoint, to: page), viewPoint)
    }

    /// Handle positions in page space. Index meaning: resize corners 0...3, or 0 = start / 1 = end for lines.
    func handles(for annotation: PDFAnnotation) -> [CGPoint] {
        guard let kind = PDFEditorService.kind(of: annotation) else { return [] }
        if kind.hasEndpoints {
            let (start, end) = PDFEditorService.lineEndpoints(of: annotation)
            return [start, end]
        }
        guard kind.isResizable else { return [] }
        return outline(for: annotation)
    }

    func outline(for annotation: PDFAnnotation) -> [CGPoint] {
        if let image = annotation as? PDFStudioImageAnnotation { return image.rotatedCorners }
        let rect = annotation.bounds
        return [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)
        ]
    }

    func handleIndex(at viewPoint: CGPoint, for annotation: PDFAnnotation) -> Int? {
        guard let page = annotation.page else { return nil }
        for (index, point) in handles(for: annotation).enumerated() {
            let handleView = convert(point, from: page)
            if hypot(handleView.x - viewPoint.x, handleView.y - viewPoint.y) <= Self.handleRadius + 3 {
                return index
            }
        }
        return nil
    }

    private static func snapped(_ point: CGPoint, from origin: CGPoint) -> CGPoint {
        let dx = point.x - origin.x, dy = point.y - origin.y
        let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
        let length = hypot(dx, dy)
        return CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length)
    }

    private static func squared(_ point: CGPoint, from origin: CGPoint) -> CGPoint {
        let dx = point.x - origin.x, dy = point.y - origin.y
        let side = max(abs(dx), abs(dy))
        return CGPoint(x: origin.x + (dx < 0 ? -side : side), y: origin.y + (dy < 0 ? -side : side))
    }

    // MARK: - Mouse Handling

    override func mouseDown(with event: NSEvent) {
        guard let service, document != nil, let (page, pagePoint, viewPoint) = pageLocation(for: event) else {
            super.mouseDown(with: event)
            return
        }
        window?.makeFirstResponder(self)
        let tool = service.selectedAnnotationTool

        switch tool {
        case .select, .signatureStamp:
            if let selected = service.selectedAnnotation, let selectedPage = selected.page,
               let handle = handleIndex(at: viewPoint, for: selected) {
                let before = PDFEditorService.captureState(selected)
                if PDFEditorService.kind(of: selected)?.hasEndpoints == true {
                    interaction = .lineEndpoint(selected, selectedPage, isStart: handle == 0, before: before)
                } else {
                    interaction = .resizing(selected, selectedPage, corner: handle, before: before)
                }
                return
            }
            let candidates = service.hitTest(page: page, point: pagePoint, tolerance: 3 / max(scaleFactor, 0.1))
            if var target = candidates.first {
                if event.modifierFlags.contains(.option), let current = service.selectedAnnotation,
                   let index = candidates.firstIndex(where: { $0 === current }) {
                    target = candidates[(index + 1) % candidates.count]
                }
                service.select(target)
                let kind = PDFEditorService.kind(of: target)
                if event.clickCount >= 2, kind == .freeText || kind == .note {
                    service.requestTextEditing()
                }
                if kind?.isMovable == true {
                    interaction = .moving(target, page, start: pagePoint, before: PDFEditorService.captureState(target))
                }
                return
            }
            service.select(nil)
            super.mouseDown(with: event)

        case .highlight, .underline, .strikeout:
            service.select(nil)
            interaction = .markup(tool, page, start: pagePoint, current: pagePoint)
            super.mouseDown(with: event)
            // PDFKit may track the text-selection drag itself and consume the mouse-up.
            if let current = NSApp.currentEvent, current.type == .leftMouseUp, case .markup = interaction {
                finishMarkup(endEvent: current)
            }

        case .text, .rectangle, .circle, .line, .arrow, .cover:
            interaction = .creating(tool, page, start: pagePoint, current: pagePoint)

        case .pen:
            interaction = .inking(page, [pagePoint])

        case .stickyNote:
            let note = service.makeNote(at: pagePoint)
            service.add(note, to: page, actionName: "Add Sticky Note")
            service.selectedAnnotationTool = .select
            service.requestTextEditing()
        }
        overlay.needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let service else {
            super.mouseDragged(with: event)
            return
        }
        let viewPoint = convert(event.locationInWindow, from: nil)

        switch interaction {
        case .idle:
            super.mouseDragged(with: event)
            return

        case .moving(let annotation, let page, let start, let before):
            let point = convert(viewPoint, to: page)
            let dx = point.x - start.x, dy = point.y - start.y
            let pageBox = page.bounds(for: displayBox)
            if let image = annotation as? PDFStudioImageAnnotation, let size = before.imageSize {
                let moved = PDFEditorGeometry.keepVisible(before.bounds.offsetBy(dx: dx, dy: dy), in: pageBox)
                service.liveSetImageGeometry(image, center: PDFEditorGeometry.center(of: moved), size: size, rotation: before.imageRotation)
            } else {
                service.liveSetBounds(annotation, PDFEditorGeometry.keepVisible(before.bounds.offsetBy(dx: dx, dy: dy), in: pageBox))
            }

        case .resizing(let annotation, let page, let corner, let before):
            let point = convert(viewPoint, to: page)
            let shift = event.modifierFlags.contains(.shift)
            if let image = annotation as? PDFStudioImageAnnotation, let size = before.imageSize {
                let lock = service.lockImageAspectRatio != shift
                let result = PDFEditorGeometry.resize(
                    center: PDFEditorGeometry.center(of: before.bounds), size: size, degrees: before.imageRotation,
                    corner: corner, to: point, lockAspect: lock
                )
                service.liveSetImageGeometry(image, center: result.center, size: result.size, rotation: before.imageRotation)
            } else {
                let result = PDFEditorGeometry.resize(
                    center: PDFEditorGeometry.center(of: before.bounds), size: before.bounds.size, degrees: 0,
                    corner: corner, to: point, lockAspect: shift, minimumSize: 6
                )
                let rect = CGRect(x: result.center.x - result.size.width / 2, y: result.center.y - result.size.height / 2,
                                  width: result.size.width, height: result.size.height)
                service.liveSetBounds(annotation, rect)
            }

        case .lineEndpoint(let annotation, let page, let isStart, _):
            var point = convert(viewPoint, to: page)
            let (start, end) = PDFEditorService.lineEndpoints(of: annotation)
            if event.modifierFlags.contains(.shift) { point = Self.snapped(point, from: isStart ? end : start) }
            service.liveSetLine(annotation, start: isStart ? point : start, end: isStart ? end : point)

        case .creating(let tool, let page, let start, _):
            var point = convert(viewPoint, to: page)
            if event.modifierFlags.contains(.shift) {
                point = (tool == .line || tool == .arrow) ? Self.snapped(point, from: start) : Self.squared(point, from: start)
            }
            interaction = .creating(tool, page, start: start, current: point)

        case .inking(let page, var points):
            let point = convert(viewPoint, to: page)
            if let last = points.last, hypot(point.x - last.x, point.y - last.y) * scaleFactor >= 1 {
                points.append(point)
                interaction = .inking(page, points)
            }

        case .markup(let tool, let page, let start, _):
            interaction = .markup(tool, page, start: start, current: convert(viewPoint, to: page))
            super.mouseDragged(with: event)
        }
        autoscroll(with: event)
        overlay.needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let service else {
            super.mouseUp(with: event)
            return
        }
        let current = interaction
        interaction = .idle

        switch current {
        case .idle:
            super.mouseUp(with: event)

        case .moving(let annotation, _, _, let before):
            service.commitChange(annotation, from: before, actionName: "Move \(PDFEditorService.kind(of: annotation)?.rawValue ?? "Annotation")")

        case .resizing(let annotation, _, _, let before):
            service.commitChange(annotation, from: before, actionName: "Resize \(PDFEditorService.kind(of: annotation)?.rawValue ?? "Annotation")")

        case .lineEndpoint(let annotation, _, _, let before):
            service.commitChange(annotation, from: before, actionName: "Move Line Endpoint")

        case .creating(let tool, let page, let start, let end):
            finishCreation(tool: tool, page: page, start: start, end: end)

        case .inking(let page, let points):
            if let ink = service.makeInk(points: points) {
                service.add(ink, to: page, actionName: "Draw", select: false)
            }

        case .markup:
            interaction = current
            super.mouseUp(with: event)
            finishMarkup(endEvent: event)
        }
        overlay.needsDisplay = true
    }

    private func finishCreation(tool: PDFAnnotationToolType, page: PDFPage, start: CGPoint, end: CGPoint) {
        guard let service else { return }
        let rect = PDFEditorGeometry.rect(from: start, to: end)
        switch tool {
        case .text:
            let box = (rect.width < 8 || rect.height < 8) ? CGRect(x: start.x, y: start.y - 24, width: 160, height: 24) : rect
            let annotation = service.makeTextBox(in: box, text: "Text")
            service.add(annotation, to: page, actionName: "Add Text Box")
            service.selectedAnnotationTool = .select
            service.requestTextEditing()
        case .rectangle, .circle:
            guard rect.width >= 3, rect.height >= 3 else { return }
            service.add(service.makeShape(tool, in: rect), to: page, actionName: "Add \(tool.rawValue)")
        case .cover:
            guard rect.width >= 3, rect.height >= 3 else { return }
            service.add(service.makeCover(in: rect), to: page, actionName: "Cover Region")
        case .line, .arrow:
            guard hypot(end.x - start.x, end.y - start.y) >= 3 else { return }
            service.add(service.makeLine(from: start, to: end, arrow: tool == .arrow), to: page, actionName: "Add \(tool.rawValue)")
        default:
            break
        }
    }

    private func finishMarkup(endEvent: NSEvent) {
        guard let service, case .markup(let tool, let page, let start, _) = interaction else { return }
        interaction = .idle
        if let selection = currentSelection,
           !(selection.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            service.applyMarkup(tool, to: selection)
        } else {
            let end = convert(convert(endEvent.locationInWindow, from: nil), to: page)
            let rect = PDFEditorGeometry.rect(from: start, to: end)
            if rect.width >= 3, rect.height >= 3 {
                service.add(service.makeMarkup(tool, in: rect), to: page, actionName: "Add \(tool.rawValue)", select: false)
            }
        }
        clearTextSelection()
        overlay.needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard let service, document != nil else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)
        switch service.selectedAnnotationTool {
        case .select, .signatureStamp:
            if let selected = service.selectedAnnotation, handleIndex(at: viewPoint, for: selected) != nil {
                NSCursor.crosshair.set()
            } else if let (page, point, _) = pageLocation(for: event),
                      let hit = service.hitTest(page: page, point: point, tolerance: 3 / max(scaleFactor, 0.1)).first,
                      PDFEditorService.kind(of: hit)?.isMovable == true {
                NSCursor.openHand.set()
            }
        case .highlight, .underline, .strikeout:
            break
        default:
            NSCursor.crosshair.set()
        }
    }

    // MARK: - Keyboard & Edit Menu

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let service else {
            super.keyDown(with: event)
            return
        }
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        switch event.keyCode {
        case 51, 117:
            if service.selectedAnnotation != nil {
                service.deleteSelection()
                return
            }
        case 53:
            interaction = .idle
            service.select(nil)
            service.selectedAnnotationTool = .select
            overlay.needsDisplay = true
            return
        case 123, 124, 125, 126:
            if service.selectedAnnotation != nil {
                let dx: CGFloat = event.keyCode == 123 ? -step : (event.keyCode == 124 ? step : 0)
                let dy: CGFloat = event.keyCode == 125 ? -step : (event.keyCode == 126 ? step : 0)
                service.nudgeSelection(dx: dx, dy: dy)
                return
            }
        default:
            break
        }
        super.keyDown(with: event)
    }

    override func copy(_ sender: Any?) {
        if let service, service.selectedAnnotation != nil {
            service.copySelection()
        } else {
            super.copy(sender)
        }
    }

    @objc func cut(_ sender: Any?) { service?.cutSelection() }
    @objc func paste(_ sender: Any?) { service?.paste() }
    @objc func delete(_ sender: Any?) { service?.deleteSelection() }
    @objc func duplicate(_ sender: Any?) { service?.duplicateSelection() }
    @objc func undo(_ sender: Any?) { service?.undo() }
    @objc func redo(_ sender: Any?) { service?.redo() }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let service else { return false }
        switch menuItem.action {
        case #selector(cut(_:)), #selector(delete(_:)), #selector(duplicate(_:)):
            return service.selectedAnnotation != nil
        case #selector(paste(_:)):
            return service.canPaste
        case #selector(copy(_:)):
            return service.selectedAnnotation != nil || currentSelection != nil
        case #selector(undo(_:)):
            menuItem.title = service.undoActionName.isEmpty ? "Undo" : "Undo \(service.undoActionName)"
            return service.canUndo
        case #selector(redo(_:)):
            menuItem.title = service.redoActionName.isEmpty ? "Redo" : "Redo \(service.redoActionName)"
            return service.canRedo
        default:
            return true
        }
    }

    // MARK: - Overlay Drawing

    fileprivate func drawOverlay(in view: NSView) {
        guard let service, document != nil else { return }
        let accent = NSColor.controlAccentColor
        let visible = Set(visiblePages.map { ObjectIdentifier($0) })

        func viewPoint(_ point: CGPoint, _ page: PDFPage) -> CGPoint {
            view.convert(convert(point, from: page), from: self)
        }

        func polygon(_ points: [CGPoint]) -> NSBezierPath {
            let path = NSBezierPath()
            guard let first = points.first else { return path }
            path.move(to: first)
            for point in points.dropFirst() { path.line(to: point) }
            path.close()
            return path
        }

        if let selected = service.selectedAnnotation, let page = selected.page, visible.contains(ObjectIdentifier(page)),
           let kind = PDFEditorService.kind(of: selected) {
            if kind.hasEndpoints {
                let (start, end) = PDFEditorService.lineEndpoints(of: selected)
                let a = viewPoint(start, page), b = viewPoint(end, page)
                let path = NSBezierPath()
                path.move(to: a)
                path.line(to: b)
                path.lineWidth = 1
                accent.withAlphaComponent(0.6).setStroke()
                path.setLineDash([4, 3], count: 2, phase: 0)
                path.stroke()
                for point in [a, b] { drawHandle(at: point, accent: accent, round: true) }
            } else {
                let corners = outline(for: selected).map { viewPoint($0, page) }
                let outlinePath = polygon(corners)
                outlinePath.lineWidth = 3
                NSColor.white.withAlphaComponent(0.85).setStroke()
                outlinePath.stroke()
                outlinePath.lineWidth = 1.5
                accent.setStroke()
                outlinePath.setLineDash([5, 3], count: 2, phase: 0)
                outlinePath.stroke()
                if kind.isResizable {
                    for point in corners { drawHandle(at: point, accent: accent, round: false) }
                }
            }
        }

        switch interaction {
        case .creating(let tool, let page, let start, let current):
            let rectCorners = [
                CGPoint(x: start.x, y: start.y), CGPoint(x: current.x, y: start.y),
                CGPoint(x: current.x, y: current.y), CGPoint(x: start.x, y: current.y)
            ].map { viewPoint($0, page) }
            let color = service.toolNSColor(tool)
            switch tool {
            case .line, .arrow:
                let a = viewPoint(start, page), b = viewPoint(current, page)
                let path = NSBezierPath()
                path.move(to: a)
                path.line(to: b)
                path.lineWidth = max(1, CGFloat(service.strokeWidth) * scaleFactor)
                path.lineCapStyle = .round
                color.setStroke()
                path.stroke()
                if tool == .arrow { drawArrowHead(from: a, to: b, color: color, width: path.lineWidth) }
            case .circle:
                let path = NSBezierPath(ovalIn: PDFEditorGeometry.boundingRect(of: rectCorners))
                path.lineWidth = max(1, CGFloat(service.strokeWidth) * scaleFactor)
                color.setStroke()
                path.stroke()
            case .cover:
                let path = polygon(rectCorners)
                color.withAlphaComponent(0.9).setFill()
                path.fill()
                NSColor.gray.setStroke()
                path.lineWidth = 1
                path.setLineDash([4, 3], count: 2, phase: 0)
                path.stroke()
            case .text:
                let path = polygon(rectCorners)
                path.lineWidth = 1
                accent.setStroke()
                path.setLineDash([4, 3], count: 2, phase: 0)
                path.stroke()
            default:
                let path = polygon(rectCorners)
                path.lineWidth = max(1, CGFloat(service.strokeWidth) * scaleFactor)
                color.setStroke()
                path.stroke()
            }

        case .inking(let page, let points):
            guard points.count > 1 else { break }
            let path = NSBezierPath()
            path.move(to: viewPoint(points[0], page))
            for point in points.dropFirst() { path.line(to: viewPoint(point, page)) }
            path.lineWidth = max(1, CGFloat(service.strokeWidth) * scaleFactor)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            service.toolNSColor(.pen).setStroke()
            path.stroke()

        case .markup(let tool, let page, let start, let current):
            if currentSelection == nil || (currentSelection?.string ?? "").isEmpty {
                let corners = [
                    CGPoint(x: start.x, y: start.y), CGPoint(x: current.x, y: start.y),
                    CGPoint(x: current.x, y: current.y), CGPoint(x: start.x, y: current.y)
                ].map { viewPoint($0, page) }
                let path = polygon(corners)
                service.toolNSColor(tool).withAlphaComponent(0.25).setFill()
                path.fill()
            }

        default:
            break
        }
    }

    private func drawHandle(at point: CGPoint, accent: NSColor, round: Bool) {
        let size = Self.handleRadius * 2 - 2
        let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        let path = round ? NSBezierPath(ovalIn: rect) : NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        NSColor.white.setFill()
        path.fill()
        path.lineWidth = 1.5
        accent.setStroke()
        path.stroke()
    }

    private func drawArrowHead(from a: CGPoint, to b: CGPoint, color: NSColor, width: CGFloat) {
        let angle = atan2(b.y - a.y, b.x - a.x)
        let length = max(10, width * 4)
        let path = NSBezierPath()
        path.move(to: b)
        path.line(to: CGPoint(x: b.x - length * cos(angle - .pi / 7), y: b.y - length * sin(angle - .pi / 7)))
        path.line(to: CGPoint(x: b.x - length * cos(angle + .pi / 7), y: b.y - length * sin(angle + .pi / 7)))
        path.close()
        color.setFill()
        path.fill()
    }
}

/// Transparent, click-through layer that draws selection borders, handles and live previews.
@MainActor
final class PDFEditorOverlayView: NSView {
    weak var canvas: PDFEditorCanvasView?

    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        canvas?.drawOverlay(in: self)
    }
}

/// Canvas plus PDFKit's native thumbnail strip.
@MainActor
final class PDFEditorHostView: NSView {
    let canvas = PDFEditorCanvasView(frame: .zero)
    let thumbnails = PDFThumbnailView(frame: .zero)
    private let separator = NSBox()

    var showsThumbnails = true {
        didSet {
            guard showsThumbnails != oldValue else { return }
            thumbnails.isHidden = !showsThumbnails
            separator.isHidden = !showsThumbnails
            needsLayout = true
        }
    }

    static let thumbnailWidth: CGFloat = 132

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        thumbnails.pdfView = canvas
        thumbnails.thumbnailSize = CGSize(width: 92, height: 120)
        thumbnails.allowsDragging = false
        thumbnails.allowsMultipleSelection = false
        thumbnails.backgroundColor = .underPageBackgroundColor
        thumbnails.setAccessibilityLabel("Page thumbnails")
        separator.boxType = .separator
        addSubview(thumbnails)
        addSubview(separator)
        addSubview(canvas)
        canvas.setAccessibilityLabel("PDF page canvas")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        let thumbWidth = showsThumbnails ? min(Self.thumbnailWidth, bounds.width * 0.35) : 0
        thumbnails.frame = CGRect(x: 0, y: 0, width: thumbWidth, height: bounds.height)
        separator.frame = CGRect(x: thumbWidth, y: 0, width: showsThumbnails ? 1 : 0, height: bounds.height)
        let canvasX = thumbWidth + (showsThumbnails ? 1 : 0)
        canvas.frame = CGRect(x: canvasX, y: 0, width: max(0, bounds.width - canvasX), height: bounds.height)
    }
}

struct PDFEditorCanvasRepresentable: NSViewRepresentable {
    @ObservedObject var service: PDFEditorService
    var showsThumbnails: Bool

    func makeNSView(context: Context) -> PDFEditorHostView {
        let host = PDFEditorHostView(frame: .zero)
        host.canvas.service = service
        service.canvas = host.canvas
        host.canvas.document = service.document
        host.showsThumbnails = showsThumbnails
        return host
    }

    func updateNSView(_ host: PDFEditorHostView, context: Context) {
        if service.canvas !== host.canvas { service.canvas = host.canvas }
        if host.canvas.document !== service.document {
            host.canvas.document = service.document
            host.canvas.autoScales = true
        }
        host.showsThumbnails = showsThumbnails
        host.canvas.overlay.needsDisplay = true
    }

    static func dismantleNSView(_ host: PDFEditorHostView, coordinator: ()) {
        if host.canvas.service?.canvas === host.canvas {
            host.canvas.service?.canvas = nil
        }
        host.canvas.cleanup()
    }
}
