//
//  PDFSecurityView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct PDFSecurityView: View {
    @ObservedObject var service = PDFSecurityService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("PDF Security & Metadata")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Inspect document metadata, handle encrypted PDFs with valid credentials, and export sanitized copies")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Select or Drop PDF to Inspect",
                    subtitle: "PDF documents for metadata audit and privacy cleaning",
                    icon: "lock.shield.fill",
                    allowedTypes: [.pdf]
                ) { urls in
                    if let first = urls.first {
                        service.inspectPDF(url: first)
                    }
                }
                
                if let doc = service.document, let url = service.selectedURL {
                    // Lock status card
                    if doc.isLocked && !service.isUnlocked {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(AppTheme.dangerRed)
                                Text("Password Protected Document")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            
                            Text("This document is protected with standard PDF encryption. Enter the authorized password to inspect and manipulate it:")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            HStack(spacing: 12) {
                                SecureField("Enter document password", text: $service.passwordInput)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 280)
                                
                                Button("Unlock") {
                                    _ = service.attemptUnlock()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .smartCard()
                    }
                    
                    // Metadata Viewer Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Document Attributes")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            Spacer()
                            
                            if !service.isUnlocked {
                                Label("Locked", systemImage: "lock.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.dangerRed)
                            } else {
                                Label("Unlocked", systemImage: "lock.open.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.matrixGreen)
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            attributeRow(label: "File Name", value: url.lastPathComponent)
                            attributeRow(label: "Page Count", value: "\(service.metadata.pageCount)")
                            attributeRow(label: "Title", value: service.metadata.title ?? "None")
                            attributeRow(label: "Author", value: service.metadata.author ?? "None")
                            attributeRow(label: "Subject", value: service.metadata.subject ?? "None")
                            attributeRow(label: "Creator Application", value: service.metadata.creator ?? "None")
                            attributeRow(label: "PDF Producer", value: service.metadata.producer ?? "None")
                            if let date = service.metadata.creationDate {
                                attributeRow(label: "Creation Date", value: date.formatted(date: .abbreviated, time: .shortened))
                            }
                        }
                    }
                    .smartCard()
                    
                    // Privacy & Sanitization Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Privacy Sanitizer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Text("Export a cleaned copy of this document with title, author, creator history, and document attributes completely stripped to protect identity prior to sharing.")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Text("Notice: Re-exporting or modifying signed documents will cause existing cryptographic digital signatures to become invalid.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                        
                        Button {
                            _ = service.exportCleanMetadataCopy()
                        } label: {
                            HStack {
                                Image(systemName: "shield.slash.fill")
                                Text("Export Privacy-Sanitized PDF")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppTheme.matrixGreen)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!service.isUnlocked)
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
    
    private func attributeRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
        }
    }
}
