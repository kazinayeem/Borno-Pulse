//
//  TextEncodingInspectorView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct TextEncodingInspectorView: View {
    @ObservedObject var service = TextEncodingInspectorService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Text File Encoding & Format Inspector")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Inspect text file character encoding, Byte Order Marks (BOM), line endings (LF/CRLF), and word metrics")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Drag & Drop Text, Source Code, or Log File",
                    subtitle: "Supports .txt, .json, .csv, .log, .md, .swift, and more",
                    icon: "text.alignleft",
                    allowedTypes: [.text, .plainText, .sourceCode]
                ) { urls in
                    if let first = urls.first {
                        service.inspectFile(url: first)
                    }
                }
                
                if let url = service.selectedFileURL {
                    // Encoding Metrics Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(AppTheme.electricBlue)
                            Text(url.lastPathComponent)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(service.fileInfo.fileSize), countStyle: .file))
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Divider()
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            metricTile(title: "Encoding", value: service.fileInfo.encodingName, color: AppTheme.matrixGreen)
                            metricTile(title: "Byte Order Mark (BOM)", value: service.fileInfo.hasBOM ? "Present" : "None", color: service.fileInfo.hasBOM ? AppTheme.neonCyan : AppTheme.textSecondary)
                            metricTile(title: "Line Endings", value: service.fileInfo.lineEndings, color: AppTheme.electricBlue)
                            metricTile(title: "Lines", value: "\(service.fileInfo.lineCount)", color: AppTheme.textPrimary)
                            metricTile(title: "Words", value: "\(service.fileInfo.wordCount)", color: AppTheme.textPrimary)
                            metricTile(title: "Characters", value: "\(service.fileInfo.characterCount)", color: AppTheme.textPrimary)
                        }
                    }
                    .smartCard()
                    
                    // Preview Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Content Preview (First 2,000 characters)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        ScrollView {
                            Text(service.fileInfo.samplePreview)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .frame(maxHeight: 240)
                        .background(Color.white.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .smartCard()
                }
                
                Text(service.statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(24)
        }
    }
    
    private func metricTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
