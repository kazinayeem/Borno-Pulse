//
//  ChecksumCalculatorView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ChecksumCalculatorView: View {
    @ObservedObject var service = ChecksumService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("File Checksum & Hash Verifier")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Compute cryptographic integrity hashes (SHA-256, MD5, SHA-1) and verify files against known checksums")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Drop Area
                FileDropZoneView(
                    title: "Drag & Drop Any File to Hash",
                    subtitle: "Supports files of any size or type",
                    icon: "number.square.fill",
                    allowedTypes: [.item]
                ) { urls in
                    if let first = urls.first {
                        service.computeChecksum(for: first)
                    }
                }
                
                if let url = service.selectedFileURL {
                    // Results Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(AppTheme.electricBlue)
                            Text(url.lastPathComponent)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(service.result.fileSize), countStyle: .file))
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Divider()
                        
                        if service.isComputing {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Calculating hashes...")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.vertical, 8)
                        } else {
                            hashRow(title: "SHA-256 (Secure)", hash: service.result.sha256, color: AppTheme.matrixGreen)
                            hashRow(title: "MD5 (Legacy)", hash: service.result.md5, color: AppTheme.electricBlue)
                            hashRow(title: "SHA-1 (Legacy)", hash: service.result.sha1, color: AppTheme.neonCyan)
                        }
                    }
                    .smartCard()
                    
                    // Verification Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Checksum Match Verification")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Text("Paste an expected hash from a software provider, release note, or download mirror to verify authentic contents:")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                        
                        HStack(spacing: 12) {
                            TextField("Paste expected SHA-256 or MD5 hash here...", text: $service.comparisonHash)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                                .onChange(of: service.comparisonHash) {
                                    service.verifyMatch()
                                }
                            
                            if !service.comparisonHash.isEmpty {
                                Button("Clear") {
                                    service.comparisonHash = ""
                                    service.verifyMatch()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        if let status = service.hashMatchStatus {
                            HStack(spacing: 8) {
                                Image(systemName: status.hasPrefix("MATCH") ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(status.hasPrefix("MATCH") ? AppTheme.matrixGreen : AppTheme.dangerRed)
                                Text(status)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(status.hasPrefix("MATCH") ? AppTheme.matrixGreen : AppTheme.dangerRed)
                            }
                            .padding(.top, 4)
                        }
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
    
    private func hashRow(title: String, hash: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                
                Spacer()
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hash, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            
            Text(hash.isEmpty ? "—" : hash)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.insetBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}
