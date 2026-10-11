//
//  BatchConverterView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct BatchConverterView: View {
    @ObservedObject var batch = BatchConverterService.shared
    @State private var globalOperation: BatchOperationKind = .convertImage
    @State private var globalFormat: String = "jpg"
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header Bar
            AdaptivePageHeader(
                title: "Batch File Converter",
                subtitle: "Unified processing queue for images, PDFs, compression, and resizing",
                icon: "arrow.triangle.2.circlepath",
                iconColor: AppTheme.electricBlue
            ) {
                // Destination Folder Button
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.electricCyan)
                    Text(batch.outputFolderURL?.lastPathComponent ?? "Downloads")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Button("Change...") {
                        selectDestinationFolder()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.electricBlue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Batch Operation Toolbar & Add Files
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    addFilesButton
                    operationPicker
                    applyToAllButton
                    Spacer()
                    batchProcessButton
                    clearDoneButton
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        addFilesButton
                        operationPicker
                        applyToAllButton
                    }
                    
                    HStack(spacing: 10) {
                        batchProcessButton
                        clearDoneButton
                        Spacer()
                    }
                }
            }
            
            // Queue Table / Drop Zone
            if batch.queue.isEmpty {
                emptyDropZone
            } else {
                queueTableView
            }
        }
        .padding(18)
        .background(AppTheme.graphiteCanvas)
    }
    
    // MARK: - Queue Table View
    private var queueTableView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Queue Items (\(batch.queue.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                
                Spacer()
                
                let completed = batch.queue.filter { $0.status == .completed }.count
                Text("\(completed) of \(batch.queue.count) processed")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach($batch.queue) { $item in
                        queueRowView(item: $item)
                    }
                }
            }
            .frame(minHeight: 280)
        }
        .padding(14)
        .smartCard()
    }
    
    // MARK: - Queue Row
    private func queueRowView(item: Binding<BatchQueueItem>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.wrappedValue.operation.icon)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.electricCyan)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.wrappedValue.sourceFilename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(Formatters.bytes(UInt64(item.wrappedValue.sourceSize)))
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    Text("→ \(item.wrappedValue.operation.rawValue)")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(width: 220, alignment: .leading)
            
            // Format Selector
            Picker("", selection: item.targetFormat) {
                Text("JPG").tag("jpg")
                Text("PNG").tag("png")
                Text("WebP").tag("webp")
                Text("PDF").tag("pdf")
            }
            .pickerStyle(.menu)
            .frame(width: 75)
            .disabled(item.wrappedValue.status == .processing || item.wrappedValue.status == .completed)
            
            Spacer()
            
            // Status & Progress
            HStack(spacing: 8) {
                switch item.wrappedValue.status {
                case .queued:
                    Text("Queued")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                case .processing:
                    ProgressView()
                        .controlSize(.small)
                case .completed:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.successGreen)
                        if item.wrappedValue.outputSize > 0 {
                            Text(Formatters.bytes(UInt64(item.wrappedValue.outputSize)))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.successGreen)
                        }
                    }
                case .failed:
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(AppTheme.dangerRed)
                        Text(item.wrappedValue.errorMessage ?? "Failed")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.dangerRed)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 140, alignment: .trailing)
            
            // Actions
            HStack(spacing: 6) {
                if let dest = item.wrappedValue.destinationURL, item.wrappedValue.status == .completed {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([dest])
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.electricCyan)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal converted file in Finder")
                }
                
                Button {
                    batch.removeItem(id: item.wrappedValue.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Remove from queue")
                .disabled(item.wrappedValue.status == .processing)
            }
        }
        .padding(8)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }
    
    // MARK: - Empty Drop Zone
    private var emptyDropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 34))
                .foregroundStyle(AppTheme.textTertiary)
            
            Text("No Files in Conversion Queue")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            
            Text("Add images or PDF documents to convert formats, compress file size, or resize in a single unified batch queue.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            
            Button("Select Files to Convert...") {
                openFilePicker()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.electricBlue)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .smartCard()
    }
    
    // MARK: - Actions
    private func openFilePicker() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Files for Batch Conversion"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK {
            batch.addFiles(openPanel.urls, defaultOperation: globalOperation)
        }
    }
    
    private func selectDestinationFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Output Destination Folder"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            batch.outputFolderURL = url
        }
    }
    
    // MARK: - Toolbar Subviews
    private var addFilesButton: some View {
        Button {
            openFilePicker()
        } label: {
            Label("Add Files...", systemImage: "plus.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.electricBlue)
    }
    
    private var operationPicker: some View {
        Picker("Operation", selection: $globalOperation) {
            ForEach(BatchOperationKind.allCases) { op in
                Text(op.rawValue).tag(op)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 190)
    }
    
    private var applyToAllButton: some View {
        Button("Apply to All") {
            for i in 0..<batch.queue.count {
                batch.queue[i].operation = globalOperation
            }
        }
        .buttonStyle(.bordered)
        .disabled(batch.queue.isEmpty)
    }
    
    @ViewBuilder
    private var batchProcessButton: some View {
        if batch.isProcessing {
            Button("Cancel") {
                batch.cancel()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.dangerRed)
        } else {
            Button("Start Batch (\(batch.queue.filter { $0.status == .queued }.count))") {
                batch.startProcessing()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.matrixGreen)
            .disabled(batch.queue.isEmpty)
        }
    }
    
    private var clearDoneButton: some View {
        Button("Clear Done") {
            batch.clearCompleted()
        }
        .buttonStyle(.bordered)
        .disabled(batch.queue.isEmpty)
    }
}
