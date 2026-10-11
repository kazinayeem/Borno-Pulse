//
//  ArchiveUtilityView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ArchiveUtilityView: View {
    @ObservedObject var service = ArchiveUtilityService.shared
    @State private var activeTab: ArchiveTab = .create
    
    enum ArchiveTab: String, CaseIterable, Identifiable {
        case create = "Create ZIP Archive"
        case extract = "Extract ZIP Archive"
        var id: String { rawValue }
    }
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("ZIP Archive Utility")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Fast, private archive compression and safe extraction with strict path-traversal safeguards")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Picker("Mode", selection: $activeTab) {
                    ForEach(ArchiveTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                
                if activeTab == .create {
                    createZipSection
                } else {
                    extractZipSection
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Create Section
    private var createZipSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileDropZoneView(
                title: "Drag & Drop Files or Folders to Archive",
                subtitle: "Add multiple items to bundle into a ZIP archive",
                icon: "doc.zipper",
                allowedTypes: [.item]
            ) { urls in
                service.selectedURLs.append(contentsOf: urls)
                service.statusMessage = "Added \(urls.count) item(s) for archiving"
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Archive Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                
                HStack(spacing: 12) {
                    Text("Archive Filename:")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Archive.zip", text: $service.archiveOutputFilename)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                    
                    Spacer()
                }
            }
            .smartCard()
            
            if !service.selectedURLs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Items to Archive (\(service.selectedURLs.count))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Button("Clear Items") {
                            service.selectedURLs.removeAll()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.dangerRed)
                        .font(.system(size: 11))
                    }
                    
                    ForEach(service.selectedURLs, id: \.self) { url in
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                                .foregroundStyle(AppTheme.electricBlue)
                            Text(url.lastPathComponent)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(url.path)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textTertiary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                .smartCard()
                
                HStack(spacing: 14) {
                    Button {
                        service.createZipArchive()
                    } label: {
                        HStack {
                            Image(systemName: "archivebox.fill")
                            Text("Create ZIP Archive")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppTheme.electricBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(service.isProcessing)
                    
                    Spacer()
                    
                    Text(service.statusMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Extract Section
    private var extractZipSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileDropZoneView(
                title: "Drag & Drop ZIP Archive to Extract",
                subtitle: "Safe extraction with path traversal protection",
                icon: "arrow.down.doc.fill",
                allowedTypes: [.zip]
            ) { urls in
                if let zip = urls.first {
                    service.extractZipArchive(zipURL: zip)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Extraction Destination")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                
                HStack(spacing: 12) {
                    Button("Select Destination...") {
                        selectDestinationFolder()
                    }
                    .buttonStyle(.bordered)
                    
                    if let dest = service.extractionDestination {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(AppTheme.neonCyan)
                            Text(dest.path)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if let dest = service.extractionDestination {
                        Button("Open Folder") {
                            NSWorkspace.shared.open(dest)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Text("Security Guarantee: Archives are verified against zip-slip path traversal attacks and extracted strictly inside an isolated folder under the chosen destination.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .smartCard()
            
            Text(service.statusMessage)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
    
    private func selectDestinationFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Choose Destination"
        if openPanel.runModal() == .OK, let url = openPanel.url {
            service.extractionDestination = url
        }
    }
}
