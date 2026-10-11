//
//  FileToolsDashboardView.swift
//  Naem Smart Tool
//

import SwiftUI

public enum FileToolCategory: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case imageTools = "Image Tools"
    case pdfTools = "PDF Tools"
    case fileUtilities = "File Utilities"
    
    public var id: String { rawValue }
}

public enum SelectedFileSubTool: String, CaseIterable, Identifiable {
    // Image Tools
    case imageConverter = "Format Converter"
    case imageCompressor = "Image Compressor"
    case imageResizer = "Image Resizer"
    case imageMetadata = "Metadata Viewer"
    
    // PDF Tools
    case pdfCompressor = "PDF Compressor"
    case pdfToImages = "PDF to Images"
    case imagesToPDF = "Images to PDF"
    case pdfMergerSplitter = "Merge & Split"
    case pdfPageTools = "Page Organizer"
    case pdfSecurity = "Security & Privacy"
    
    // File Utilities
    case checksum = "Checksum (SHA-256)"
    case batchRenamer = "Batch Renamer"
    case duplicateFinder = "Duplicate Finder"
    case archiveUtility = "ZIP Utility"
    case textEncoding = "Text Inspector"
    
    public var id: String { rawValue }
    
    public var category: FileToolCategory {
        switch self {
        case .imageConverter, .imageCompressor, .imageResizer, .imageMetadata:
            return .imageTools
        case .pdfCompressor, .pdfToImages, .imagesToPDF, .pdfMergerSplitter, .pdfPageTools, .pdfSecurity:
            return .pdfTools
        case .checksum, .batchRenamer, .duplicateFinder, .archiveUtility, .textEncoding:
            return .fileUtilities
        }
    }
}

public struct FileToolsDashboardView: View {
    @State private var selectedCategory: FileToolCategory = .overview
    @State private var activeSubTool: SelectedFileSubTool? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Category Navigation Bar
            HStack(spacing: 12) {
                ForEach(FileToolCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                        if category == .overview {
                            activeSubTool = nil
                        } else if activeSubTool?.category != category {
                            activeSubTool = defaultSubTool(for: category)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            categoryIcon(for: category)
                            Text(category.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedCategory == category ? AppTheme.electricBlue.opacity(0.18) : Color.white.opacity(0.04))
                        .foregroundStyle(selectedCategory == category ? AppTheme.electricBlue : AppTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(selectedCategory == category ? AppTheme.electricBlue : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Privacy badge
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(AppTheme.matrixGreen)
                    Text("100% Offline & Private")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.matrixGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.matrixGreen.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackground)
            
            Divider()
            
            // Subtool Pills Bar (when category is selected)
            if selectedCategory != .overview {
                HStack(spacing: 8) {
                    ForEach(subTools(for: selectedCategory)) { tool in
                        Button {
                            activeSubTool = tool
                        } label: {
                            Text(tool.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(activeSubTool == tool ? AppTheme.neonCyan.opacity(0.2) : Color.white.opacity(0.04))
                                .foregroundStyle(activeSubTool == tool ? AppTheme.neonCyan : AppTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(activeSubTool == tool ? AppTheme.neonCyan : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))
                
                Divider()
            }
            
            // Content Area
            if selectedCategory == .overview || activeSubTool == nil {
                overviewCardsView
            } else {
                toolContentView(for: activeSubTool!)
            }
        }
        .background(AppTheme.background)
    }
    
    // MARK: - Overview Cards View
    private var overviewCardsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Intro banner
                VStack(alignment: .leading, spacing: 6) {
                    Text("Offline File & Document Utilities")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("High-performance, private, zero-telemetry utilities powered natively by macOS ImageIO, CoreGraphics, PDFKit, and CryptoKit.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Section 1: Image Tools
                categorySectionHeader(title: "Image Tools", icon: "photo.on.rectangle.angled", color: AppTheme.electricBlue)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    toolLaunchCard(
                        title: "Format Converter",
                        description: "Convert PNG, JPG, WebP, HEIC, TIFF, BMP with custom transparency flatten colors.",
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        color: AppTheme.electricBlue,
                        target: .imageConverter
                    )
                    toolLaunchCard(
                        title: "Image Compressor",
                        description: "Smart quality reduction, percentage savings, side-by-side preview, and batch processing.",
                        icon: "arrow.down.right.and.arrow.up.left",
                        color: AppTheme.matrixGreen,
                        target: .imageCompressor
                    )
                    toolLaunchCard(
                        title: "Image Resizer",
                        description: "Scale by pixels, percentage, or social presets with aspect ratio lock and no upscaling guard.",
                        icon: "crop",
                        color: AppTheme.neonCyan,
                        target: .imageResizer
                    )
                    toolLaunchCard(
                        title: "Metadata Viewer",
                        description: "Inspect EXIF, camera, lens, color profile, and export location-scrubbed private copies.",
                        icon: "info.circle.fill",
                        color: Color.purple,
                        target: .imageMetadata
                    )
                }
                
                // Section 2: PDF Tools
                categorySectionHeader(title: "PDF Tools", icon: "doc.text.fill", color: AppTheme.neonCyan)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    toolLaunchCard(
                        title: "PDF Compressor",
                        description: "Downsample image-heavy PDFs and optimize streams with selectable compression levels.",
                        icon: "arrow.down.circle.fill",
                        color: AppTheme.electricBlue,
                        target: .pdfCompressor
                    )
                    toolLaunchCard(
                        title: "PDF to Images",
                        description: "Render high-res PNG or JPG page images with custom DPI and page range export.",
                        icon: "photo.stack.fill",
                        color: AppTheme.matrixGreen,
                        target: .pdfToImages
                    )
                    toolLaunchCard(
                        title: "Images to PDF",
                        description: "Merge multiple photos into A4, Letter, or custom multi-page PDF documents.",
                        icon: "doc.badge.plus",
                        color: AppTheme.neonCyan,
                        target: .imagesToPDF
                    )
                    toolLaunchCard(
                        title: "PDF Merger & Splitter",
                        description: "Combine documents in custom order or split by page ranges, every page, or N intervals.",
                        icon: "arrow.triangle.merge",
                        color: Color.orange,
                        target: .pdfMergerSplitter
                    )
                    toolLaunchCard(
                        title: "Page Organizer",
                        description: "Rotate 90°, delete unwanted pages, and reorder pages without modifying source files.",
                        icon: "square.stack.3d.up.fill",
                        color: Color.teal,
                        target: .pdfPageTools
                    )
                    toolLaunchCard(
                        title: "Security & Metadata",
                        description: "Inspect PDF attributes, unlock encrypted PDFs, and export sanitized metadata copies.",
                        icon: "lock.shield.fill",
                        color: Color.indigo,
                        target: .pdfSecurity
                    )
                }
                
                // Section 3: File Utilities
                categorySectionHeader(title: "File Utilities", icon: "wrench.and.screwdriver.fill", color: AppTheme.matrixGreen)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    toolLaunchCard(
                        title: "Checksum Calculator",
                        description: "Compute SHA-256, MD5, and SHA-1 hashes and verify file integrity against expected hashes.",
                        icon: "number.square.fill",
                        color: AppTheme.matrixGreen,
                        target: .checksum
                    )
                    toolLaunchCard(
                        title: "Batch File Renamer",
                        description: "Rename hundreds of files with find & replace, sequence numbers, casing, and live collision check.",
                        icon: "pencil.and.list.clipboard",
                        color: AppTheme.electricBlue,
                        target: .batchRenamer
                    )
                    toolLaunchCard(
                        title: "Duplicate File Finder",
                        description: "Reclaim disk space with fast two-tier size bucketing and SHA-256 cryptographic match.",
                        icon: "doc.on.doc.fill",
                        color: Color.orange,
                        target: .duplicateFinder
                    )
                    toolLaunchCard(
                        title: "ZIP Archive Utility",
                        description: "Create and extract ZIP archives natively with strict path traversal security.",
                        icon: "doc.zipper",
                        color: AppTheme.neonCyan,
                        target: .archiveUtility
                    )
                    toolLaunchCard(
                        title: "Text Encoding Inspector",
                        description: "Detect UTF-8, UTF-16, ASCII, BOM headers, and Unix (LF) vs Windows (CRLF) line endings.",
                        icon: "text.alignleft",
                        color: Color.purple,
                        target: .textEncoding
                    )
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Sub Tool Renderer
    @ViewBuilder
    private func toolContentView(for tool: SelectedFileSubTool) -> some View {
        switch tool {
        case .imageConverter:
            ImageConverterView()
        case .imageCompressor:
            ImageCompressorView()
        case .imageResizer:
            ImageResizerView()
        case .imageMetadata:
            ImageMetadataView()
        case .pdfCompressor:
            PDFCompressorView()
        case .pdfToImages:
            PDFToImagesView()
        case .imagesToPDF:
            ImagesToPDFView()
        case .pdfMergerSplitter:
            PDFMergerSplitterView()
        case .pdfPageTools:
            PDFPageToolsView()
        case .pdfSecurity:
            PDFSecurityView()
        case .checksum:
            ChecksumCalculatorView()
        case .batchRenamer:
            BatchRenamerView()
        case .duplicateFinder:
            DuplicateFinderView()
        case .archiveUtility:
            ArchiveUtilityView()
        case .textEncoding:
            TextEncodingInspectorView()
        }
    }
    
    // MARK: - Helpers
    private func defaultSubTool(for category: FileToolCategory) -> SelectedFileSubTool? {
        switch category {
        case .overview: return nil
        case .imageTools: return .imageConverter
        case .pdfTools: return .pdfCompressor
        case .fileUtilities: return .checksum
        }
    }
    
    private func subTools(for category: FileToolCategory) -> [SelectedFileSubTool] {
        switch category {
        case .overview:
            return []
        case .imageTools:
            return [.imageConverter, .imageCompressor, .imageResizer, .imageMetadata]
        case .pdfTools:
            return [.pdfCompressor, .pdfToImages, .imagesToPDF, .pdfMergerSplitter, .pdfPageTools, .pdfSecurity]
        case .fileUtilities:
            return [.checksum, .batchRenamer, .duplicateFinder, .archiveUtility, .textEncoding]
        }
    }
    
    @ViewBuilder
    private func categoryIcon(for category: FileToolCategory) -> some View {
        switch category {
        case .overview:
            Image(systemName: "square.grid.2x2.fill")
        case .imageTools:
            Image(systemName: "photo.on.rectangle.angled")
        case .pdfTools:
            Image(systemName: "doc.text.fill")
        case .fileUtilities:
            Image(systemName: "wrench.and.screwdriver.fill")
        }
    }
    
    private func categorySectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.top, 4)
    }
    
    private func toolLaunchCard(title: String, description: String, icon: String, color: Color, target: SelectedFileSubTool) -> some View {
        Button {
            selectedCategory = target.category
            activeSubTool = target
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.top, 6)
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
