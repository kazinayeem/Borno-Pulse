//
//  ImageMetadataView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct ImageMetadataView: View {
    @ObservedObject var service = ImageMetadataService.shared
    @State private var exportMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image Metadata & EXIF Viewer")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Inspect embedded camera specs, color profiles, and strip sensitive GPS location metadata")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Drag & Drop Image to Inspect",
                    subtitle: "Supports JPG, PNG, HEIC, TIFF, RAW",
                    icon: "info.circle.fill",
                    allowedTypes: [.image],
                    allowsMultiple: false
                ) { urls in
                    if let first = urls.first {
                        service.inspectImage(url: first)
                    }
                }
                
                if let url = service.selectedImageURL {
                    // Preview & Overview Card
                    HStack(alignment: .top, spacing: 16) {
                        if let img = service.previewImage {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(url.lastPathComponent)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                            
                            StatRow(label: "Dimensions", value: "\(service.metadataInfo.width) × \(service.metadataInfo.height) px")
                            StatRow(label: "File Size", value: Formatters.bytes(service.metadataInfo.fileSize))
                            StatRow(label: "Format & Profile", value: "\(service.metadataInfo.format) (\(service.metadataInfo.colorProfile))")
                            StatRow(label: "Resolution", value: "\(Int(service.metadataInfo.dpi)) DPI")
                        }
                    }
                    .smartCard()
                    
                    // Location / Privacy Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Location & GPS Privacy", systemImage: "location.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(service.metadataInfo.hasLocationData ? AppTheme.warningAmber : AppTheme.successGreen)
                            Spacer()
                            StatusBadge(
                                text: service.metadataInfo.hasLocationData ? "GPS Embedded" : "No GPS Data",
                                color: service.metadataInfo.hasLocationData ? AppTheme.warningAmber : AppTheme.successGreen
                            )
                        }
                        
                        if service.metadataInfo.hasLocationData {
                            Text("This image contains embedded GPS coordinates. Sharing this file publicly may reveal precise location data.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            ForEach(Array(service.metadataInfo.gpsProperties.prefix(4)), id: \.key) { k, v in
                                StatRow(label: k, value: v)
                            }
                        }
                        
                        Button {
                            let result = service.exportPrivacyCleanCopy()
                            if case .success(let outURL) = result {
                                exportMessage = "Saved sanitized image to \(outURL.lastPathComponent)"
                            }
                        } label: {
                            Label("Export Privacy-Clean Copy (Strip Location)", systemImage: "shield.slash.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentFill)
                        .controlSize(.small)
                        
                        if let msg = exportMessage {
                            Text(msg)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.successGreen)
                        }
                    }
                    .smartCard()
                    
                    // EXIF Details
                    if !service.metadataInfo.exifProperties.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Camera & Exposure Telemetry (EXIF)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            ForEach(Array(service.metadataInfo.exifProperties.prefix(12)), id: \.key) { k, v in
                                StatRow(label: k, value: v)
                            }
                        }
                        .smartCard()
                    }
                }
            }
            .padding(20)
        }
    }
}
