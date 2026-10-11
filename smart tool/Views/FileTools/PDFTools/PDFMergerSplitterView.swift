//
//  PDFMergerSplitterView.swift
//  Naem Smart Tool
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct PDFMergerSplitterView: View {
    @ObservedObject var service = PDFMergerSplitterService.shared
    @State private var activeTab: MergerSplitterTab = .merge
    
    enum MergerSplitterTab: String, CaseIterable, Identifiable {
        case merge = "PDF Merger"
        case split = "PDF Splitter"
        var id: String { rawValue }
    }
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("PDF Merger & Splitter")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Combine multiple PDF documents or break apart documents by page ranges and intervals")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Tab Picker
                Picker("Mode", selection: $activeTab) {
                    ForEach(MergerSplitterTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                
                if activeTab == .merge {
                    mergeSection
                } else {
                    splitSection
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Merge Section
    private var mergeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileDropZoneView(
                title: "Drag & Drop PDFs to Merge",
                subtitle: "Select 2 or more PDF documents to concatenate in order",
                icon: "doc.on.doc.fill",
                allowedTypes: [.pdf]
            ) { urls in
                service.addMergeFiles(urls: urls)
            }
            
            // Output settings
            VStack(alignment: .leading, spacing: 14) {
                Text("Merge Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                
                HStack(spacing: 12) {
                    Text("Output Filename:")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Merged_Document.pdf", text: $service.mergedFilename)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                    
                    Spacer()
                    
                    Button("Select Output Folder") {
                        selectOutputFolder()
                    }
                    .buttonStyle(.bordered)
                    
                    if let dir = service.outputDirectory {
                        Text(dir.lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
            .smartCard()
            
            // Queue
            if !service.mergeQueue.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Merge Queue (\(service.mergeQueue.count) files)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Button("Clear Queue") {
                            service.clearMergeQueue()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.dangerRed)
                        .font(.system(size: 11))
                    }
                    
                    ForEach(Array(service.mergeQueue.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Text("\(index + 1).")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.textTertiary)
                                .frame(width: 20)
                            
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(AppTheme.electricBlue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.filename)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)
                                Text("\(item.pageCount) pages • \(ByteCountFormatter.string(fromByteCount: Int64(item.fileSize), countStyle: .file))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Button {
                                    if index > 0 {
                                        service.mergeQueue.swapAt(index, index - 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.up")
                                }
                                .disabled(index == 0)
                                
                                Button {
                                    if index < service.mergeQueue.count - 1 {
                                        service.mergeQueue.swapAt(index, index + 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.down")
                                }
                                .disabled(index == service.mergeQueue.count - 1)
                                
                                Button {
                                    service.mergeQueue.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(AppTheme.dangerRed)
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .smartCard()
            }
            
            // Actions
            HStack(spacing: 16) {
                Button {
                    service.executeMerge()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.merge")
                        Text("Merge PDFs")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.electricBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(service.isProcessing || service.mergeQueue.count < 2)
                
                if let dir = service.outputDirectory {
                    Button("Open Destination") {
                        NSWorkspace.shared.open(dir)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Text(service.statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            if service.isProcessing {
                ProgressView(value: service.currentProgress)
                    .progressViewStyle(.linear)
            }
        }
    }
    
    // MARK: - Split Section
    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileDropZoneView(
                title: "Select or Drop PDF to Split",
                subtitle: "Single PDF document",
                icon: "scissors",
                allowedTypes: [.pdf]
            ) { urls in
                if let first = urls.first {
                    service.loadSplitDocument(url: first)
                }
            }
            
            if let doc = service.splitSourceDoc, let url = service.splitSourceURL {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(AppTheme.neonCyan)
                        Text(url.lastPathComponent)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("\(doc.pageCount) Pages")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.neonCyan)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Split Mode")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Picker("Split Mode", selection: $service.splitMode) {
                            ForEach(PDFSplitMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        
                        if service.splitMode == .pageRange {
                            HStack(spacing: 12) {
                                Text("From Page:")
                                    .font(.system(size: 12))
                                Stepper("\(service.splitRangeStart)", value: $service.splitRangeStart, in: 1...doc.pageCount)
                                
                                Text("To Page:")
                                    .font(.system(size: 12))
                                Stepper("\(service.splitRangeEnd)", value: $service.splitRangeEnd, in: service.splitRangeStart...doc.pageCount)
                            }
                            .padding(.top, 4)
                        } else if service.splitMode == .everyNPages {
                            HStack(spacing: 12) {
                                Text("Split every:")
                                    .font(.system(size: 12))
                                Stepper("\(service.splitEveryN) page(s)", value: $service.splitEveryN, in: 1...doc.pageCount)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .smartCard()
                
                // Actions
                HStack(spacing: 16) {
                    Button {
                        service.executeSplit()
                    } label: {
                        HStack {
                            Image(systemName: "scissors")
                            Text("Execute Split")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppTheme.neonCyan)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(service.isProcessing)
                    
                    if let dir = service.outputDirectory {
                        Button("Open Destination") {
                            NSWorkspace.shared.open(dir)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Text(service.statusMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                if service.isProcessing {
                    ProgressView(value: service.currentProgress)
                        .progressViewStyle(.linear)
                }
            }
        }
    }
    
    private func selectOutputFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Folder"
        if openPanel.runModal() == .OK, let url = openPanel.url {
            service.outputDirectory = url
        }
    }
}
