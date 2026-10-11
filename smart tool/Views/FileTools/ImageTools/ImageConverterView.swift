//
//  ImageConverterView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct ImageConverterView: View {
    @ObservedObject var service = ImageFormatConverterService.shared
    @State private var pickedColor: Color = .white
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image Format Converter")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Batch convert between PNG, JPEG, WebP, HEIC, TIFF, and BMP while preserving dimensions and orientation")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Drag & Drop Images Here",
                    subtitle: "Supports PNG, JPG, WebP, HEIC, TIFF, BMP",
                    icon: "photo.on.rectangle.angled",
                    allowedTypes: [.image]
                ) { urls in
                    service.addFiles(urls: urls)
                }
                
                // Settings Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Conversion Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output Format").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                            Picker("", selection: $service.targetFormat) {
                                ForEach(ImageFormat.allCases) { fmt in
                                    Text(fmt.rawValue).tag(fmt)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        
                        if !service.targetFormat.supportsAlpha {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Transparency Background").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                                HStack {
                                    ColorPicker("", selection: $pickedColor)
                                        .labelsHidden()
                                        .onChange(of: pickedColor) { _, newColor in
                                            service.backgroundColor = NSColor(newColor)
                                        }
                                    Text("Flatten Color")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Destination Folder").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                            HStack {
                                Text(service.outputDirectory?.lastPathComponent ?? "Downloads")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Button("Change...") {
                                    service.selectOutputDirectory()
                                }
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .smartCard()
                
                // Queue List
                if !service.queue.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Queue (\(service.queue.count) files)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Button("Clear Queue") {
                                service.clearQueue()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.dangerRed)
                            .font(.system(size: 11))
                        }
                        
                        ForEach(service.queue) { item in
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundStyle(AppTheme.electricBlue)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.filename)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    HStack(spacing: 8) {
                                        Text(item.originalFormat).font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                                        if let dim = item.dimensions {
                                            Text("\(Int(dim.width)) × \(Int(dim.height)) px").font(.system(size: 10)).foregroundStyle(AppTheme.textTertiary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Text(Formatters.bytes(item.originalSizeBytes))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(AppTheme.textSecondary)
                                
                                if let outSize = item.outputSizeBytes {
                                    Text("→ \(Formatters.bytes(outSize))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppTheme.successGreen)
                                }
                                
                                StatusBadge(text: item.status.rawValue, color: statusColor(item.status))
                            }
                            .padding(8)
                            .background(AppTheme.insetBackground)
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
                        Spacer()
                        Button("Cancel") { service.cancel() }
                            .buttonStyle(.bordered)
                    } else {
                        Text(service.statusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        if service.completedCount > 0, let dir = service.outputDirectory {
                            Button("Open Output Folder") {
                                NSWorkspace.shared.open(dir)
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            service.convertAll()
                        } label: {
                            Label("Convert All Images", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentFill)
                        .disabled(service.queue.isEmpty)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }
    
    private func statusColor(_ status: FileItemStatus) -> Color {
        switch status {
        case .pending: return AppTheme.textTertiary
        case .processing: return AppTheme.electricBlue
        case .completed: return AppTheme.successGreen
        case .failed: return AppTheme.dangerRed
        }
    }
}
