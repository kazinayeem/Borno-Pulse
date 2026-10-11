//
//  DuplicateFinderView.swift
//  Naem Smart Tool
//

import AppKit
import SwiftUI

public struct DuplicateFinderView: View {
    @ObservedObject var service = DuplicateFinderService.shared
    @State private var fileToDelete: URL?
    @State private var showingDeleteAlert = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duplicate File Finder")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Scan folders safely using two-tier size bucketing and SHA-256 cryptographic hash comparison to reclaim storage")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Target Folder Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scan Directory")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    HStack(spacing: 14) {
                        Button("Choose Folder to Scan...") {
                            service.selectTargetDirectory()
                        }
                        .buttonStyle(.bordered)
                        
                        if let dir = service.targetDirectory {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(AppTheme.neonCyan)
                                Text(dir.path)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        if service.isScanning {
                            Button("Cancel") {
                                service.cancel()
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(AppTheme.dangerRed)
                        } else {
                            Button {
                                service.startScan()
                            } label: {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    Text("Start Scan")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(AppTheme.electricBlue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(service.targetDirectory == nil)
                        }
                    }
                    
                    if service.isScanning {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: service.currentProgress)
                                .progressViewStyle(.linear)
                            Text(service.statusMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .smartCard()
                
                // Duplicate Results
                if !service.duplicateGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Identified Duplicates (\(service.duplicateGroups.count) groups)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            Spacer()
                            
                            let reclaimableBytes = service.duplicateGroups.reduce(UInt64(0)) { total, grp in
                                total + (UInt64(max(0, grp.files.count - 1)) * grp.fileSize)
                            }
                            Text("Reclaimable: \(ByteCountFormatter.string(fromByteCount: Int64(reclaimableBytes), countStyle: .file))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.matrixGreen)
                        }
                        
                        Divider()
                        
                        ForEach(service.duplicateGroups) { group in
                            duplicateGroupCard(group: group)
                        }
                    }
                    .smartCard()
                } else if !service.isScanning {
                    Text(service.statusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, 4)
                }
            }
            .padding(24)
        }
        .alert("Confirm File Deletion", isPresented: $showingDeleteAlert) {
            Button("Delete Permanently", role: .destructive) {
                if let url = fileToDelete {
                    _ = service.deleteDuplicateFile(url: url)
                    fileToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
        } message: {
            if let url = fileToDelete {
                Text("Are you sure you want to delete \(url.lastPathComponent)? This file will be removed from your disk.")
            } else {
                Text("Are you sure you want to delete this file?")
            }
        }
    }
    
    @ViewBuilder
    private func duplicateGroupCard(group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SHA-256: \(group.hash.prefix(12))...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Text("Size each: \(ByteCountFormatter.string(fromByteCount: Int64(group.fileSize), countStyle: .file))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.neonCyan)
            }
            
            ForEach(group.files, id: \.self) { fileURL in
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                        .foregroundStyle(AppTheme.electricBlue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileURL.lastPathComponent)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(fileURL.path)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Reveal in Finder")
                    
                    Button {
                        fileToDelete = fileURL
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(AppTheme.dangerRed)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete Duplicate")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
