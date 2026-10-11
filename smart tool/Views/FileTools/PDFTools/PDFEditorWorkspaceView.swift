//
//  PDFEditorWorkspaceView.swift
//  Borno Pulse
//
//  Advanced PDF Editor: toolbar, interactive canvas with thumbnails, inspector and status bar.
//

import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct PDFEditorWorkspaceView: View {
    @ObservedObject var service = PDFEditorService.shared

    @State private var showThumbnails = true
    @State private var showInspector = true
    @State private var showSignatureSheet = false
    @State private var showFormsSheet = false
    @State private var showReplaceSheet = false
    @State private var replaceSelection: PDFSelection?
    @State private var replacementText = ""
    @State private var passwordText = ""
    @State private var passwordFailed = false
    @State private var pageField = "1"
    @State private var isDropTargeted = false
    @State private var isCompact = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if let notice = service.documentNotice, service.document != nil {
                noticeBanner(notice)
                Divider()
            }
            if service.document != nil {
                HStack(spacing: 0) {
                    PDFEditorCanvasRepresentable(service: service, showsThumbnails: showThumbnails && !isCompact)
                        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                    if showInspector {
                        Divider()
                        PDFEditorInspectorView(service: service)
                            .frame(width: isCompact ? 236 : 264)
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { isCompact = proxy.size.width < 760 }
                            .onChange(of: proxy.size.width) { _, width in isCompact = width < 760 }
                    }
                )
            } else {
                emptyState
            }
            Divider()
            statusBar
        }
        .sheet(isPresented: $showSignatureSheet) {
            SignatureDrawingView(isPresented: $showSignatureSheet) { image in
                service.addSignature(image: image)
            }
        }
        .sheet(isPresented: $showFormsSheet) {
            PDFEditorFormsSheet(service: service, isPresented: $showFormsSheet)
        }
        .sheet(isPresented: $showReplaceSheet) { replaceTextSheet }
        .sheet(isPresented: Binding(
            get: { service.pendingPasswordURL != nil },
            set: { if !$0 { service.pendingPasswordURL = nil } }
        )) { passwordSheet }
        .alert(
            service.lastError?.title ?? "Error",
            isPresented: Binding(get: { service.lastError != nil }, set: { if !$0 { service.lastError = nil } }),
            presenting: service.lastError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
        .onChange(of: service.currentPageIndex) { _, newValue in pageField = "\(newValue + 1)" }
        .onAppear { pageField = "\(service.currentPageIndex + 1)" }
    }

    private var hasDocument: Bool { service.document != nil }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button { service.runOpenPanel() } label: { Label("Open", systemImage: "folder") }
                        .help("Open a PDF (asks to save unsaved changes first)")
                    Button { service.saveInteractively() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(!hasDocument)
                        .help(service.sourceURL == nil ? "Save (choose a location)" : "Save changes to \(service.documentTitle) safely (written to a temporary file, verified, then replaced)")
                    Button { service.runSaveAsPanel() } label: { Text("Save As…") }
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                        .disabled(!hasDocument)
                        .help("Save to a new file and continue editing it")
                    Menu {
                        Button("Export Copy…") { service.runExportPanel(flatten: false) }
                        Button("Export Flattened Copy…") { service.runExportPanel(flatten: true) }
                        Divider()
                        Button("Print…") { service.printDocument() }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(!hasDocument)
                    .help("Export an editable copy, a flattened copy (annotations burned in), or print")

                    toolbarDivider

                    Button { service.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!service.canUndo)
                        .help(service.undoActionName.isEmpty ? "Undo" : "Undo \(service.undoActionName)")
                    Button { service.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                        .disabled(!service.canRedo)
                        .help(service.redoActionName.isEmpty ? "Redo" : "Redo \(service.redoActionName)")

                    toolbarDivider

                    Button { service.zoomOut() } label: { Image(systemName: "minus.magnifyingglass") }
                        .keyboardShortcut("-", modifiers: .command)
                        .disabled(!hasDocument)
                        .help("Zoom Out")
                    Menu {
                        ForEach([50, 75, 100, 125, 150, 200, 300, 400], id: \.self) { percent in
                            Button("\(percent)%") { service.setZoomPercent(percent) }
                        }
                        Divider()
                        Button("Fit Page") { service.zoomToFitPage() }
                        Button("Fit Width") { service.zoomToFitWidth() }
                    } label: {
                        Text("\(service.zoomPercent)%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .frame(minWidth: 40)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(!hasDocument)
                    .help("Zoom level")
                    Button { service.zoomIn() } label: { Image(systemName: "plus.magnifyingglass") }
                        .keyboardShortcut("=", modifiers: .command)
                        .disabled(!hasDocument)
                        .help("Zoom In")
                    Button { service.zoomToFitPage() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                        .disabled(!hasDocument)
                        .help("Fit Page")
                    Button { service.zoomToFitWidth() } label: { Image(systemName: "arrow.left.and.right") }
                        .disabled(!hasDocument)
                        .help("Fit Width")

                    toolbarDivider

                    Button { service.goToPage(service.currentPageIndex - 1) } label: { Image(systemName: "chevron.up") }
                        .disabled(!hasDocument || service.currentPageIndex == 0)
                        .help("Previous Page")
                    TextField("", text: $pageField)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 42)
                        .multilineTextAlignment(.center)
                        .onSubmit {
                            if let number = Int(pageField.trimmingCharacters(in: .whitespaces)) {
                                service.goToPage(number - 1)
                            }
                            pageField = "\(service.currentPageIndex + 1)"
                        }
                        .disabled(!hasDocument)
                        .help("Go to page")
                    Text("of \(service.pageCount)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Button { service.goToPage(service.currentPageIndex + 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(!hasDocument || service.currentPageIndex >= service.pageCount - 1)
                        .help("Next Page")

                    toolbarDivider

                    Toggle(isOn: $showThumbnails) { Image(systemName: "sidebar.left") }
                        .toggleStyle(.button)
                        .disabled(isCompact)
                        .help(isCompact ? "Thumbnails are hidden while the window is narrow" : "Show or hide page thumbnails")
                    Toggle(isOn: $showInspector) { Image(systemName: "sidebar.right") }
                        .toggleStyle(.button)
                        .help("Show or hide the inspector")
                }
                .controlSize(.small)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider().opacity(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(PDFAnnotationToolType.canvasTools) { tool in
                        toolButton(tool)
                    }

                    toolbarDivider

                    Button { service.runInsertImagePanel() } label: { Label("Image", systemImage: "photo.badge.plus") }
                        .disabled(!hasDocument)
                        .help("Insert an image from disk as a movable, resizable, rotatable object")
                    Button { showSignatureSheet = true } label: { Label("Sign", systemImage: "signature") }
                        .disabled(!hasDocument)
                        .help("Draw or import a signature and place it on the page")
                    Button { beginReplaceText() } label: { Label("Replace Text", systemImage: "character.cursor.ibeam") }
                        .disabled(!hasDocument)
                        .help("Replacement-text workflow: covers the selected PDF text and places editable text on top. The original text remains in the file underneath.")

                    toolbarDivider

                    Button { service.insertBlankPage() } label: { Image(systemName: "doc.badge.plus") }
                        .disabled(!hasDocument)
                        .help("Insert a blank page after the current page")
                    Button { service.duplicateCurrentPage() } label: { Image(systemName: "plus.square.on.square") }
                        .disabled(!hasDocument)
                        .help("Duplicate the current page")
                    Button { service.rotateCurrentPage(delta: -90) } label: { Image(systemName: "rotate.left") }
                        .disabled(!hasDocument)
                        .help("Rotate the current page left")
                    Button { service.rotateCurrentPage(delta: 90) } label: { Image(systemName: "rotate.right") }
                        .disabled(!hasDocument)
                        .help("Rotate the current page right")
                    Button(role: .destructive) { service.deleteCurrentPage() } label: {
                        Image(systemName: "trash").foregroundStyle(hasDocument && service.pageCount > 1 ? AppTheme.dangerRed : AppTheme.disabledText)
                    }
                    .disabled(!hasDocument || service.pageCount <= 1)
                    .help(service.pageCount <= 1 ? "A document must keep at least one page" : "Delete the current page")

                    toolbarDivider

                    Button { showFormsSheet = true } label: {
                        Label("Forms (\(service.formFields.count))", systemImage: "list.bullet.rectangle")
                    }
                    .disabled(!hasDocument)
                    .help(service.formFields.isEmpty ? "This document has no fillable form fields" : "Review and fill the document's form fields")
                }
                .controlSize(.small)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .background(AppTheme.cardBackgroundSecondary)
    }

    private var toolbarDivider: some View {
        Divider().frame(height: 18).padding(.horizontal, 2)
    }

    private func toolButton(_ tool: PDFAnnotationToolType) -> some View {
        let isActive = service.selectedAnnotationTool == tool
        return Button {
            service.selectedAnnotationTool = tool
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 24)
                .foregroundStyle(isActive ? AppTheme.textOnAccent : AppTheme.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? AppTheme.accentFill : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasDocument)
        .help("\(tool.rawValue): \(tool.usageHint)")
        .accessibilityLabel(tool.rawValue)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Banners, Empty State, Status

    private func noticeBanner(_ notice: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warningAmber)
            Text(notice)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(AppTheme.warningAmber.opacity(0.12))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.viewfinder.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.electricBlue)
            Text("No PDF Document Open")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Open or drop a PDF to annotate it, add text, shapes, freehand drawings, notes, images and signatures, fill forms, and rearrange pages. Your original file is only changed when you choose Save.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: 440)
                .multilineTextAlignment(.center)
            Button("Open PDF…") { service.runOpenPanel() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isDropTargeted ? AppTheme.electricBlue : Color.clear, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .padding(12)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
                        service.openDocument(at: url)
                    } else {
                        service.lastError = PDFEditorAlert(title: "Unsupported File", message: "“\(url.lastPathComponent)” is not a PDF. The editor opens PDF documents; use Images to PDF or Word & Office to PDF to convert other files first.")
                    }
                }
            }
            return true
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if service.hasUnsavedChanges {
                Circle().fill(AppTheme.warningAmber).frame(width: 7, height: 7)
                    .help("Unsaved changes")
            }
            Text(service.document == nil ? "No document" : service.documentTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            Text(service.statusMessage)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            Spacer()
            if hasDocument {
                Text("Page \(service.currentPageIndex + 1) of \(service.pageCount)")
                Text("\(service.zoomPercent)%")
                Button("Close") { service.requestClose() }
                    .controlSize(.small)
                    .help("Close the document (asks to save unsaved changes)")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(AppTheme.cardBackground)
    }

    // MARK: - Replace Text

    private func beginReplaceText() {
        guard let selection = service.canvas?.currentSelection,
              !(selection.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            service.lastError = PDFEditorAlert(
                title: "Select Text First",
                message: "With the Select tool, drag across the PDF text you want to replace, then choose Replace Text."
            )
            return
        }
        replaceSelection = selection
        replacementText = selection.string ?? ""
        showReplaceSheet = true
    }

    private var replaceTextSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Replace Text")
                .font(.system(size: 14, weight: .bold))
            Text("PDFs do not store editable paragraphs, so Borno Pulse does not rewrite the original text. Instead it covers the selected lines with an opaque box and places an editable text box on top. The original text still exists underneath (it can be found by search or copy) — this is not secure redaction.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Original").font(.system(size: 11, weight: .semibold)).foregroundStyle(AppTheme.textSecondary)
            Text(replaceSelection?.string ?? "")
                .font(.system(size: 12))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.insetBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("Replacement").font(.system(size: 11, weight: .semibold)).foregroundStyle(AppTheme.textSecondary)
            TextEditor(text: $replacementText)
                .font(.system(size: 12))
                .frame(height: 80)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.inputBorder))
            HStack {
                Spacer()
                Button("Cancel") { showReplaceSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Replace") {
                    if let selection = replaceSelection {
                        service.replaceText(in: selection, with: replacementText)
                    }
                    showReplaceSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
                .keyboardShortcut(.defaultAction)
                .disabled(replacementText.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    // MARK: - Password

    private var passwordSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Password Required", systemImage: "lock.fill")
                .font(.system(size: 14, weight: .bold))
            Text("“\(service.pendingPasswordURL?.lastPathComponent ?? "")” is encrypted. Enter its password to open it.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
            SecureField("Password", text: $passwordText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submitPassword)
            if passwordFailed {
                Text("Incorrect password. Try again.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.dangerRed)
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    passwordText = ""
                    passwordFailed = false
                    service.pendingPasswordURL = nil
                }
                .keyboardShortcut(.cancelAction)
                Button("Open", action: submitPassword)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentFill)
                    .keyboardShortcut(.defaultAction)
                    .disabled(passwordText.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func submitPassword() {
        let succeeded = service.unlockPendingDocument(password: passwordText)
        passwordFailed = !succeeded
        if succeeded { passwordText = "" }
    }
}

// MARK: - Inspector

struct PDFEditorInspectorView: View {
    @ObservedObject var service: PDFEditorService
    @FocusState private var textFocused: Bool

    var body: some View {
        let _ = service.revision
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let annotation = service.selectedAnnotation, let kind = PDFEditorService.kind(of: annotation) {
                    selectionInspector(annotation, kind: kind)
                } else {
                    toolDefaults
                    pageSummary
                    commentsList
                    editingGuide
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.sidebarBackground)
        .onChange(of: service.textEditRequest) { _, _ in textFocused = true }
        .onChange(of: textFocused) { _, focused in
            if !focused { service.endTextEditSession() }
        }
    }

    // MARK: Selection

    @ViewBuilder
    private func selectionInspector(_ annotation: PDFAnnotation, kind: PDFEditableKind) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.rawValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let page = annotation.page, let index = service.document?.index(for: page) {
                    Text("Page \(index + 1)")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            Button { service.duplicateSelection() } label: { Image(systemName: "plus.square.on.square") }
                .help("Duplicate")
            Button(role: .destructive) { service.deleteSelection() } label: {
                Image(systemName: "trash").foregroundStyle(AppTheme.dangerRed)
            }
            .help("Delete (⌫)")
        }
        .controlSize(.small)

        if kind == .freeText || kind == .note {
            section(kind == .note ? "Comment" : "Text") {
                TextEditor(text: Binding(
                    get: { annotation.contents ?? "" },
                    set: { service.updateText($0, for: annotation) }
                ))
                .font(.system(size: 12))
                .focused($textFocused)
                .frame(height: 90)
                .scrollContentBackground(.hidden)
                .background(AppTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.inputBorder))
            }
        }

        if kind == .freeText {
            section("Font") {
                Picker("Font", selection: Binding(
                    get: { annotation.font?.fontName ?? "Helvetica" },
                    set: { service.setFont(name: $0, for: annotation) }
                )) {
                    ForEach(fontOptions(including: annotation.font?.fontName), id: \.postScript) { option in
                        Text(option.name).tag(option.postScript)
                    }
                }
                .labelsHidden()
                HStack {
                    Text("Size").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                    PDFInspectorNumberField(value: Double(annotation.font?.pointSize ?? 14), suffix: "pt") { value in
                        service.setFont(size: CGFloat(value), for: annotation)
                    }
                    Stepper("", value: Binding(
                        get: { Double(annotation.font?.pointSize ?? 14) },
                        set: { service.setFont(size: CGFloat($0), for: annotation) }
                    ), in: 4...288, step: 1)
                    .labelsHidden()
                }
                colorRow("Text Color", color: annotation.fontColor ?? .black) { color in
                    service.liveModify(annotation, actionName: "Change Text Color") { $0.fontColor = color }
                }
                fillRow(annotation, current: annotation.color.alphaComponent > 0.01 ? annotation.color : nil)
            }
        } else if kind == .cover {
            section("Cover") {
                colorRow("Fill", color: annotation.interiorColor ?? .white) { color in
                    service.liveModify(annotation, actionName: "Change Fill") {
                        $0.color = color
                        $0.interiorColor = color
                    }
                }
                Text("Hides content visually only. The covered text is still in the file.")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.warningAmber)
            }
        } else if !kind.isImage {
            section("Appearance") {
                colorRow(kind == .note ? "Note Color" : "Color", color: annotation.color.withAlphaComponent(1)) { color in
                    service.liveModify(annotation, actionName: "Change Color") { annotation in
                        let alpha = annotation.color.alphaComponent
                        annotation.color = kind == .highlight ? color.withAlphaComponent(alpha) : color
                        if kind == .arrow { annotation.interiorColor = color }
                    }
                }
                if kind == .highlight {
                    sliderRow("Opacity", value: Double(annotation.color.alphaComponent), range: 0.1...1) { value in
                        service.liveModify(annotation, actionName: "Change Opacity") { $0.color = $0.color.withAlphaComponent(CGFloat(value)) }
                    }
                }
                if kind.supportsStroke {
                    sliderRow("Line Width", value: Double(annotation.border?.lineWidth ?? 1), range: 0.5...20, format: "%.1f pt") { value in
                        let endpoints = kind.hasEndpoints ? PDFEditorService.lineEndpoints(of: annotation) : nil
                        service.liveModify(annotation, actionName: "Change Line Width") { annotation in
                            let border = PDFBorder()
                            border.lineWidth = CGFloat(value)
                            annotation.border = border
                            if let endpoints { PDFEditorService.setLineEndpoints(annotation, start: endpoints.0, end: endpoints.1) }
                        }
                    }
                }
                if kind == .rectangle || kind == .ellipse {
                    fillRow(annotation, current: annotation.interiorColor)
                }
                if kind.hasEndpoints {
                    Toggle("Arrow Head", isOn: Binding(
                        get: { annotation.endLineStyle != .none },
                        set: { service.setArrowHead($0, for: annotation) }
                    ))
                    .font(.system(size: 11))
                }
            }
        }

        if let image = annotation as? PDFStudioImageAnnotation {
            imageInspector(image)
        } else if kind.hasEndpoints {
            lineInspector(annotation)
        } else if kind.isMovable {
            frameInspector(annotation, resizable: kind.isResizable)
        }

        Text("Positions are PDF points measured from the page's bottom-left corner. Arrow keys nudge by 1 pt (Shift: 10 pt).")
            .font(.system(size: 10))
            .foregroundStyle(AppTheme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func imageInspector(_ image: PDFStudioImageAnnotation) -> some View {
        let center = image.center
        let size = image.contentSize
        let rotation = image.rotationDegrees
        let aspect = size.height > 0 ? size.width / size.height : 1
        return section("Image Transform") {
            HStack {
                labeledNumber("X", value: center.x) { service.setImageGeometry(image, center: CGPoint(x: $0, y: center.y), size: size, rotation: rotation, actionName: "Move Image") }
                labeledNumber("Y", value: center.y) { service.setImageGeometry(image, center: CGPoint(x: center.x, y: $0), size: size, rotation: rotation, actionName: "Move Image") }
            }
            HStack {
                labeledNumber("W", value: size.width) { width in
                    let height = service.lockImageAspectRatio ? width / aspect : size.height
                    service.setImageGeometry(image, center: center, size: CGSize(width: width, height: height), rotation: rotation, actionName: "Resize Image")
                }
                labeledNumber("H", value: size.height) { height in
                    let width = service.lockImageAspectRatio ? height * aspect : size.width
                    service.setImageGeometry(image, center: center, size: CGSize(width: width, height: height), rotation: rotation, actionName: "Resize Image")
                }
            }
            HStack {
                labeledNumber("Angle", value: rotation, suffix: "°") { service.setImageGeometry(image, center: center, size: size, rotation: $0, actionName: "Rotate Image") }
                Button { service.rotateSelectedImage(by: -90) } label: { Image(systemName: "rotate.left") }
                    .help("Rotate 90° left")
                Button { service.rotateSelectedImage(by: 90) } label: { Image(systemName: "rotate.right") }
                    .help("Rotate 90° right")
            }
            .controlSize(.small)
            Toggle("Lock aspect ratio (Shift-drag toggles)", isOn: $service.lockImageAspectRatio)
                .font(.system(size: 11))
            HStack {
                Button("Reset Aspect") { service.resetSelectedImageAspect() }
                Button("Replace Image…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.image]
                    if panel.runModal() == .OK, let url = panel.url { service.replaceImage(image, with: url) }
                }
            }
            .controlSize(.small)
            Text("Source: \(Int(image.pixelSize.width)) × \(Int(image.pixelSize.height)) px")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textTertiary)
        }
    }

    private func lineInspector(_ annotation: PDFAnnotation) -> some View {
        let (start, end) = PDFEditorService.lineEndpoints(of: annotation)
        return section("Endpoints") {
            HStack {
                labeledNumber("X1", value: start.x) { service.setLineEndpoints(annotation, start: CGPoint(x: $0, y: start.y), end: end) }
                labeledNumber("Y1", value: start.y) { service.setLineEndpoints(annotation, start: CGPoint(x: start.x, y: $0), end: end) }
            }
            HStack {
                labeledNumber("X2", value: end.x) { service.setLineEndpoints(annotation, start: start, end: CGPoint(x: $0, y: end.y)) }
                labeledNumber("Y2", value: end.y) { service.setLineEndpoints(annotation, start: start, end: CGPoint(x: end.x, y: $0)) }
            }
        }
    }

    private func frameInspector(_ annotation: PDFAnnotation, resizable: Bool) -> some View {
        let rect = annotation.bounds
        return section(resizable ? "Position & Size" : "Position") {
            HStack {
                labeledNumber("X", value: rect.minX) { service.setFrame(annotation, to: CGRect(x: $0, y: rect.minY, width: rect.width, height: rect.height)) }
                labeledNumber("Y", value: rect.minY) { service.setFrame(annotation, to: CGRect(x: rect.minX, y: $0, width: rect.width, height: rect.height)) }
            }
            if resizable {
                HStack {
                    labeledNumber("W", value: rect.width) { service.setFrame(annotation, to: CGRect(x: rect.minX, y: rect.minY, width: $0, height: rect.height)) }
                    labeledNumber("H", value: rect.height) { service.setFrame(annotation, to: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: $0)) }
                }
            }
        }
    }

    // MARK: No Selection

    private var toolDefaults: some View {
        let tool = service.selectedAnnotationTool
        return section("\(tool.rawValue) Tool") {
            Text(tool.usageHint)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if tool != .select && tool != .signatureStamp {
                HStack {
                    Text("Color").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    ColorPicker("", selection: $service.annotationColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }
            if tool == .highlight {
                sliderRow("Opacity", value: service.annotationOpacity, range: 0.1...1) { service.annotationOpacity = $0 }
            }
            if [.pen, .rectangle, .circle, .line, .arrow].contains(tool) {
                sliderRow("Line Width", value: service.strokeWidth, range: 0.5...20, format: "%.1f pt") { service.strokeWidth = $0 }
            }
            if tool == .rectangle || tool == .circle {
                Toggle("Fill shape", isOn: $service.shapeFillEnabled).font(.system(size: 11))
                if service.shapeFillEnabled {
                    ColorPicker("Fill Color", selection: $service.shapeFillColor).font(.system(size: 11))
                }
            }
            if tool == .text {
                Picker("Font", selection: $service.textFontName) {
                    ForEach(PDFEditorService.fontChoices, id: \.postScript) { Text($0.name).tag($0.postScript) }
                }
                .font(.system(size: 11))
                Stepper("Size: \(Int(service.textFontSize)) pt", value: $service.textFontSize, in: 6...144)
                    .font(.system(size: 11))
            }
        }
    }

    private var pageSummary: some View {
        let page = service.currentPage
        let box = page?.bounds(for: .cropBox) ?? .zero
        let editable = page?.annotations.filter { PDFEditorService.kind(of: $0) != nil }.count ?? 0
        return section("Page \(service.currentPageIndex + 1)") {
            infoRow("Size", "\(Int(box.width)) × \(Int(box.height)) pt")
            infoRow("Rotation", "\(page?.rotation ?? 0)°")
            infoRow("Editable objects", "\(editable)")
            infoRow("Has text layer", (page?.string?.isEmpty == false) ? "Yes" : "No (scanned/image page)")
        }
    }

    @ViewBuilder
    private var commentsList: some View {
        let items = commentItems()
        if !items.isEmpty {
            section("Comments & Text (\(items.count))") {
                ForEach(items, id: \.id) { item in
                    Button {
                        service.select(item.annotation)
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: item.annotation.type == "Text" ? "note.text" : "character.textbox")
                                .foregroundStyle(AppTheme.electricBlue)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.text.isEmpty ? "(empty)" : item.text)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(2)
                                Text("Page \(item.page + 1)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var editingGuide: some View {
        section("What Can Be Edited") {
            Text("• Objects you add (text boxes, shapes, drawings, notes, images, signatures) stay fully editable, including after saving and reopening.\n• Existing annotations from other apps can be selected, moved, recolored and deleted.\n• Original page text and images are part of the page content and cannot be rewritten in place. Use Replace Text, or Cover Region plus Insert Image to visually replace them.")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private struct CommentItem {
        let id: ObjectIdentifier
        let annotation: PDFAnnotation
        let text: String
        let page: Int
    }

    private func commentItems() -> [CommentItem] {
        guard let doc = service.document else { return [] }
        var items: [CommentItem] = []
        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index) else { continue }
            for annotation in page.annotations where annotation.type == "Text" || annotation.type == "FreeText" {
                items.append(CommentItem(id: ObjectIdentifier(annotation), annotation: annotation, text: annotation.contents ?? "", page: index))
                if items.count >= 50 { return items }
            }
        }
        return items
    }

    // MARK: Building Blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(AppTheme.textPrimary)
        }
        .font(.system(size: 11))
    }

    private func labeledNumber(_ label: String, value: CGFloat, suffix: String = "", onCommit: @escaping (CGFloat) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: label.count > 2 ? 34 : 16, alignment: .leading)
            PDFInspectorNumberField(value: Double(value), suffix: suffix) { onCommit(CGFloat($0)) }
        }
    }

    private func colorRow(_ label: String, color: NSColor, onChange: @escaping (NSColor) -> Void) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { Color(nsColor: color) },
                set: { onChange(PDFEditorService.nsColor($0)) }
            ), supportsOpacity: false)
            .labelsHidden()
        }
    }

    private func fillRow(_ annotation: PDFAnnotation, current: NSColor?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Fill", isOn: Binding(
                get: { current != nil },
                set: { service.setFill($0 ? NSColor(srgbRed: 1, green: 0.95, blue: 0.75, alpha: 1) : nil, for: annotation) }
            ))
            .font(.system(size: 11))
            if let current {
                colorRow("Fill Color", color: current) { color in
                    service.liveModify(annotation, actionName: "Change Fill") { annotation in
                        if annotation.type == "FreeText" { annotation.color = color } else { annotation.interiorColor = color }
                    }
                }
            }
        }
    }

    private func sliderRow(_ label: String, value: Double, range: ClosedRange<Double>, format: String = "%.0f%%", onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(format.contains("%%") ? String(format: format, value * 100) : String(format: format, value))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Slider(value: Binding(get: { value }, set: { newValue in onChange(newValue) }), in: range)
                .controlSize(.small)
        }
    }

    private func fontOptions(including current: String?) -> [(name: String, postScript: String)] {
        var options = PDFEditorService.fontChoices
        if let current, !options.contains(where: { $0.postScript == current }) {
            options.insert((NSFont(name: current, size: 12)?.displayName ?? current, current), at: 0)
        }
        return options
    }
}

/// Numeric text field that commits on Return or when focus leaves, so each edit is one undo step.
struct PDFInspectorNumberField: View {
    let value: Double
    var suffix: String = ""
    let onCommit: (Double) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 2) {
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .focused($focused)
                .onSubmit(commit)
            if !suffix.isEmpty {
                Text(suffix).font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
            }
        }
        .onAppear { text = Self.format(value) }
        .onChange(of: value) { _, newValue in if !focused { text = Self.format(newValue) } }
        .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
    }

    private func commit() {
        let normalized = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let parsed = Double(normalized), parsed.isFinite else {
            text = Self.format(value)
            return
        }
        if abs(parsed - value) > 0.0001 { onCommit(parsed) }
    }

    static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Forms Sheet

struct PDFEditorFormsSheet: View {
    @ObservedObject var service: PDFEditorService
    @Binding var isPresented: Bool

    var body: some View {
        let _ = service.revision
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Form Fields")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
            Text("Values you enter here (or directly on the page with the Select tool) are saved into the PDF's form fields.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
            if service.formFields.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("This document has no fillable (AcroForm) fields.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(service.formFields) { field in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(field.name).font(.system(size: 12, weight: .medium))
                            Text("\(field.kind.rawValue) · Page \(field.pageIndex + 1)")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(width: 170, alignment: .leading)
                        fieldEditor(field)
                        Button {
                            service.goToPage(field.pageIndex)
                        } label: { Image(systemName: "arrow.right.circle") }
                        .buttonStyle(.plain)
                        .help("Show on page")
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 420)
    }

    @ViewBuilder
    private func fieldEditor(_ field: PDFFormFieldInfo) -> some View {
        switch field.kind {
        case .text:
            PDFFormTextField(initial: service.formTextValue(field)) { service.setFormText($0, for: field) }
        case .checkbox, .radio:
            Toggle("", isOn: Binding(get: { service.formIsChecked(field) }, set: { service.setFormChecked($0, for: field) }))
                .labelsHidden()
            Spacer()
        case .choice:
            Picker("", selection: Binding(get: { service.formTextValue(field) }, set: { service.setFormText($0, for: field) })) {
                Text("—").tag("")
                ForEach(field.annotation.choices ?? [], id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
        case .signature, .pushButton:
            Text("Not editable here")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
        }
    }
}

private struct PDFFormTextField: View {
    let initial: String
    let onCommit: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Value", text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .onAppear { text = initial }
            .onSubmit { onCommit(text) }
            .onChange(of: focused) { _, isFocused in if !isFocused { onCommit(text) } }
    }
}
