//
//  PDFCompressorView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct PDFCompressorView: View {
    @ObservedObject var service = PDFCompressorService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("PDF Compressor & Optimizer")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Reduce document file size through downsampling embedded images and optimizing PDF streams")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Drag & Drop PDF Documents Here",
                    subtitle: "Supports multi-page PDF documents",
                    icon: "doc.text.fill",
                    allowedTypes: [.pdf]
                ) { urls in
                    service.addFiles(urls: urls)
                }
                
                // Settings Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Compression Presets")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    HStack(spacing: 12) {
                        ForEach(PDFCompressionPreset.allCases) { preset in
                            Button {
                                service.selectedPreset = preset
                            } label: {
                                VStack(spacing: 4) {
                                    Text(preset.rawValue)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(service.selectedPreset == preset ? AppTheme.electricBlue.opacity(0.18) : Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(service.selectedPreset == preset ? AppTheme.electricBlue : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text("Optimization Guarantee: Page structure, aspect ratios, and orientations are strictly preserved. If a PDF is primarily vector/text and contains no heavy images, further compression yields minimal size reduction.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .smartCard()
                
                // Queue
                if !service.queue.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Queue (\(service.queue.count) documents)")
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
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(AppTheme.electricBlue)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.filename)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Text("\(item.pageCount) pages • Original: \(Formatters.bytes(item.fileSize))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                                
                                Spacer()
                                
                                if let out = item.outputSizeBytes {
                                    let saved = item.fileSize > out ? (item.fileSize - out) : 0
                                    let pct = item.fileSize > 0 ? (Double(saved) / Double(item.fileSize)) * 100.0 : 0
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(Formatters.bytes(out))
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(AppTheme.successGreen)
                                        Text("-\(String(format: "%.0f", pct))%")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(AppTheme.successGreen)
                                    }
                                }
                                
                                StatusBadge(text: item.status.rawValue, color: statusColor(item.status))
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
                        Spacer()
                        Button("Cancel") { service.cancel() }
                            .buttonStyle(.bordered)
                    } else {
                        Text(service.statusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        if service.totalCompressedBytes > 0, let dir = service.outputDirectory {
                            Button("Open Output Folder") {
                                NSWorkspace.shared.open(dir)
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            service.compressAll()
                        } label: {
                            Label("Compress All PDFs", systemImage: "arrow.down.doc.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.electricBlue)
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
