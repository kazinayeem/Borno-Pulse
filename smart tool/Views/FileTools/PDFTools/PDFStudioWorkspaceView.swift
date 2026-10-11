//
//  PDFStudioWorkspaceView.swift
//  Borno Pulse
//
//  Comprehensive Native macOS PDF Studio Workspace with all 14 tools,
//  drag-and-drop assembly, advanced annotations, OCR, and offline Office conversion.
//

import AppKit
import Foundation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import Vision

public struct PDFStudioWorkspaceView: View {
    @State private var selectedTool: PDFStudioTool = .imagesToPDF
    @State private var showSignatureSheet: Bool = false
    @State private var showFormFieldsSheet: Bool = false
    @State private var showExportSuccessAlert: Bool = false
    @State private var lastExportedURL: URL?
    @State private var isTargetedForDrop: Bool = false
    @State private var showOverwriteConfirmation: Bool = false
    @State private var pendingOverwriteURL: URL?
    
    // Services
    @ObservedObject var assemblyService = PDFAssemblyService.shared
    @ObservedObject var editorService = PDFEditorService.shared
    @ObservedObject var officeService = PDFOfficeConverterService.shared
    @ObservedObject var ocrService = PDFOCRService.shared
    
    // Metadata state
    @State private var metadataReport: PDFDetailedMetadata?
    @State private var metadataURL: URL?
    
    // Splitter state
    @State private var splitterSourceURL: URL?
    @State private var splitMode: String = "each" // "each", "range", "interval"
    @State private var splitInterval: Int = 2
    @State private var splitRangesText: String = "1-2, 3-5"
    @State private var splitStatusMessage: String = ""
    
    // Office conversion state
    @State private var officeSourceURL: URL?
    @State private var officeConvertedURL: URL?
    
    // OCR state
    @State private var ocrSourceURL: URL?
    @State private var ocrSearchableOutputURL: URL?
    @State private var ocrIsSearchableMode: Bool = true
    
    // Extractor state
    @State private var extractorSourceURL: URL?
    @State private var extractorPageNumbersText: String = "1, 2"
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left Studio Tool Sidebar
            studioToolSidebar
                .frame(width: 230)
                .background(AppTheme.sidebarBackground)
            
            Divider()
            
            // Main Tool Workspace Canvas
            VStack(spacing: 0) {
                workspaceHeader
                
                Divider()
                
                // Workspace Content by Selected Tool
                workspaceCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showSignatureSheet) {
            SignatureDrawingView(isPresented: $showSignatureSheet) { signatureImage in
                editorService.addSignature(image: signatureImage)
            }
        }
        .sheet(isPresented: $showFormFieldsSheet) {
            formFieldsInspectorSheet
        }
        .alert("File Already Exists", isPresented: $showOverwriteConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingOverwriteURL = nil
            }
            Button("Replace File", role: .destructive) {
                if let url = pendingOverwriteURL {
                    _ = assemblyService.exportMergedDocument(to: url)
                    lastExportedURL = url
                    showExportSuccessAlert = true
                }
                pendingOverwriteURL = nil
            }
        } message: {
            Text("A document with this filename already exists. Overwrite the existing document or choose a different name?")
        }
    }
    
    // MARK: - Left Tool Sidebar
    private var studioToolSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sidebar Header
            HStack(spacing: 8) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.electricBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PDF Studio")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Native Local Suite")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sidebarToolGroup("Assemble & Convert", tools: [
                        .imagesToPDF,
                        .mergePDFs,
                        .mergeMixed,
                        .officeToPDF,
                        .pdfToImages
                    ])
                    
                    sidebarToolGroup("Edit & Organize", tools: [
                        .advancedEditor,
                        .pageOrganizer,
                        .splitter,
                        .extractor,
                        .rotateReorder
                    ])
                    
                    sidebarToolGroup("Optimize & Tools", tools: [
                        .compressor,
                        .metadataInspector,
                        .ocrSearchable,
                        .exportPrint
                    ])
                }
                .padding(.vertical, 10)
            }
        }
    }
    
    private func sidebarToolGroup(_ title: String, tools: [PDFStudioTool]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.bottom, 2)
            
            ForEach(tools) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 12))
                            .frame(width: 16)
                            .foregroundStyle(selectedTool == tool ? AppTheme.electricBlue : AppTheme.textSecondary)
                        
                        Text(tool.rawValue)
                            .font(.system(size: 12, weight: selectedTool == tool ? .semibold : .regular))
                            .foregroundStyle(selectedTool == tool ? AppTheme.textPrimary : AppTheme.textSecondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTool == tool ? AppTheme.electricBlue.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
        }
    }
    
    // MARK: - Workspace Header
    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedTool.icon)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.electricBlue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTool.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(selectedTool.description)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
            
            // Privacy Shield Badge
            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.matrixGreen)
                Text("100% Offline & Private")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.matrixGreen)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppTheme.matrixGreen.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
    }
    
    // MARK: - Workspace Dynamic Canvas
    @ViewBuilder
    private var workspaceCanvas: some View {
        switch selectedTool {
        case .imagesToPDF, .mergePDFs, .mergeMixed, .pageOrganizer, .rotateReorder:
            documentAssemblyCanvas
            
        case .advancedEditor:
            advancedEditorCanvas
            
        case .officeToPDF:
            officeToPDFCanvas
            
        case .ocrSearchable:
            ocrSearchableCanvas
            
        case .compressor:
            PDFCompressorView()
            
        case .pdfToImages:
            PDFToImagesView()
            
        case .splitter:
            splitterCanvas
            
        case .extractor:
            extractorCanvas
            
        case .metadataInspector:
            metadataInspectorCanvas
            
        case .exportPrint:
            exportPrintCanvas
        }
    }
    
    // MARK: - 1. Document Assembly Canvas (Images to PDF, Merge PDFs, Mixed, Organizer)
    private var documentAssemblyCanvas: some View {
        HSplitView {
            // Left/Center: Dropzone & Thumbnails Grid
            VStack(spacing: 0) {
                // Top Action Toolbar
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Button {
                            selectFilesForAssembly()
                        } label: {
                            Label("Add Files", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.electricBlue)
                        .controlSize(.small)
                        
                        if !assemblyService.pages.isEmpty {
                            Button("Select All") {
                                assemblyService.selectAllPages()
                            }
                            .controlSize(.small)
                            
                            Button("Deselect") {
                                assemblyService.deselectAllPages()
                            }
                            .controlSize(.small)
                            
                            Button {
                                for page in assemblyService.pages where page.isSelected {
                                    assemblyService.rotatePage(id: page.id, delta: 90)
                                }
                            } label: {
                                Label("Rotate 90°", systemImage: "rotate.right")
                            }
                            .controlSize(.small)
                            
                            Button(role: .destructive) {
                                assemblyService.removeSelectedPages()
                            } label: {
                                Label("Delete Selected", systemImage: "trash")
                            }
                            .controlSize(.small)
                            
                            Spacer()
                            
                            Button("Clear All") {
                                assemblyService.clearAllPages()
                            }
                            .controlSize(.small)
                            .foregroundStyle(AppTheme.dangerRed)
                        } else {
                            Spacer()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button {
                                selectFilesForAssembly()
                            } label: {
                                Label("Add Files", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.electricBlue)
                            .controlSize(.small)
                            
                            if !assemblyService.pages.isEmpty {
                                Button("Select All") {
                                    assemblyService.selectAllPages()
                                }
                                .controlSize(.small)
                                
                                Button("Deselect") {
                                    assemblyService.deselectAllPages()
                                }
                                .controlSize(.small)
                            }
                            
                            Spacer()
                        }
                        
                        if !assemblyService.pages.isEmpty {
                            HStack(spacing: 8) {
                                Button {
                                    for page in assemblyService.pages where page.isSelected {
                                        assemblyService.rotatePage(id: page.id, delta: 90)
                                    }
                                } label: {
                                    Label("Rotate 90°", systemImage: "rotate.right")
                                }
                                .controlSize(.small)
                                
                                Button(role: .destructive) {
                                    assemblyService.removeSelectedPages()
                                } label: {
                                    Label("Delete Selected", systemImage: "trash")
                                }
                                .controlSize(.small)
                                
                                Spacer()
                                
                                Button("Clear All") {
                                    assemblyService.clearAllPages()
                                }
                                .controlSize(.small)
                                .foregroundStyle(AppTheme.dangerRed)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackgroundSecondary)
                
                Divider()
                
                if assemblyService.pages.isEmpty {
                    // Empty Drop Zone State
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.electricBlue)
                        
                        VStack(spacing: 6) {
                            Text("Drag and Drop Documents & Images")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Import PNG, JPG, HEIC, TIFF images and PDF pages. Reorder, rotate, or assemble into a unified document.")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 440)
                        }
                        
                        Button("Choose Files...") {
                            selectFilesForAssembly()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.electricBlue)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
                    .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                        handleAssemblyDrop(providers: providers)
                    }
                } else {
                    // Page Thumbnails Grid
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 14)], spacing: 14) {
                            ForEach(Array(assemblyService.pages.enumerated()), id: \.element.id) { index, item in
                                assemblyThumbnailCard(item: item, index: index)
                            }
                        }
                        .padding(16)
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                        handleAssemblyDrop(providers: providers)
                    }
                }
                
                Divider()
                
                // Bottom Export Bar
                assemblyExportBar
            }
            .frame(minWidth: 460)
            
            // Right: Inspector Panel for Page Settings
            assemblyInspectorPanel
                .frame(width: 250)
                .background(AppTheme.sidebarBackground)
        }
    }
    
    // MARK: - Assembly Thumbnail Card
    private func assemblyThumbnailCard(item: PDFStudioPageItem, index: Int) -> some View {
        VStack(spacing: 6) {
            // Thumbnail container
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                    
                    if let thumb = item.cachedThumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .scaledToFit()
                            .rotationEffect(.degrees(Double(item.rotationAngle)))
                            .padding(4)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: item.sourceType == .pdfPage ? "doc.text.fill" : "photo")
                                .font(.system(size: 24))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text("Page \(item.originalPageIndex + 1)")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
                .frame(height: 160)
                
                // Selection checkbox
                Button {
                    assemblyService.togglePageSelection(id: item.id)
                } label: {
                    Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(item.isSelected ? AppTheme.electricBlue : Color.gray.opacity(0.6))
                        .background(Color.white.clipShape(Circle()))
                }
                .buttonStyle(.plain)
                .padding(6)
            }
            
            // Metadata & Quick Actions
            HStack(spacing: 4) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Text(item.sourceFilename)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                // Rotate button
                Button {
                    assemblyService.rotatePage(id: item.id, delta: 90)
                } label: {
                    Image(systemName: "rotate.right")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Rotate 90° Clockwise")
                
                // Duplicate button
                Button {
                    assemblyService.duplicatePage(id: item.id)
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Duplicate Page")
                
                // Delete button
                Button {
                    assemblyService.removePage(id: item.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.dangerRed)
                }
                .buttonStyle(.plain)
                .help("Delete Page")
            }
            .padding(.horizontal, 2)
        }
        .padding(8)
        .background(item.isSelected ? AppTheme.electricBlue.opacity(0.12) : AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(item.isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: item.isSelected ? 1.5 : 0.5)
        )
    }
    
    // MARK: - Assembly Inspector Panel
    private var assemblyInspectorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Page Configuration")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                // Paper Size
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paper Preset")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Picker("", selection: $assemblyService.pageSizePreset) {
                        ForEach(PDFPageSizePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Margins
                VStack(alignment: .leading, spacing: 4) {
                    Text("Margins")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Picker("", selection: $assemblyService.pageMargin) {
                        ForEach(PDFPageMargin.allCases) { margin in
                            Text(margin.rawValue).tag(margin)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Orientation
                Toggle("Landscape Orientation", isOn: $assemblyService.isLandscape)
                    .font(.system(size: 11))
                
                Divider()
                
                // Image Fit
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image Fit Mode")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Picker("", selection: $assemblyService.imageFitMode) {
                        ForEach(ImageFitMode.allCases) { fit in
                            Text(fit.rawValue).tag(fit)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Divider()
                
                // Summary Box
                VStack(alignment: .leading, spacing: 6) {
                    Text("Document Summary")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Text("Total Pages: \(assemblyService.pages.count)")
                        .font(.system(size: 11))
                    Text("Selected: \(assemblyService.pages.filter(\.isSelected).count)")
                        .font(.system(size: 11))
                    Text("PDF Pages: \(assemblyService.pages.filter { $0.sourceType == .pdfPage }.count)")
                        .font(.system(size: 11))
                    Text("Image Pages: \(assemblyService.pages.filter { $0.sourceType == .image }.count)")
                        .font(.system(size: 11))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(14)
        }
    }
    
    // MARK: - Assembly Export Bar
    private var assemblyExportBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Output Filename")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
                TextField("Document Name", text: $assemblyService.outputFilename)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Destination")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
                Button(assemblyService.outputDirectory?.lastPathComponent ?? "Choose...") {
                    chooseOutputFolder()
                }
                .controlSize(.small)
            }
            
            Spacer()
            
            if assemblyService.isProcessing {
                ProgressView()
                    .controlSize(.small)
            }
            
            Button("Live Preview") {
                previewAssembledPDF()
            }
            .controlSize(.small)
            .disabled(assemblyService.pages.isEmpty)
            
            Button {
                triggerAssemblyExport()
            } label: {
                Label("Export PDF", systemImage: "arrow.down.doc.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.electricBlue)
            .controlSize(.small)
            .disabled(assemblyService.pages.isEmpty || assemblyService.isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
    }
    
    // MARK: - 2. Advanced PDF Editor Canvas
    private var advancedEditorCanvas: some View {
        VStack(spacing: 0) {
            // Editor Toolbar
            HStack(spacing: 8) {
                Button {
                    openPDFForEditing()
                } label: {
                    Label("Open PDF", systemImage: "folder")
                }
                .controlSize(.small)
                
                Divider().frame(height: 18)
                
                // Annotation Tool Buttons
                ForEach([
                    PDFAnnotationToolType.select,
                    PDFAnnotationToolType.highlight,
                    PDFAnnotationToolType.underline,
                    PDFAnnotationToolType.strikeout,
                    PDFAnnotationToolType.text,
                    PDFAnnotationToolType.rectangle,
                    PDFAnnotationToolType.circle,
                    PDFAnnotationToolType.arrow,
                    PDFAnnotationToolType.stickyNote
                ]) { tool in
                    Button {
                        editorService.selectedAnnotationTool = tool
                    } label: {
                        Image(systemName: tool.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(editorService.selectedAnnotationTool == tool ? AppTheme.electricBlue : AppTheme.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(editorService.selectedAnnotationTool == tool ? AppTheme.electricBlue.opacity(0.18) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help(tool.rawValue)
                }
                
                Button {
                    showSignatureSheet = true
                } label: {
                    Image(systemName: "signature")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Add Signature Stamp")
                
                Divider().frame(height: 18)
                
                // Color Picker for Annotations
                ColorPicker("", selection: $editorService.annotationColor)
                    .labelsHidden()
                    .frame(width: 24, height: 24)
                
                Spacer()
                
                // Undo / Redo
                Button {
                    editorService.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .controlSize(.small)
                .disabled(!editorService.canUndo)
                
                Button {
                    editorService.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .controlSize(.small)
                .disabled(!editorService.canRedo)
                
                Divider().frame(height: 18)
                
                // Page Management
                Button {
                    editorService.rotateCurrentPage()
                } label: {
                    Image(systemName: "rotate.right")
                }
                .controlSize(.small)
                .help("Rotate Current Page 90°")
                
                Button {
                    editorService.insertBlankPage()
                } label: {
                    Image(systemName: "plus.square")
                }
                .controlSize(.small)
                .help("Insert Blank Page")
                
                Button {
                    editorService.duplicateCurrentPage()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .controlSize(.small)
                .help("Duplicate Current Page")
                
                Button(role: .destructive) {
                    editorService.deleteCurrentPage()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.dangerRed)
                }
                .controlSize(.small)
                .help("Delete Current Page")
                
                Divider().frame(height: 18)
                
                // Interactive Forms
                Button {
                    showFormFieldsSheet = true
                } label: {
                    Label("Forms (\(editorService.detectedFormFields.count))", systemImage: "list.bullet.rectangle")
                }
                .controlSize(.small)
                
                // Save As
                Button("Save As...") {
                    saveEditedDocumentAs()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.electricBlue)
                .controlSize(.small)
                .disabled(editorService.document == nil)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.cardBackgroundSecondary)
            
            Divider()
            
            // Document Canvas & Thumbnails
            if let doc = editorService.document {
                HSplitView {
                    // Left Editor Page List
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(0..<doc.pageCount, id: \.self) { idx in
                                Button {
                                    editorService.currentPageIndex = idx
                                } label: {
                                    VStack(spacing: 4) {
                                        if let page = doc.page(at: idx) {
                                            Image(nsImage: page.thumbnail(of: CGSize(width: 80, height: 110), for: .mediaBox))
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 80, height: 110)
                                                .background(Color.white)
                                                .shadow(color: Color.black.opacity(0.15), radius: 2)
                                        }
                                        Text("Page \(idx + 1)")
                                            .font(.system(size: 10, weight: editorService.currentPageIndex == idx ? .bold : .regular))
                                            .foregroundStyle(editorService.currentPageIndex == idx ? AppTheme.electricBlue : AppTheme.textSecondary)
                                    }
                                    .padding(6)
                                    .background(editorService.currentPageIndex == idx ? AppTheme.electricBlue.opacity(0.15) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                    }
                    .frame(width: 120)
                    
                    // Center PDFKit Native Canvas View
                    PDFKitRepresentedView(
                        document: doc,
                        currentPageIndex: $editorService.currentPageIndex
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.underPageBackgroundColor))
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.electricBlue)
                    Text("No PDF Document Open")
                        .font(.system(size: 16, weight: .bold))
                    Text("Open an existing PDF document to edit pages, add text, highlights, shapes, sticky notes, and signatures.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: 400)
                        .multilineTextAlignment(.center)
                    Button("Open PDF...") {
                        openPDFForEditing()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.electricBlue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - 3. Word & Office to PDF Canvas
    private var officeToPDFCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Engine Status Card
                HStack(spacing: 12) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.electricBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Native macOS Document Processing Engine")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(officeService.isLibreOfficeAvailable ?
                             "Active: CoreText / TextKit with LibreOffice Headless Fallback Detected. 100% offline." :
                             "Active: Apple CoreText / TextKit Engine. Converts DOCX, RTF, TXT, HTML, and Markdown offline.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AppTheme.matrixGreen)
                }
                .padding(14)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Dropzone for Office Documents
                FileDropZoneView(
                    title: "Select Word or Office Document",
                    subtitle: "Supports .docx, .rtf, .txt, .html, .md offline",
                    icon: "doc.badge.gearshape.fill",
                    allowedTypes: [.item]
                ) { urls in
                    if let first = urls.first {
                        officeSourceURL = first
                    }
                }
                
                if let url = officeSourceURL {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(AppTheme.electricBlue)
                            Text(url.lastPathComponent)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text(fileSizeString(for: url))
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        HStack(spacing: 12) {
                            Button("Convert to PDF") {
                                convertOfficeDocument()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.electricBlue)
                            .disabled(officeService.isProcessing)
                            
                            if let converted = officeConvertedURL {
                                Button("Reveal PDF in Finder") {
                                    NSWorkspace.shared.selectFile(converted.path, inFileViewerRootedAtPath: converted.deletingLastPathComponent().path)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - 4. OCR & Searchable PDF Canvas
    private var ocrSearchableCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header & Language selector
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Vision On-Device Text Recognition")
                            .font(.system(size: 14, weight: .bold))
                        Text("Extract text from scanned PDFs & images, or overlay an invisible searchable text layer.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Picker("Language", selection: $ocrService.selectedLanguage) {
                        ForEach(ocrService.supportedLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .frame(width: 130)
                }
                .padding(14)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Dropzone for OCR
                FileDropZoneView(
                    title: "Select Scanned PDF or Image",
                    subtitle: "Supports PDF, PNG, JPG, TIFF for local neural recognition",
                    icon: "text.viewfinder",
                    allowedTypes: [.pdf, .image]
                ) { urls in
                    if let first = urls.first {
                        ocrSourceURL = first
                        ocrService.recognizedText = ""
                        ocrSearchableOutputURL = nil
                    }
                }
                
                if let url = ocrSourceURL {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.viewfinder")
                                .foregroundStyle(AppTheme.electricBlue)
                            Text(url.lastPathComponent)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Button("Extract Plain Text") {
                                runOCRExtractText()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.electricBlue)
                            .disabled(ocrService.isProcessing)
                            
                            Button("Generate Searchable PDF") {
                                runOCRGenerateSearchablePDF()
                            }
                            .buttonStyle(.bordered)
                            .disabled(ocrService.isProcessing)
                            
                            if let searchable = ocrSearchableOutputURL {
                                Button("Reveal Searchable PDF") {
                                    NSWorkspace.shared.selectFile(searchable.path, inFileViewerRootedAtPath: searchable.deletingLastPathComponent().path)
                                }
                            }
                        }
                        
                        if ocrService.isProcessing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(ocrService.statusMessage)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        
                        if !ocrService.recognizedText.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Recognized Text Output")
                                        .font(.system(size: 12, weight: .bold))
                                    Spacer()
                                    Button("Copy to Clipboard") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(ocrService.recognizedText, forType: .string)
                                    }
                                    .controlSize(.small)
                                }
                                
                                TextEditor(text: .constant(ocrService.recognizedText))
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(14)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - 5. PDF Splitter Canvas
    private var splitterCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FileDropZoneView(
                    title: "Select PDF to Split",
                    subtitle: "Split multi-page document into individual pages or ranges",
                    icon: "scissors",
                    allowedTypes: [.pdf]
                ) { urls in
                    splitterSourceURL = urls.first
                }
                
                if let url = splitterSourceURL {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Split Settings: \(url.lastPathComponent)")
                            .font(.system(size: 13, weight: .bold))
                        
                        Picker("Split Mode", selection: $splitMode) {
                            Text("Every Single Page").tag("each")
                            Text("Page Ranges (e.g. 1-2, 3-5)").tag("range")
                            Text("Every N Pages").tag("interval")
                        }
                        .pickerStyle(.radioGroup)
                        
                        if splitMode == "range" {
                            TextField("Enter ranges (e.g. 1-2, 3-5)", text: $splitRangesText)
                                .textFieldStyle(.roundedBorder)
                        } else if splitMode == "interval" {
                            Stepper("Every \(splitInterval) page(s)", value: $splitInterval, in: 1...50)
                        }
                        
                        Button("Execute PDF Split") {
                            executeSplitPDF()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.electricBlue)
                        
                        if !splitStatusMessage.isEmpty {
                            Text(splitStatusMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.matrixGreen)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - 6. PDF Page Extractor Canvas
    private var extractorCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FileDropZoneView(
                    title: "Select PDF to Extract Pages From",
                    subtitle: "Extract specific pages into a standalone new document",
                    icon: "arrow.up.right.and.arrow.down.left.rectangle",
                    allowedTypes: [.pdf]
                ) { urls in
                    extractorSourceURL = urls.first
                }
                
                if let url = extractorSourceURL {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Extract from: \(url.lastPathComponent)")
                            .font(.system(size: 13, weight: .bold))
                        
                        TextField("Page numbers to extract (e.g. 1, 3, 5-7)", text: $extractorPageNumbersText)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Extract Pages to New Document") {
                            executeExtractPages()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.electricBlue)
                    }
                    .padding(16)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - 7. Metadata & Privacy Inspector Canvas
    private var metadataInspectorCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FileDropZoneView(
                    title: "Select PDF for Metadata Inspection",
                    subtitle: "Inspect hidden tracking tags, creator apps, and scrub metadata safely",
                    icon: "lock.shield.fill",
                    allowedTypes: [.pdf]
                ) { urls in
                    if let first = urls.first {
                        metadataURL = first
                        metadataReport = PDFMetadataInspectorService.shared.inspect(url: first)
                    }
                }
                
                if let report = metadataReport, let url = metadataURL {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Metadata Report: \(url.lastPathComponent)")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Button("Scrub & Sanitize Copy") {
                                sanitizeMetadataCopy()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.matrixGreen)
                        }
                        
                        Divider()
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            metadataFieldView("Title", value: report.title ?? "None")
                            metadataFieldView("Author", value: report.author ?? "None")
                            metadataFieldView("Subject", value: report.subject ?? "None")
                            metadataFieldView("Creator App", value: report.creator ?? "None")
                            metadataFieldView("PDF Producer", value: report.producer ?? "None")
                            metadataFieldView("Keywords", value: report.keywords.isEmpty ? "None" : report.keywords.joined(separator: ", "))
                            metadataFieldView("Page Count", value: "\(report.pageCount)")
                            metadataFieldView("Encrypted", value: report.isEncrypted ? "Yes" : "No")
                        }
                    }
                    .padding(16)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
    }
    
    private func metadataFieldView(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - 8. Export & Print Canvas
    private var exportPrintCanvas: some View {
        VStack(spacing: 20) {
            Image(systemName: "printer.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.electricBlue)
            
            Text("Native macOS Print & Flattened Export")
                .font(.system(size: 16, weight: .bold))
            
            Text("Send documents directly to connected printers or AirPrint with full page setup and pagination control.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Button("Select PDF to Print...") {
                let openPanel = NSOpenPanel()
                openPanel.allowedContentTypes = [.pdf]
                if openPanel.runModal() == .OK, let url = openPanel.url, let doc = PDFDocument(url: url) {
                    let printInfo = NSPrintInfo.shared
                    if let printOp = doc.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true) {
                        printOp.run()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.electricBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
    
    // MARK: - Form Fields Sheet
    private var formFieldsInspectorSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Interactive AcroForm Fields")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("Done") {
                    showFormFieldsSheet = false
                }
            }
            
            if editorService.detectedFormFields.isEmpty {
                Text("No fillable interactive form fields detected in this document.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                List(editorService.detectedFormFields, id: \.self) { field in
                    Text(field)
                        .font(.system(size: 12))
                }
            }
        }
        .padding(20)
        .frame(width: 400, height: 300)
    }
    
    // MARK: - Actions & Helpers
    private func selectFilesForAssembly() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.allowedContentTypes = [
            .pdf, .png, .jpeg, .heic, .tiff, .bmp, .webP
        ]
        if openPanel.runModal() == .OK {
            assemblyService.addFiles(urls: openPanel.urls)
        }
    }
    
    private func handleAssemblyDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        self.assemblyService.addFiles(urls: [url])
                    }
                }
            }
        }
        return true
    }
    
    private func chooseOutputFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = true
        if openPanel.runModal() == .OK {
            assemblyService.outputDirectory = openPanel.url
        }
    }
    
    private func triggerAssemblyExport() {
        guard let outDir = assemblyService.outputDirectory else {
            chooseOutputFolder()
            return
        }
        let filename = assemblyService.outputFilename.hasSuffix(".pdf") ? assemblyService.outputFilename : "\(assemblyService.outputFilename).pdf"
        let destURL = outDir.appendingPathComponent(filename)
        
        // Non-destructive protection: check if file already exists
        if FileManager.default.fileExists(atPath: destURL.path) {
            pendingOverwriteURL = destURL
            showOverwriteConfirmation = true
        } else {
            let res = assemblyService.exportMergedDocument(to: destURL)
            if case .success(let url) = res {
                lastExportedURL = url
                showExportSuccessAlert = true
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: outDir.path)
            }
        }
    }
    
    private func previewAssembledPDF() {
        let doc = assemblyService.buildMergedDocument()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Preview_\(UUID().uuidString).pdf")
        doc.write(to: tempURL)
        NSWorkspace.shared.open(tempURL)
    }
    
    private func openPDFForEditing() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.pdf]
        if openPanel.runModal() == .OK, let url = openPanel.url {
            editorService.loadDocument(url: url)
        }
    }
    
    private func saveEditedDocumentAs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "Edited_Document.pdf"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            _ = editorService.saveCopy(to: url)
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }
    
    private func convertOfficeDocument() {
        guard let source = officeSourceURL else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = source.deletingPathExtension().appendingPathExtension("pdf").lastPathComponent
        if savePanel.runModal() == .OK, let dest = savePanel.url {
            _ = officeService.convertOfficeDocument(from: source, to: dest)
            officeConvertedURL = dest
        }
    }
    
    private func runOCRExtractText() {
        guard let source = ocrSourceURL else { return }
        ocrService.performOCR(url: source, languages: [ocrService.selectedLanguage])
    }
    
    private func runOCRGenerateSearchablePDF() {
        guard let source = ocrSourceURL else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "Searchable_\(source.deletingPathExtension().lastPathComponent).pdf"
        if savePanel.runModal() == .OK, let dest = savePanel.url {
            ocrService.createSearchablePDF(from: source, destinationURL: dest, languages: [ocrService.selectedLanguage]) { res in
                if case .success(let url) = res {
                    ocrSearchableOutputURL = url
                }
            }
        }
    }
    
    private func executeSplitPDF() {
        guard let source = splitterSourceURL else { return }
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.title = "Select Folder for Split Pages"
        if openPanel.runModal() == .OK, let destFolder = openPanel.url {
            let res = PDFAssemblyService.shared.splitDocument(
                sourceURL: source,
                splitMode: splitMode,
                splitInterval: splitInterval,
                splitRangesText: splitRangesText,
                destinationFolder: destFolder
            )
            splitStatusMessage = "Successfully exported \(res.count) PDF files."
            NSWorkspace.shared.open(destFolder)
        }
    }
    
    private func executeExtractPages() {
        guard let source = extractorSourceURL else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "Extracted_Pages.pdf"
        if savePanel.runModal() == .OK, let dest = savePanel.url {
            _ = PDFAssemblyService.shared.extractPages(
                sourceURL: source,
                pageRangesText: extractorPageNumbersText,
                destinationURL: dest
            )
            NSWorkspace.shared.selectFile(dest.path, inFileViewerRootedAtPath: dest.deletingLastPathComponent().path)
        }
    }
    
    private func sanitizeMetadataCopy() {
        guard let source = metadataURL else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "Sanitized_\(source.lastPathComponent)"
        if savePanel.runModal() == .OK, let dest = savePanel.url {
            _ = PDFMetadataInspectorService.shared.sanitizeMetadata(sourceURL: source, destinationURL: dest)
            NSWorkspace.shared.selectFile(dest.path, inFileViewerRootedAtPath: dest.deletingLastPathComponent().path)
        }
    }
    
    private func fileSizeString(for url: URL) -> String {
        let size = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? UInt64) ?? 0
        return String(format: "%.1f KB", Double(size) / 1024.0)
    }
}
