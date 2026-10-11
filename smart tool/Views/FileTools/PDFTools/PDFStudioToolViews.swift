//
//  PDFStudioToolViews.swift
//  Borno Pulse
//
//  PDF Studio tool screens other than the Advanced Editor: assembly (Images to PDF, Merge,
//  Page Organizer, Rotate & Reorder), Office conversion, OCR, Split, Extract, Metadata and
//  Export & Print. Every operation reports success with the written files, or an actionable error.
//

import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared Outcome Banner

struct PDFStudioOutcome: Identifiable, Equatable {
    let id = UUID()
    let isSuccess: Bool
    let title: String
    let message: String
    var urls: [URL] = []

    static func success(_ title: String, _ message: String, urls: [URL] = []) -> PDFStudioOutcome {
        PDFStudioOutcome(isSuccess: true, title: title, message: message, urls: urls)
    }

    static func failure(_ title: String, _ error: Error) -> PDFStudioOutcome {
        PDFStudioOutcome(isSuccess: false, title: title, message: error.localizedDescription)
    }

    static func failure(_ title: String, _ message: String) -> PDFStudioOutcome {
        PDFStudioOutcome(isSuccess: false, title: title, message: message)
    }
}

struct PDFStudioOutcomeBanner: View {
    let outcome: PDFStudioOutcome
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: outcome.isSuccess ? "checkmark.circle.fill" : "exclamationmark.octagon.fill")
                .font(.system(size: 16))
                .foregroundStyle(outcome.isSuccess ? AppTheme.successGreen : AppTheme.dangerRed)
            VStack(alignment: .leading, spacing: 3) {
                Text(outcome.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(outcome.message)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if !outcome.urls.isEmpty {
                    HStack(spacing: 8) {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting(outcome.urls)
                        }
                        if outcome.urls.count == 1 {
                            Button("Open") { NSWorkspace.shared.open(outcome.urls[0]) }
                        }
                    }
                    .controlSize(.small)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(12)
        .background((outcome.isSuccess ? AppTheme.successGreen : AppTheme.dangerRed).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((outcome.isSuccess ? AppTheme.successGreen : AppTheme.dangerRed).opacity(0.35), lineWidth: 1)
        )
    }
}

private func studioCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) { content() }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
}

private func selectedFileHeader(_ url: URL, icon: String = "doc.fill", detail: String? = nil, onClear: @escaping () -> Void) -> some View {
    HStack(spacing: 8) {
        Image(systemName: icon).foregroundStyle(AppTheme.electricBlue)
        VStack(alignment: .leading, spacing: 1) {
            Text(url.lastPathComponent)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            if let detail {
                Text(detail).font(.system(size: 10)).foregroundStyle(AppTheme.textSecondary)
            }
        }
        Spacer()
        Button("Remove", action: onClear)
            .controlSize(.small)
    }
}

@MainActor
private func savePanel(suggestedName: String, types: [UTType] = [.pdf], directory: URL? = nil) -> URL? {
    let panel = NSSavePanel()
    panel.allowedContentTypes = types
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = suggestedName
    if let directory { panel.directoryURL = directory }
    return panel.runModal() == .OK ? panel.url : nil
}

@MainActor
private func chooseFolder(title: String) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.title = title
    panel.prompt = "Choose"
    return panel.runModal() == .OK ? panel.url : nil
}

private func fileSizeText(_ url: URL) -> String {
    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    return Formatters.bytes(UInt64(size))
}

// MARK: - Assembly (Images to PDF, Merge PDFs, Mixed, Page Organizer, Rotate & Reorder)

struct PDFAssemblyWorkspaceView: View {
    let tool: PDFStudioTool
    @ObservedObject var service: PDFAssemblyService

    @State private var isTargetedForDrop = false
    @State private var draggingID: UUID?
    @State private var outcome: PDFStudioOutcome?
    @State private var pendingOverwriteURL: URL?
    @State private var showInspector = true
    @State private var showInspectorPopover = false
    @State private var isCompact = false

    private static let compactWidth: CGFloat = 640

    init(tool: PDFStudioTool) {
        self.tool = tool
        self.service = PDFAssemblyService.workspace(for: tool)
    }

    private var acceptsImages: Bool { service.acceptedTypes.contains(.image) }
    private var acceptsPDFs: Bool { service.acceptedTypes.contains(.pdfPage) }
    private var hasImagePages: Bool { service.pages.contains { $0.sourceType == .image } }

    private var allowedContentTypes: [UTType] {
        var types: [UTType] = []
        if acceptsPDFs { types.append(.pdf) }
        if acceptsImages { types += [.png, .jpeg, .heic, .tiff, .bmp, .gif, .webP] }
        return types
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                actionToolbar
                Divider()
                if let issues = service.importIssues {
                    Label(issues, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.warningAmber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(AppTheme.warningAmber.opacity(0.1))
                }
                if service.pages.isEmpty {
                    emptyState
                } else {
                    pageGrid
                }
                if let outcome {
                    PDFStudioOutcomeBanner(outcome: outcome) { self.outcome = nil }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                Divider()
                exportBar
            }
            .frame(minWidth: 320)

            if showInspector && !isCompact {
                inspectorPanel
                    .frame(minWidth: 210, idealWidth: 250, maxWidth: 300)
                    .background(AppTheme.sidebarBackground)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { isCompact = proxy.size.width < Self.compactWidth }
                    .onChange(of: proxy.size.width) { _, width in isCompact = width < Self.compactWidth }
            }
        )
        .alert("File Already Exists", isPresented: Binding(get: { pendingOverwriteURL != nil }, set: { if !$0 { pendingOverwriteURL = nil } })) {
            Button("Keep Both") {
                if let url = pendingOverwriteURL { runExport(to: PDFSafeWriter.uniqueURL(for: url)) }
                pendingOverwriteURL = nil
            }
            Button("Replace", role: .destructive) {
                if let url = pendingOverwriteURL { runExport(to: url) }
                pendingOverwriteURL = nil
            }
            Button("Cancel", role: .cancel) { pendingOverwriteURL = nil }
        } message: {
            Text("“\(pendingOverwriteURL?.lastPathComponent ?? "")” already exists in the destination folder. The existing file is only replaced after the new PDF has been written and verified.")
        }
    }

    // MARK: Toolbar

    private var actionToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { selectFiles() } label: { Label("Add Files", systemImage: "plus.circle.fill") }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentFill)
                    .help(acceptsImages && acceptsPDFs ? "Add PDFs and images" : (acceptsImages ? "Add images" : "Add PDF documents"))

                if !service.pages.isEmpty {
                    Button("Select All") { service.selectAllPages() }
                    Button("Deselect") { service.deselectAllPages() }
                        .disabled(!service.pages.contains(where: \.isSelected))
                    Divider().frame(height: 16)
                    Button { service.rotateSelectedOrAll(delta: -90) } label: { Image(systemName: "rotate.left") }
                        .help(rotationHelp("left 90°"))
                    Button { service.rotateSelectedOrAll(delta: 90) } label: { Image(systemName: "rotate.right") }
                        .help(rotationHelp("right 90°"))
                    Button { service.rotateSelectedOrAll(delta: 180) } label: { Text("180°") }
                        .help(rotationHelp("180°"))
                    Button { service.reverseOrder() } label: { Label("Reverse", systemImage: "arrow.up.arrow.down") }
                        .help("Reverse the page order")
                    Button(role: .destructive) { service.removeSelectedPages() } label: { Label("Delete Selected", systemImage: "trash") }
                        .disabled(!service.pages.contains(where: \.isSelected))
                    Divider().frame(height: 16)
                    Button("Clear All") { service.clearAllPages() }
                        .foregroundStyle(AppTheme.dangerRed)
                }
                Divider().frame(height: 16)
                Button {
                    if isCompact { showInspectorPopover.toggle() } else { showInspector.toggle() }
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help(isCompact ? "Show page settings" : (showInspector ? "Hide page settings" : "Show page settings"))
                .popover(isPresented: $showInspectorPopover, arrowEdge: .bottom) {
                    inspectorPanel.frame(width: 260, height: 420)
                }
            }
            .controlSize(.small)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppTheme.cardBackgroundSecondary)
    }

    private func rotationHelp(_ amount: String) -> String {
        service.pages.contains(where: \.isSelected) ? "Rotate selected pages \(amount)" : "Rotate all pages \(amount) (select pages to rotate only those)"
    }

    // MARK: Content

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: tool.icon)
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.electricBlue)
            VStack(spacing: 6) {
                Text(emptyTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(emptySubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }
            Button("Choose Files…") { selectFiles() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isTargetedForDrop ? AppTheme.electricBlue : AppTheme.borderStrong, style: StrokeStyle(lineWidth: isTargetedForDrop ? 2 : 1, dash: [6, 4]))
                .padding(16)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop, perform: handleFileDrop)
    }

    private var emptyTitle: String {
        switch tool {
        case .imagesToPDF: return "Drop Images to Build a PDF"
        case .mergePDFs: return "Drop PDF Documents to Merge"
        case .mergeMixed: return "Drop Images and PDFs to Combine"
        case .pageOrganizer: return "Drop a PDF to Organize Its Pages"
        default: return "Drop a PDF to Rotate or Reorder Pages"
        }
    }

    private var emptySubtitle: String {
        switch tool {
        case .imagesToPDF: return "PNG, JPEG, HEIC, TIFF, GIF, BMP and WebP. Each image becomes one page at full resolution with its camera orientation applied."
        case .mergePDFs: return "Pages keep their size, text, vector graphics, links and annotations. Drag cards to change the order."
        case .mergeMixed: return "Mix image pages and PDF pages in any order. Images are placed on the paper size you choose."
        case .pageOrganizer: return "Reorder by dragging, rotate, duplicate or delete pages, then export a new PDF. Your original file is not changed."
        default: return "Rotate pages by 90°, 180° or 270°, reverse the order, and export a new PDF. Your original file is not changed."
        }
    }

    private var pageGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 14)], spacing: 14) {
                ForEach(Array(service.pages.enumerated()), id: \.element.id) { index, item in
                    pageCard(item: item, index: index)
                        .opacity(draggingID == item.id ? 0.45 : 1)
                        .onDrag {
                            draggingID = item.id
                            return NSItemProvider(object: item.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: PageReorderDropDelegate(targetID: item.id, service: service, draggingID: $draggingID))
                }
            }
            .padding(16)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop, perform: handleFileDrop)
    }

    private func pageCard(item: PDFStudioPageItem, index: Int) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                    if let thumb = item.cachedThumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .scaledToFit()
                            .rotationEffect(.degrees(Double(displayRotation(item))))
                            .padding(6)
                    } else {
                        Image(systemName: item.sourceType == .pdfPage ? "doc.text.fill" : "photo")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.gray)
                    }
                }
                .frame(height: 170)
                .clipped()

                Button {
                    service.togglePageSelection(id: item.id)
                } label: {
                    Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(item.isSelected ? AppTheme.electricBlue : Color.gray.opacity(0.7))
                        .background(Color.white.clipShape(Circle()))
                }
                .buttonStyle(.plain)
                .padding(6)
                .help(item.isSelected ? "Deselect page" : "Select page")
            }

            HStack(spacing: 4) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(item.pageTitle)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .help(item.pageTitle)
                Spacer(minLength: 0)
                if item.rotationAngle != 0 {
                    Text("\(item.rotationAngle)°")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.electricBlue)
                }
            }

            HStack(spacing: 10) {
                cardButton("chevron.left", help: "Move earlier", disabled: index == 0) { service.movePage(id: item.id, by: -1) }
                cardButton("chevron.right", help: "Move later", disabled: index == service.pages.count - 1) { service.movePage(id: item.id, by: 1) }
                Spacer(minLength: 0)
                cardButton("rotate.left", help: "Rotate 90° left") { service.rotatePage(id: item.id, delta: -90) }
                cardButton("rotate.right", help: "Rotate 90° right") { service.rotatePage(id: item.id, delta: 90) }
                cardButton("plus.square.on.square", help: "Duplicate page") { service.duplicatePage(id: item.id) }
                cardButton("trash", help: "Delete page", tint: AppTheme.dangerRed) { service.removePage(id: item.id) }
            }
        }
        .padding(8)
        .background(item.isSelected ? AppTheme.selectionBackground : AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(item.isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: item.isSelected ? 1.5 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { service.togglePageSelection(id: item.id) }
    }

    private func displayRotation(_ item: PDFStudioPageItem) -> Int {
        item.rotationAngle - item.thumbnailRotation
    }

    private func cardButton(_ icon: String, help: String, disabled: Bool = false, tint: Color = AppTheme.textSecondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(disabled ? AppTheme.disabledText : tint)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: Inspector

    private var inspectorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(acceptsImages ? "Page Configuration" : "Output")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                if acceptsImages {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Paper Size for Images").font(.system(size: 11, weight: .medium)).foregroundStyle(AppTheme.textSecondary)
                        Picker("", selection: $service.pageSizePreset) {
                            ForEach(PDFPageSizePreset.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                    }
                    if service.pageSizePreset != .matchImage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Margins").font(.system(size: 11, weight: .medium)).foregroundStyle(AppTheme.textSecondary)
                            Picker("", selection: $service.pageMargin) {
                                ForEach(PDFPageMargin.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .labelsHidden()
                        }
                        Toggle("Landscape Orientation", isOn: $service.isLandscape)
                            .font(.system(size: 11))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Image Fit").font(.system(size: 11, weight: .medium)).foregroundStyle(AppTheme.textSecondary)
                            Picker("", selection: $service.imageFitMode) {
                                ForEach(ImageFitMode.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .labelsHidden()
                        }
                    }
                    if acceptsPDFs {
                        Text("PDF pages always keep their own size.")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                } else {
                    Text("PDF pages are copied with their original size, text, vector graphics, links and annotations. Rotation is stored losslessly in the page.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Summary").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.textSecondary)
                    Text("Total pages: \(service.pages.count)").font(.system(size: 11))
                    Text("Selected: \(service.pages.filter(\.isSelected).count)").font(.system(size: 11))
                    if acceptsPDFs && acceptsImages {
                        Text("PDF pages: \(service.pages.filter { $0.sourceType == .pdfPage }.count)").font(.system(size: 11))
                        Text("Image pages: \(service.pages.filter { $0.sourceType == .image }.count)").font(.system(size: 11))
                    }
                    Text("Tip: drag cards to reorder, or use the arrow buttons.")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(14)
        }
    }

    // MARK: Export

    private var exportBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Output Filename").font(.system(size: 10)).foregroundStyle(AppTheme.textSecondary)
                TextField("Document Name", text: $service.outputFilename)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 120, maxWidth: 200)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Destination").font(.system(size: 10)).foregroundStyle(AppTheme.textSecondary)
                Button(service.outputDirectory?.lastPathComponent ?? "Choose…") {
                    if let folder = chooseFolder(title: "Choose Destination Folder") { service.outputDirectory = folder }
                }
                .controlSize(.small)
                .help(service.outputDirectory?.path ?? "Choose where the PDF is saved")
            }
            Spacer()
            if service.isProcessing {
                ProgressView(value: service.currentProgress)
                    .frame(width: 100)
                Text(service.statusMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Button("Preview") { preview() }
                .controlSize(.small)
                .disabled(service.pages.isEmpty || service.isProcessing)
                .help("Build the PDF into a temporary file and open it")
            Button { triggerExport() } label: { Label("Export PDF", systemImage: "arrow.down.doc.fill") }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
                .controlSize(.small)
                .disabled(service.pages.isEmpty || service.isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
    }

    private func triggerExport() {
        let trimmed = service.outputFilename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/"), !trimmed.contains(":") else {
            outcome = .failure("Invalid File Name", "Enter a file name without “/” or “:”.")
            return
        }
        guard let folder = service.outputDirectory ?? chooseFolder(title: "Choose Destination Folder") else { return }
        service.outputDirectory = folder
        let name = trimmed.lowercased().hasSuffix(".pdf") ? trimmed : "\(trimmed).pdf"
        let destination = folder.appendingPathComponent(name)
        if service.pages.contains(where: { $0.sourceURL.standardizedFileURL == destination.standardizedFileURL }) {
            outcome = .failure("Choose a Different Name", "“\(name)” is one of the input files. Export never overwrites a source document.")
            return
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            pendingOverwriteURL = destination
        } else {
            runExport(to: destination)
        }
    }

    private func runExport(to destination: URL) {
        outcome = nil
        Task {
            switch await service.export(to: destination) {
            case .success(let url):
                outcome = .success("PDF Exported", "\(service.pages.count) page(s) saved to “\(url.lastPathComponent)” and verified.", urls: [url])
            case .failure(let error):
                outcome = .failure("Export Failed", error)
            }
        }
    }

    private func preview() {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("Preview-\(UUID().uuidString.prefix(8)).pdf")
        Task {
            switch await service.export(to: temp) {
            case .success(let url):
                NSWorkspace.shared.open(url)
            case .failure(let error):
                outcome = .failure("Preview Failed", error)
            }
        }
    }

    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = allowedContentTypes
        if panel.runModal() == .OK {
            service.addFiles(urls: panel.urls)
        }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { service.addFiles(urls: [url]) }
            }
        }
        return true
    }
}

private struct PageReorderDropDelegate: DropDelegate {
    let targetID: UUID
    let service: PDFAssemblyService
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        AppLog.concurrency.debug("[PDFStudio] Reorder drop entered on thread \(Thread.isMainThread ? "main" : "background"), animating on main queue")
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.15)) {
                service.movePage(id: draggingID, before: targetID)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

// MARK: - Word & Office to PDF

struct PDFOfficeConvertView: View {
    @ObservedObject var service = PDFOfficeConverterService.shared
    @State private var sourceURL: URL?
    @State private var outcome: PDFStudioOutcome?

    private var allowedTypes: [UTType] {
        service.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.electricBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Offline Document Conversion")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(service.isLibreOfficeAvailable
                             ? "LibreOffice detected: used for Word, OpenDocument, PowerPoint and Excel files, with the macOS text system as fallback."
                             : "macOS text system: Word (.docx, .doc), OpenDocument Text, RTF, plain text, HTML and Markdown. Install LibreOffice for PowerPoint/Excel and higher-fidelity Word layout.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(14)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                FileDropZoneView(
                    title: "Select a Document to Convert",
                    subtitle: service.supportedExtensions.sorted().map { ".\($0)" }.joined(separator: " "),
                    icon: "doc.badge.gearshape.fill",
                    allowedTypes: allowedTypes,
                    allowsMultiple: false
                ) { urls in
                    guard let first = urls.first else { return }
                    if service.isSupported(first) {
                        sourceURL = first
                        outcome = nil
                    } else {
                        outcome = .failure("Unsupported Format", "“\(first.lastPathComponent)” cannot be converted. Supported: \(service.supportedExtensions.sorted().map { ".\($0)" }.joined(separator: ", ")).")
                    }
                }

                if let url = sourceURL {
                    studioCard {
                        selectedFileHeader(url, detail: fileSizeText(url)) { sourceURL = nil }
                        HStack(spacing: 12) {
                            Button("Convert to PDF…") { convert(url) }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accentFill)
                                .disabled(service.isProcessing)
                            if service.isProcessing {
                                ProgressView().controlSize(.small)
                                Text(service.statusMessage).font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        Text("Layout fidelity: complex Word features (text boxes, columns, tracked changes) may be simplified by the macOS text system.")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }

                if let outcome {
                    PDFStudioOutcomeBanner(outcome: outcome) { self.outcome = nil }
                }
            }
            .padding(20)
        }
    }

    private func convert(_ url: URL) {
        guard let destination = savePanel(suggestedName: url.deletingPathExtension().lastPathComponent + ".pdf", directory: url.deletingLastPathComponent()) else { return }
        outcome = nil
        Task {
            switch await service.convertDocument(from: url, to: destination) {
            case .success(let written):
                let pages = PDFDocument(url: written)?.pageCount ?? 0
                outcome = .success("Converted", "“\(url.lastPathComponent)” was converted to a \(pages)-page PDF.", urls: [written])
            case .failure(let error):
                outcome = .failure("Conversion Failed", error)
            }
        }
    }
}

// MARK: - OCR & Searchable PDF

struct PDFOCRToolView: View {
    @ObservedObject var service = PDFOCRService.shared
    @State private var sourceURL: URL?
    @State private var outcome: PDFStudioOutcome?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Vision On-Device Text Recognition")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Extract text from scans and photos, or create a searchable PDF with an invisible text layer aligned to the visible words. Nothing leaves your Mac.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Picker("Language", selection: $service.selectedLanguage) {
                        ForEach(service.languageChoices, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(width: 170)
                }
                .padding(14)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                FileDropZoneView(
                    title: "Select a Scanned PDF or Image",
                    subtitle: "PDF, PNG, JPEG, HEIC, TIFF",
                    icon: "text.viewfinder",
                    allowedTypes: [.pdf, .image],
                    allowsMultiple: false
                ) { urls in
                    if let first = urls.first {
                        sourceURL = first
                        service.recognizedText = ""
                        outcome = nil
                    }
                }

                if let url = sourceURL {
                    studioCard {
                        selectedFileHeader(url, icon: "doc.text.viewfinder", detail: pageInfo(url)) { sourceURL = nil }
                        Toggle("Also run OCR on pages that already contain text", isOn: $service.forceOCROnTextPages)
                            .font(.system(size: 11))
                            .help("Off (recommended): pages with an existing text layer are kept unchanged, so no duplicate text is created.")
                        HStack(spacing: 12) {
                            Button("Extract Text") { service.extractText(from: url) }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accentFill)
                                .disabled(service.isProcessing)
                            Button("Create Searchable PDF…") { createSearchable(url) }
                                .disabled(service.isProcessing)
                            if service.isProcessing {
                                Button("Cancel") { service.cancel() }
                            }
                        }
                        if service.isProcessing || service.statusMessage != "Ready" {
                            HStack(spacing: 8) {
                                if service.isProcessing {
                                    ProgressView(value: service.currentProgress).frame(width: 120)
                                }
                                Text(service.statusMessage)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        if !service.recognizedText.isEmpty {
                            HStack {
                                Text("Recognized Text").font(.system(size: 12, weight: .bold))
                                Spacer()
                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(service.recognizedText, forType: .string)
                                }
                                Button("Save as Text…") { saveText(url) }
                            }
                            .controlSize(.small)
                            ScrollView {
                                Text(service.recognizedText)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            }
                            .frame(height: 220)
                            .background(AppTheme.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                if let outcome {
                    PDFStudioOutcomeBanner(outcome: outcome) { self.outcome = nil }
                }
            }
            .padding(20)
        }
    }

    private func pageInfo(_ url: URL) -> String {
        guard url.pathExtension.lowercased() == "pdf" else { return "Image · \(fileSizeText(url))" }
        guard let doc = PDFDocument(url: url) else { return "Unreadable PDF" }
        if doc.isLocked { return "Password-protected" }
        let textPages = (0..<doc.pageCount).filter { !(doc.page(at: $0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }.count
        return "\(doc.pageCount) page(s) · \(textPages) already searchable"
    }

    private func createSearchable(_ url: URL) {
        guard let destination = savePanel(suggestedName: "\(url.deletingPathExtension().lastPathComponent) (Searchable).pdf", directory: url.deletingLastPathComponent()) else { return }
        outcome = nil
        Task {
            switch await service.makeSearchablePDF(from: url, to: destination) {
            case .success(let report):
                var message = "\(report.recognizedPages) page(s) recognized (\(report.recognizedLines) text lines)"
                if report.preservedTextPages > 0 { message += "; \(report.preservedTextPages) page(s) already had text and were kept unchanged" }
                if report.recognizedLines == 0 && report.recognizedPages > 0 { message += ". No text was recognized; check the language setting or scan quality" }
                outcome = .success("Searchable PDF Created", message + ".", urls: [report.outputURL])
            case .failure(let error):
                outcome = .failure("OCR Failed", error)
            }
        }
    }

    private func saveText(_ url: URL) {
        guard let destination = savePanel(suggestedName: "\(url.deletingPathExtension().lastPathComponent).txt", types: [.plainText], directory: url.deletingLastPathComponent()) else { return }
        do {
            try service.recognizedText.write(to: destination, atomically: true, encoding: .utf8)
            outcome = .success("Text Saved", "Saved to “\(destination.lastPathComponent)”.", urls: [destination])
        } catch {
            outcome = .failure("Save Failed", error)
        }
    }
}

// MARK: - PDF Splitter

struct PDFSplitterToolView: View {
    @State private var sourceURL: URL?
    @State private var pageCount = 0
    @State private var splitMode = "each"
    @State private var splitInterval = 2
    @State private var rangesText = "1-2, 3-5"
    @State private var isRunning = false
    @State private var outcome: PDFStudioOutcome?

    private var plan: Result<Int, Error> {
        guard pageCount > 0 else { return .failure(PDFStudioError.noDocument) }
        switch splitMode {
        case "each": return .success(pageCount)
        case "interval": return .success(Int(ceil(Double(pageCount) / Double(max(1, splitInterval)))))
        default:
            do { return .success(try PDFSafeWriter.parsePageRanges(rangesText, pageCount: pageCount).count) } catch { return .failure(error) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FileDropZoneView(
                    title: "Select a PDF to Split",
                    subtitle: "Split into single pages, page ranges or N-page parts",
                    icon: "scissors",
                    allowedTypes: [.pdf],
                    allowsMultiple: false
                ) { urls in load(urls.first) }

                if let url = sourceURL {
                    studioCard {
                        selectedFileHeader(url, detail: "\(pageCount) page(s) · \(fileSizeText(url))") { sourceURL = nil }
                        Picker("Split Mode", selection: $splitMode) {
                            Text("Every page as its own PDF").tag("each")
                            Text("Custom page ranges").tag("range")
                            Text("Every N pages").tag("interval")
                        }
                        .pickerStyle(.radioGroup)
                        if splitMode == "range" {
                            TextField("Ranges, e.g. 1-2, 3-5, 8", text: $rangesText)
                                .textFieldStyle(.roundedBorder)
                            Text("Each comma-separated range becomes one file.")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textTertiary)
                        } else if splitMode == "interval" {
                            Stepper("Every \(splitInterval) page(s)", value: $splitInterval, in: 1...max(1, pageCount))
                        }
                        switch plan {
                        case .success(let count):
                            Text("Will create \(count) PDF file(s). Existing files are never overwritten.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        case .failure(let error):
                            Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.dangerRed)
                        }
                        HStack {
                            Button("Split PDF…") { run(url) }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accentFill)
                                .disabled(isRunning || (try? plan.get()) == nil)
                            if isRunning { ProgressView().controlSize(.small) }
                        }
                    }
                }

                if let outcome {
                    PDFStudioOutcomeBanner(outcome: outcome) { self.outcome = nil }
                }
            }
            .padding(20)
        }
    }

    private func load(_ url: URL?) {
        guard let url else { return }
        outcome = nil
        do {
            let doc = try PDFSafeWriter.openReadable(url)
            sourceURL = url
            pageCount = doc.pageCount
        } catch {
            sourceURL = nil
            outcome = .failure("Cannot Open PDF", error)
        }
    }

    private func run(_ url: URL) {
        guard let folder = chooseFolder(title: "Choose a Folder for the Split Files") else { return }
        isRunning = true
        outcome = nil
        let mode = splitMode, interval = splitInterval, ranges = rangesText
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try PDFAssemblyService.split(sourceURL: url, mode: mode, interval: interval, rangesText: ranges, destinationFolder: folder) }
            }.value
            isRunning = false
            switch result {
            case .success(let urls):
                outcome = .success("PDF Split", "Created \(urls.count) file(s) in “\(folder.lastPathComponent)”.", urls: urls)
            case .failure(let error):
                outcome = .failure("Split Failed", error)
            }
        }
    }
}

// MARK: - Page Extractor

struct PDFExtractorToolView: View {
    @State private var sourceURL: URL?
    @State private var pageCount = 0
    @State private var pagesText = "1"
    @State private var outcome: PDFStudioOutcome?

    private var selection: Result<[Int], Error> {
        do { return .success(try PDFSafeWriter.parsePageRanges(pagesText, pageCount: pageCount).flatMap { $0 }) } catch { return .failure(error) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FileDropZoneView(
                    title: "Select a PDF to Extract Pages From",
                    subtitle: "Copy chosen pages into a new document",
                    icon: "arrow.up.right.and.arrow.down.left.rectangle",
                    allowedTypes: [.pdf],
                    allowsMultiple: false
                ) { urls in load(urls.first) }

                if let url = sourceURL {
                    studioCard {
                        selectedFileHeader(url, detail: "\(pageCount) page(s)") { sourceURL = nil }
                        TextField("Pages, e.g. 1, 3, 5-7", text: $pagesText)
                            .textFieldStyle(.roundedBorder)
                        switch selection {
                        case .success(let pages):
                            Text("Will extract \(pages.count) page(s) in the order listed: \(pages.prefix(20).map { "\($0 + 1)" }.joined(separator: ", "))\(pages.count > 20 ? "…" : "")")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        case .failure(let error):
                            Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.dangerRed)
                        }
                        Button("Extract to New PDF…") { run(url) }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accentFill)
                            .disabled((try? selection.get()) == nil)
                    }
                }

                if let outcome {
                    PDFStudioOutcomeBanner(outcome: outcome) { self.outcome = nil }
                }
            }
            .padding(20)
        }
    }

    private func load(_ url: URL?) {
        guard let url else { return }
        outcome = nil
        do {
            let doc = try PDFSafeWriter.openReadable(url)
            sourceURL = url
            pageCount = doc.pageCount
            pagesText = "1"
        } catch {
            sourceURL = nil
            outcome = .failure("Cannot Open PDF", error)
        }
    }

    private func run(_ url: URL) {
        guard let destination = savePanel(suggestedName: "\(url.deletingPathExtension().lastPathComponent) (Extracted).pdf", directory: url.deletingLastPathComponent()) else { return }
        do {
            let count = try PDFAssemblyService.extract(sourceURL: url, pageRangesText: pagesText, destinationURL: destination)
            outcome = .success("Pages Extracted", "\(count) page(s) saved to “\(destination.lastPathComponent)”.", urls: [destination])
        } catch {
            outcome = .failure("Extraction Failed", error)
        }
    }
}

// MARK: - Metadata & Privacy

struct PDFMetadataToolView: View {
    @ObservedObject var service = PDFMetadataInspectorService.shared
    @State private var outcome: PDFStudioOutcome?
    @State private var removeAuthors = true
    @State private var removeAnnotations = false
    @State private var editTitle = ""
    @State private var editAuthor = ""
    @State private var editSubject = ""
    @State private var editKeywords = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FileDropZoneView(
                    title: "Select a PDF to Inspect",
                    subtitle: "See hidden document properties, then save a cleaned or edited copy",
                    icon: "lock.shield.fill",
                    allowedTypes: [.pdf],
                    allowsMultiple: false
                ) { urls in
                    guard let first = urls.first else { return }
                    outcome = nil
                    service.inspectDocument(url: first)
                    let meta = service.metadata
                    editTitle = meta.title ?? ""
                    editAuthor = meta.author ?? ""
                    editSubject = meta.subject ?? ""
                    editKeywords = meta.keywords.joined(separator: ", ")
                }

                if let error = service.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.warningAmber)
                }

                if let url = service.sourceURL, service.document != nil {
                    let report = service.metadata
                    studioCard {
                        Text("Report: \(url.lastPathComponent)")
                            .font(.system(size: 14, weight: .bold))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                            field("Title", report.title)
                            field("Author", report.author)
                            field("Subject", report.subject)
                            field("Keywords", report.keywords.isEmpty ? nil : report.keywords.joined(separator: ", "))
                            field("Creator App", report.creator)
                            field("PDF Producer", report.producer)
                            field("Created", report.creationDate.map { $0.formatted(date: .abbreviated, time: .shortened) })
                            field("Modified", report.modificationDate.map { $0.formatted(date: .abbreviated, time: .shortened) })
                            field("Pages", "\(report.pageCount)")
                            field("PDF Version", report.pdfVersion)
                            field("File Size", Formatters.bytes(report.fileSize))
                            field("Encrypted", report.isEncrypted ? (report.isLocked ? "Yes (locked)" : "Yes") : "No")
                            field("Annotations", "\(report.annotationCount)")
                            field("Annotation Authors", report.annotationAuthors.isEmpty ? nil : report.annotationAuthors.joined(separator: ", "))
                            field("Form Fields", "\(report.formFieldCount)")
                            field("Permissions", permissions(report))
                        }
                    }

                    if !report.isLocked {
                        studioCard {
                            Text("Sanitize").font(.system(size: 13, weight: .bold))
                            Text("Creates a new PDF from copies of the pages without the original title, author, subject, keywords, creator or XMP metadata. macOS records its own Producer and date when any PDF is written; that cannot be removed.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Toggle("Remove annotation author names and dates", isOn: $removeAuthors).font(.system(size: 11))
                            Toggle("Remove all comments and markups (keeps form fields)", isOn: $removeAnnotations).font(.system(size: 11))
                            Button("Save Sanitized Copy…") { sanitize(url) }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.successFill)
                        }

                        studioCard {
                            Text("Edit Metadata").font(.system(size: 13, weight: .bold))
                            TextField("Title", text: $editTitle).textFieldStyle(.roundedBorder)
                            TextField("Author", text: $editAuthor).textFieldStyle(.roundedBorder)
                            TextField("Subject", text: $editSubject).textFieldStyle(.roundedBorder)
                            TextField("Keywords (comma separated)", text: $editKeywords).textFieldStyle(.roundedBorder)
                            Button("Save Copy with Metadata…") { saveEdited(url) }
                        }
                    }
                }

                if let outcome {
                    PDFStudioOutcomeBanner(outcome: outcome) { self.outcome = nil }
                }
            }
            .padding(20)
        }
    }

    private func permissions(_ report: PDFDetailedMetadata) -> String {
        var denied: [String] = []
        if !report.allowsPrinting { denied.append("printing") }
        if !report.allowsCopying { denied.append("copying") }
        if !report.allowsChanges { denied.append("editing") }
        if !report.allowsCommenting { denied.append("commenting") }
        if !report.allowsFormFilling { denied.append("form filling") }
        return denied.isEmpty ? "All allowed" : "Restricted: " + denied.joined(separator: ", ")
    }

    private func field(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundStyle(AppTheme.textSecondary)
            Text(value ?? "None")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(value == nil ? AppTheme.textTertiary : AppTheme.textPrimary)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func sanitize(_ url: URL) {
        guard let destination = savePanel(suggestedName: "\(url.deletingPathExtension().lastPathComponent) (Sanitized).pdf", directory: url.deletingLastPathComponent()) else { return }
        let options = PDFSanitizeOptions(removeAnnotationAuthors: removeAuthors, removeAllAnnotations: removeAnnotations)
        if service.sanitizeAndExport(to: destination, options: options) {
            let remaining = PDFDocument(url: destination).map { PDFMetadataInspectorService.inspect(document: $0) }
            let producer = remaining?.producer.map { " Producer now reads “\($0)”." } ?? ""
            outcome = .success("Sanitized Copy Saved", "Title, author, subject, keywords and creator were removed and verified after reopening.\(producer)", urls: [destination])
        } else {
            outcome = .failure("Sanitize Failed", service.lastError ?? "Unknown error")
        }
    }

    private func saveEdited(_ url: URL) {
        guard let destination = savePanel(suggestedName: "\(url.deletingPathExtension().lastPathComponent) (Edited).pdf", directory: url.deletingLastPathComponent()) else { return }
        if service.saveEditedCopy(to: destination, title: editTitle, author: editAuthor, subject: editSubject, keywords: editKeywords) {
            outcome = .success("Metadata Saved", "Saved a copy with the updated properties.", urls: [destination])
        } else {
            outcome = .failure("Save Failed", service.lastError ?? "Unknown error")
        }
    }
}

// MARK: - Export & Print

struct PDFExportPrintToolView: View {
    @ObservedObject var editor = PDFEditorService.shared
    @State private var useEditorDocument = true
    @State private var fileURL: URL?
    @State private var fileDocument: PDFDocument?
    @State private var outcome: PDFStudioOutcome?

    private var activeDocument: PDFDocument? {
        useEditorDocument && editor.document != nil ? editor.document : fileDocument
    }

    private var activeName: String {
        useEditorDocument && editor.document != nil ? editor.documentTitle : (fileURL?.lastPathComponent ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.electricBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Print & Validated Export")
                            .font(.system(size: 13, weight: .bold))
                        Text("Print with the macOS print panel, save a verified copy, or save a flattened copy with annotations, images and form values burned into the pages.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Picker("Source", selection: $useEditorDocument) {
                    Text(editor.document == nil ? "Editor (no document open)" : "Editor: \(editor.documentTitle)").tag(true)
                    Text("A PDF file").tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(editor.document == nil)
                .onAppear { if editor.document == nil { useEditorDocument = false } }

                if !useEditorDocument || editor.document == nil {
                    FileDropZoneView(
                        title: "Select a PDF",
                        subtitle: "Print or export a validated copy",
                        icon: "doc.richtext.fill",
                        allowedTypes: [.pdf],
                        allowsMultiple: false
                    ) { urls in load(urls.first) }
                }

                if let doc = activeDocument {
                    studioCard {
                        HStack {
                            Image(systemName: "doc.fill").foregroundStyle(AppTheme.electricBlue)
                            Text(activeName).font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("\(doc.pageCount) page(s)").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                        }
                        if useEditorDocument, editor.hasUnsavedChanges {
                            Text("Includes unsaved edits from the editor.")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.warningAmber)
                        }
                        HStack(spacing: 10) {
                            Button { printDocument(doc) } label: { Label("Print…", systemImage: "printer") }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accentFill)
                                .disabled(!doc.allowsPrinting)
                                .help(doc.allowsPrinting ? "Open the print panel" : "The document's owner disabled printing")
                            Button("Save Validated Copy…") { export(doc, flatten: false) }
                            Button("Save Flattened Copy…") { export(doc, flatten: true) }
                                .help("Burns annotations, inserted images and form values into the page content")
                        }
                    }
                }

                if let outcome {
                    PDFStudioOutcomeBanner(outcome: outcome) { self.outcome = nil }
                }
            }
            .padding(20)
        }
    }

    private func load(_ url: URL?) {
        guard let url else { return }
        outcome = nil
        do {
            fileDocument = try PDFSafeWriter.openReadable(url)
            fileURL = url
        } catch {
            fileDocument = nil
            fileURL = nil
            outcome = .failure("Cannot Open PDF", error)
        }
    }

    private func printDocument(_ doc: PDFDocument) {
        let info = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo.shared
        guard let operation = doc.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: true) else {
            outcome = .failure("Print Unavailable", "macOS could not prepare this document for printing.")
            return
        }
        operation.jobTitle = activeName
        if let window = NSApp.keyWindow {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    private func export(_ doc: PDFDocument, flatten: Bool) {
        let base = (activeName as NSString).deletingPathExtension
        guard let destination = savePanel(suggestedName: "\(base.isEmpty ? "Document" : base)\(flatten ? " (Flattened)" : " (Copy)").pdf") else { return }
        let sources = [useEditorDocument ? editor.sourceURL : fileURL].compactMap { $0?.standardizedFileURL }
        if sources.contains(destination.standardizedFileURL) {
            outcome = .failure("Choose a Different Name", "Exports are separate copies and never replace the source document.")
            return
        }
        do {
            try PDFSafeWriter.write(doc, to: destination, options: flatten ? [.burnInAnnotationsOption: true] : nil)
            let reopened = PDFDocument(url: destination)
            outcome = .success(
                flatten ? "Flattened Copy Saved" : "Validated Copy Saved",
                "Reopened successfully with \(reopened?.pageCount ?? 0) page(s), \(fileSizeText(destination)).",
                urls: [destination]
            )
        } catch {
            outcome = .failure("Export Failed", error)
        }
    }
}
