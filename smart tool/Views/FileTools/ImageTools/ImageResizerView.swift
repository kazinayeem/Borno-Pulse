//
//  ImageResizerView.swift
//  Naem Smart Tool
//

import AppKit
import SwiftUI

public struct ImageResizerView: View {
    @ObservedObject var service = ImageResizerService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image Resizer")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Batch resize images by exact pixels, percentage scale, or standard social & web presets")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Drag & Drop Images to Resize",
                    subtitle: "Supports PNG, JPG, WebP, HEIC, TIFF, BMP",
                    icon: "arrow.up.left.and.arrow.down.right",
                    allowedTypes: [.image]
                ) { urls in
                    service.addFiles(urls: urls)
                }
                
                // Settings Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Resizing Mode & Dimensions")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Picker("Mode", selection: $service.resizeMode) {
                        ForEach(ResizeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    switch service.resizeMode {
                    case .preset:
                        Picker("Select Preset", selection: $service.selectedPreset) {
                            ForEach(ResizePreset.allCases) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        
                    case .pixels:
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Width (px)").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                                TextField("Width", value: $service.customWidth, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Height (px)").font(.system(size: 11)).foregroundStyle(AppTheme.textTertiary)
                                TextField("Height", value: $service.customHeight, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                        }
                        
                    case .percentage:
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Scale Percentage: \(Int(service.scalePercentage))%")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                            }
                            Slider(value: $service.scalePercentage, in: 10...200, step: 5)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        Toggle("Maintain Aspect Ratio", isOn: $service.maintainAspectRatio)
                        Toggle("Allow Upscaling", isOn: $service.allowUpscaling)
                    }
                    .font(.system(size: 12))
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
                                    if let dim = item.dimensions {
                                        Text("Current: \(Int(dim.width)) × \(Int(dim.height)) px")
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppTheme.textTertiary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(Formatters.bytes(item.originalSizeBytes))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(AppTheme.textSecondary)
                                
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
                        if let dir = service.outputDirectory {
                            Button("Open Output Folder") {
                                NSWorkspace.shared.open(dir)
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            service.resizeAll()
                        } label: {
                            Label("Resize All Images", systemImage: "arrow.up.left.and.arrow.down.right")
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
