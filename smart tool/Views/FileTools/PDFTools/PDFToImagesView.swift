//
//  PDFToImagesView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct PDFToImagesView: View {
    @ObservedObject var service = PDFToImagesService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("PDF to Images Converter")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Render PDF pages into high-resolution PNG or JPG images with configurable DPI and page ranges")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Drag & Drop PDF to Convert",
                    subtitle: "Supports any multi-page PDF document",
                    icon: "doc.richtext.fill",
                    allowedTypes: [.pdf],
                    allowsMultiple: false
                ) { urls in
                    if let first = urls.first {
                        service.loadPDF(url: first)
                    }
                }
                
                if let doc = service.pdfDocument, let inURL = service.selectedPDFURL {
                    // Loaded PDF Overview Card
                    HStack(spacing: 16) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.electricBlue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(inURL.lastPathComponent)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                            Text("Total Pages: \(doc.pageCount)")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .smartCard()
                    
                    // Render Settings Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Rendering & Resolution Settings")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Output Format").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                                    Picker("", selection: $service.targetFormat) {
                                        Text("PNG (Lossless)").tag(ImageFormat.png)
                                        Text("JPG (Compressed)").tag(ImageFormat.jpeg)
                                    }
                                    .labelsHidden()
                                    .frame(width: 160)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Resolution (DPI)").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                                    Picker("", selection: $service.dpi) {
                                        Text("72 DPI (Web Screen)").tag(CGFloat(72.0))
                                        Text("150 DPI (Balanced)").tag(CGFloat(150.0))
                                        Text("300 DPI (High Print)").tag(CGFloat(300.0))
                                    }
                                    .labelsHidden()
                                    .frame(width: 170)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Output Format").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                                    Picker("", selection: $service.targetFormat) {
                                        Text("PNG (Lossless)").tag(ImageFormat.png)
                                        Text("JPG (Compressed)").tag(ImageFormat.jpeg)
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Resolution (DPI)").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                                    Picker("", selection: $service.dpi) {
                                        Text("72 DPI (Web Screen)").tag(CGFloat(72.0))
                                        Text("150 DPI (Balanced)").tag(CGFloat(150.0))
                                        Text("300 DPI (High Print)").tag(CGFloat(300.0))
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        
                        Divider().opacity(0.15)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Export All Pages (\(doc.pageCount) pages)", isOn: $service.exportAllPages)
                                .font(.system(size: 12))
                            
                            if !service.exportAllPages {
                                HStack(spacing: 12) {
                                    Text("From Page:").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                                    TextField("Start", value: $service.startPage, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                    Text("To Page:").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                                    TextField("End", value: $service.endPage, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                }
                            }
                        }
                    }
                    .smartCard()
                    
                    // Action Toolbar
                    HStack {
                        if service.isProcessing {
                            ProgressView(value: service.currentProgress)
                                .frame(width: 140)
                            Text(service.statusMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Button("Cancel") { service.cancel() }
                                .buttonStyle(.bordered)
                        } else {
                            Text(service.statusMessage)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            if service.exportedCount > 0, let dir = service.outputDirectory {
                                Button("Open Output Folder") {
                                    NSWorkspace.shared.open(dir)
                                }
                                .buttonStyle(.bordered)
                            }
                            Button {
                                service.exportImages()
                            } label: {
                                Label("Export Pages to Images", systemImage: "photo.stack.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.electricBlue)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
    }
}
