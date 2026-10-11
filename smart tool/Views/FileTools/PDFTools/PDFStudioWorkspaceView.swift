//
//  PDFStudioWorkspaceView.swift
//  Borno Pulse
//
//  PDF Studio shell: tool sidebar, header and routing to each tool's workspace.
//  Tool screens live in PDFEditorWorkspaceView, PDFStudioToolViews, PDFCompressorView and
//  PDFToImagesView.
//

import AppKit
import SwiftUI

public struct PDFStudioWorkspaceView: View {
    @State private var selectedTool: PDFStudioTool = .imagesToPDF
    @ObservedObject private var editorService = PDFEditorService.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            studioToolSidebar
                .frame(width: 230)
                .background(AppTheme.sidebarBackground)

            Divider()

            VStack(spacing: 0) {
                workspaceHeader
                Divider()
                workspaceCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppTheme.background)
    }

    // MARK: - Left Tool Sidebar

    private var studioToolSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
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

                        if tool == .advancedEditor, editorService.hasUnsavedChanges {
                            Circle()
                                .fill(AppTheme.warningAmber)
                                .frame(width: 6, height: 6)
                                .help("The open document has unsaved changes")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTool == tool ? AppTheme.electricBlue.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .help(tool.description)
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
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.matrixGreen)
                Text("100% Offline & Private")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.matrixGreen)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppTheme.matrixGreen.opacity(0.1))
            .clipShape(Capsule())
            .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
    }

    // MARK: - Tool Routing

    @ViewBuilder
    private var workspaceCanvas: some View {
        switch selectedTool {
        case .imagesToPDF, .mergePDFs, .mergeMixed, .pageOrganizer, .rotateReorder:
            PDFAssemblyWorkspaceView(tool: selectedTool)
                .id(selectedTool)
        case .advancedEditor:
            PDFEditorWorkspaceView()
        case .officeToPDF:
            PDFOfficeConvertView()
        case .ocrSearchable:
            PDFOCRToolView()
        case .compressor:
            PDFCompressorView()
        case .pdfToImages:
            PDFToImagesView()
        case .splitter:
            PDFSplitterToolView()
        case .extractor:
            PDFExtractorToolView()
        case .metadataInspector:
            PDFMetadataToolView()
        case .exportPrint:
            PDFExportPrintToolView()
        }
    }
}
