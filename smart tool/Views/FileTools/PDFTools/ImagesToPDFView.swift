//
//  ImagesToPDFView.swift
//  Naem Smart Tool
//

import AppKit
import SwiftUI

public struct ImagesToPDFView: View {
    @ObservedObject var service = ImagesToPDFService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Images to PDF Creator")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Combine multiple images into a clean multi-page PDF with custom margins, paper sizing, and orientation")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Drag & Drop Images to Combine",
                    subtitle: "Supports PNG, JPG, WebP, HEIC, TIFF",
                    icon: "doc.badge.plus",
                    allowedTypes: [.image]
                ) { urls in
                    service.addImages(urls: urls)
                }
                
                // Document Layout Settings
                VStack(alignment: .leading, spacing: 14) {
                    Text("Document Layout & Paper Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Page Size").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                            Picker("", selection: $service.pageSizePreset) {
                                ForEach(PDFPageSizePreset.allCases) { preset in
                                    Text(preset.rawValue).tag(preset)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Page Margins").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                            Picker("", selection: $service.pageMargin) {
                                ForEach(PDFPageMargin.allCases) { margin in
                                    Text(margin.rawValue).tag(margin)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                        }
                        
                        Toggle("Landscape", isOn: $service.isLandscape)
                            .padding(.top, 14)
                    }
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output Filename").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                            TextField("Filename", text: $service.outputFilename)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 240)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Destination Folder").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                            HStack {
                                Text(service.outputDirectory?.lastPathComponent ?? "Downloads")
                                    .font(.system(size: 12, weight: .medium))
                                Button("Change...") {
                                    service.selectOutputDirectory()
                                }
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .smartCard()
                
                // Image Queue
                if !service.imagesQueue.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Page Sequence (\(service.imagesQueue.count) images)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Button("Clear All") {
                                service.clearQueue()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.dangerRed)
                            .font(.system(size: 11))
                        }
                        
                        ForEach(Array(service.imagesQueue.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.electricBlue)
                                    .frame(width: 20)
                                
                                Image(systemName: "photo")
                                    .foregroundStyle(AppTheme.textSecondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.filename)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Text(Formatters.bytes(item.originalSizeBytes))
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    service.removeImage(id: item.id)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    .smartCard()
                }
                
                // Action Toolbar
                HStack {
                    if service.isProcessing {
                        ProgressView(value: service.currentProgress)
                            .frame(width: 140)
                        Text(service.statusMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Text(service.statusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        if let dir = service.outputDirectory {
                            Button("Open Output Folder") {
                                NSWorkspace.shared.open(dir)
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            service.generatePDF()
                        } label: {
                            Label("Generate PDF Document", systemImage: "doc.text.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.electricBlue)
                        .disabled(service.imagesQueue.isEmpty)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }
}
