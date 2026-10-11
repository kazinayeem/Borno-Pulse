//
//  ImageCompressorView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct ImageCompressorView: View {
    @ObservedObject var service = ImageCompressorService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image Compressor")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Compress JPG, PNG, and WebP images with adjustable quality and target presets")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Drag & Drop Images to Compress",
                    subtitle: "Supports JPG, JPEG, PNG, and WebP",
                    icon: "arrow.down.right.and.arrow.up.left",
                    allowedTypes: [.image]
                ) { urls in
                    service.addFiles(urls: urls)
                }
                
                // Compression Presets & Settings
                VStack(alignment: .leading, spacing: 14) {
                    Text("Compression Settings & Presets")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    HStack(spacing: 12) {
                        ForEach(ImageCompressionPreset.allCases) { preset in
                            Button {
                                service.applyPreset(preset)
                            } label: {
                                VStack(spacing: 4) {
                                    Text(preset.rawValue)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.selectableFill(service.selectedPreset == preset))
                                .foregroundStyle(service.selectedPreset == preset ? AppTheme.selectionForeground : AppTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(service.selectedPreset == preset ? AppTheme.electricBlue : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Quality Factor: \(Int(service.qualityValue * 100))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text("Estimated Total Output: ~\(Formatters.bytes(service.estimatedTotalOutputBytes))")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.warningAmber)
                        }
                        Slider(value: $service.qualityValue, in: 0.10...0.95, step: 0.05)
                            .onChange(of: service.qualityValue) { _, _ in
                                service.selectedPreset = .custom
                            }
                    }
                    
                    Text("Technical Note: JPEG uses lossy discrete cosine transform quantization, whereas PNG uses lossless Deflate filtering. Preserving original files is enabled by default.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .smartCard()
                
                // Queue
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
                                    Text("Original: \(Formatters.bytes(item.originalSizeBytes))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                                
                                Spacer()
                                
                                if let out = item.outputSizeBytes {
                                    let saved = item.originalSizeBytes > out ? (item.originalSizeBytes - out) : 0
                                    let pct = item.originalSizeBytes > 0 ? (Double(saved) / Double(item.originalSizeBytes)) * 100.0 : 0
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
                        if service.totalCompressedBytes > 0, let dir = service.outputDirectory {
                            Button("Open Output Folder") {
                                NSWorkspace.shared.open(dir)
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            service.compressAll()
                        } label: {
                            Label("Compress All Images", systemImage: "arrow.down.right.and.arrow.up.left")
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
