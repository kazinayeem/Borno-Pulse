//
//  BatchConverterView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct BatchConverterView: View {
    @ObservedObject var batch = BatchConverterService.shared
    @State private var isDropTargeted: Bool = false
    @State private var showSettingsSuccess: Bool = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Bar
                AdaptivePageHeader(
                    title: "Batch File Converter",
                    subtitle: "Unified processing queue for images, PDFs, format conversion, compression, and resizing",
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: AppTheme.electricBlue
                ) {
                    supportedFormatsBadges
                }
                
                if let notice = batch.rejectedFilesNotice {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warningAmber)
                        Text(notice)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Button {
                            batch.rejectedFilesNotice = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.warningAmber.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.warningAmber.opacity(0.3), lineWidth: 1))
                }
                
                // Main Split Area: Queue (Left) & Configuration / Actions (Right)
                HStack(alignment: .top, spacing: 16) {
                    queueSection
                        .frame(maxWidth: .infinity)
                    
                    controlsSection
                        .frame(width: 320)
                }
            }
            .padding(18)
        }
        .background(AppTheme.graphiteCanvas)
    }
    
    // MARK: - Supported Formats Badges
    private var supportedFormatsBadges: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.electricCyan)
                Text("Images: JPG • PNG • HEIC • TIFF • BMP")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.subtleFill)
            .clipShape(Capsule())
            
            HStack(spacing: 4) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.electricBlue)
                Text("PDF: Compress • Export • PDF from Images")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.subtleFill)
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Left Queue Section
    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Queue Title & Quick Actions
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(AppTheme.electricCyan)
                        .font(.system(size: 12))
                    Text("Conversion Queue (\(batch.queue.count))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        openFilePicker()
                    } label: {
                        Label("Add Files...", systemImage: "plus")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(AppTheme.accentFill)
                    
                    if batch.completedCount > 0 {
                        Button("Clear Done") {
                            batch.clearCompleted()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(batch.isProcessing)
                    }
                    
                    if !batch.queue.isEmpty {
                        Button("Clear All") {
                            batch.clearAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(batch.isProcessing)
                    }
                }
            }
            
            // Queue Content or Empty Drop Zone
            if batch.queue.isEmpty {
                emptyDropZone
            } else {
                queueListCard
            }
        }
        .padding(14)
        .smartCard()
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Empty Drop Zone
    private var emptyDropZone: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isDropTargeted ? AppTheme.electricBlue.opacity(0.2) : AppTheme.subtleFill)
                    .frame(width: 64, height: 64)
                
                Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "square.and.arrow.down.on.square")
                    .font(.system(size: 28))
                    .foregroundStyle(isDropTargeted ? AppTheme.electricCyan : AppTheme.textTertiary)
            }
            
            VStack(spacing: 4) {
                Text(isDropTargeted ? "Drop Files to Add" : "No Files in Conversion Queue")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("Drag and drop images or PDF documents here, or click to browse.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Select Files to Convert...") {
                openFilePicker()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentFill)
            .controlSize(.regular)
            
            HStack(spacing: 16) {
                Label("Batch Format Conversion", systemImage: "arrow.triangle.2.circlepath")
                Label("Lossless & Balanced Compression", systemImage: "arrow.down.right.and.arrow.up.left")
                Label("Images to PDF", systemImage: "doc.badge.plus")
            }
            .font(.system(size: 10))
            .foregroundStyle(AppTheme.textTertiary)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isDropTargeted ? AppTheme.electricBlue : AppTheme.cardBorder,
                    style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [6, 4])
                )
                .background(isDropTargeted ? AppTheme.electricBlue.opacity(0.05) : Color.clear)
        )
    }
    
    // MARK: - Queue List Card
    private var queueListCard: some View {
        VStack(spacing: 8) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(batch.queue.enumerated()), id: \.element.id) { index, item in
                        queueRow(item: item, index: index)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 320, maxHeight: 440)
            
            // Queue Footer
            HStack {
                Text("\(batch.queue.count) total item(s) • \(Formatters.bytes(UInt64(batch.totalSourceBytes)))")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
                
                Spacer()
                
                if isDropTargeted {
                    Text("Drop additional files to append")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.electricCyan)
                }
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Queue Row
    private func queueRow(item: BatchQueueItem, index: Int) -> some View {
        HStack(spacing: 10) {
            // Reorder Controls
            VStack(spacing: 2) {
                Button {
                    batch.moveItemUp(id: item.id)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(index > 0 ? AppTheme.textSecondary : AppTheme.textTertiary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(index == 0 || batch.isProcessing)
                
                Button {
                    batch.moveItemDown(id: item.id)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(index < batch.queue.count - 1 ? AppTheme.textSecondary : AppTheme.textTertiary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(index == batch.queue.count - 1 || batch.isProcessing)
            }
            .frame(width: 14)
            
            // Type Icon
            Image(systemName: item.isPDF ? "doc.fill" : "photo")
                .font(.system(size: 13))
                .foregroundStyle(item.isPDF ? AppTheme.electricBlue : AppTheme.electricCyan)
                .frame(width: 20)
            
            // File Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.sourceFilename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 6) {
                    Text(Formatters.bytes(UInt64(item.sourceSize)))
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    Text(item.operation.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(minWidth: 140, alignment: .leading)
            
            Spacer()
            
            // Target Format Picker (if queued/failed)
            if item.status == .queued || item.status == .failed {
                Picker("", selection: Binding(
                    get: { item.targetFormat },
                    set: { newFmt in
                        if let idx = batch.queue.firstIndex(where: { $0.id == item.id }) {
                            batch.queue[idx].targetFormat = newFmt
                        }
                    }
                )) {
                    ForEach(item.operation.availableTargetFormats, id: \.self) { fmt in
                        Text(fmt.uppercased()).tag(fmt)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 80)
                .controlSize(.small)
                .disabled(batch.isProcessing)
            }
            
            // Status Indicator
            HStack(spacing: 6) {
                switch item.status {
                case .queued:
                    Text("Queued")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                case .processing:
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Processing…")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.electricCyan)
                    }
                case .completed:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.successGreen)
                            .font(.system(size: 12))
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Formatters.bytes(UInt64(item.outputSize)))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.successGreen)
                            
                            if item.sizeSavingsPercentage > 0.5 {
                                Text(String(format: "-%.0f%%", item.sizeSavingsPercentage))
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.successGreen.opacity(0.8))
                            }
                        }
                    }
                case .failed:
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(AppTheme.dangerRed)
                            .font(.system(size: 12))
                        Text(item.errorMessage ?? "Failed")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.dangerRed)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 110, alignment: .trailing)
            
            // Actions
            HStack(spacing: 6) {
                if let dest = item.destinationURL, item.status == .completed {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([dest])
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.electricCyan)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }
                
                Button {
                    batch.removeItem(id: item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Remove from queue")
                .disabled(batch.isProcessing)
            }
            .frame(width: 44, alignment: .trailing)
        }
        .padding(8)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }
    
    // MARK: - Right Controls Section
    private var controlsSection: some View {
        VStack(spacing: 14) {
            // Output Destination Card
            outputDestinationCard
            
            // Conversion Settings Card
            conversionSettingsCard
            
            // Queue Summary Card
            summaryCard
            
            // Primary Action Card
            primaryActionCard
        }
    }
    
    // MARK: - Output Destination Card
    private var outputDestinationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.electricCyan)
                Text("Output Destination")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.electricCyan)
                
                Text(batch.outputFolderURL?.lastPathComponent ?? "Downloads")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button("Change…") {
                    selectDestinationFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(batch.isProcessing)
            }
            .padding(8)
            .background(AppTheme.insetBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            
            if let dest = batch.outputFolderURL {
                Button {
                    NSWorkspace.shared.open(dest)
                } label: {
                    Label("Open in Finder", systemImage: "arrow.up.forward.app")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.electricBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .smartCard()
    }
    
    // MARK: - Conversion Settings Card
    private var conversionSettingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.electricCyan)
                Text("Conversion Settings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            
            // Default Operation Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Batch Operation")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                
                Picker("", selection: $batch.defaultOperation) {
                    ForEach(BatchOperationKind.allCases) { op in
                        Text(op.rawValue).tag(op)
                    }
                }
                .pickerStyle(.menu)
                .disabled(batch.isProcessing)
            }
            
            // Format Selector for images
            if batch.defaultOperation.isImageSourceOperation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Format")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Picker("", selection: $batch.globalImageFormat) {
                        ForEach(batch.defaultOperation.availableTargetFormats, id: \.self) { fmt in
                            Text(fmt.uppercased()).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(batch.isProcessing)
                }
            }
            
            // Quality / Compression Setting (only for supported ops)
            if batch.defaultOperation.supportsQuality {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Quality")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("\(Int(batch.compressionQuality * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.electricCyan)
                    }
                    
                    Slider(value: $batch.compressionQuality, in: 0.3...1.0, step: 0.05)
                        .controlSize(.small)
                        .disabled(batch.isProcessing)
                    
                    HStack(spacing: 6) {
                        qualityPresetButton(title: "Balanced", value: 0.75)
                        qualityPresetButton(title: "High", value: 0.85)
                        qualityPresetButton(title: "Max", value: 0.95)
                    }
                }
            }
            
            // Resize Preset Setting
            if batch.defaultOperation.supportsResize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resize Preset")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Picker("", selection: $batch.resizePreset) {
                        ForEach(ResizePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(batch.isProcessing)
                }
            }
            
            // PDF Compression Setting
            if batch.defaultOperation == .compressPDF {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compression Preset")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    Picker("", selection: $batch.pdfCompressionPreset) {
                        ForEach(PDFCompressionPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(batch.isProcessing)
                }
            }
            
            // Apply to all button
            Button {
                batch.applyGlobalSettingsToQueue()
                showSettingsSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSettingsSuccess = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showSettingsSuccess ? "checkmark" : "arrow.triangle.2.circlepath")
                    Text(showSettingsSuccess ? "Applied!" : "Apply to All Queued Files")
                }
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(batch.queue.isEmpty || batch.isProcessing)
        }
        .padding(12)
        .smartCard()
    }
    
    private func qualityPresetButton(title: String, value: Double) -> some View {
        Button(title) {
            batch.compressionQuality = value
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .tint(abs(batch.compressionQuality - value) < 0.03 ? AppTheme.electricCyan : Color.secondary)
        .disabled(batch.isProcessing)
    }
    
    // MARK: - Queue Summary Card
    private var summaryCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Queue Summary")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(batch.completedCount) / \(batch.queue.count) processed")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            Divider()
                .background(AppTheme.cardBorder)
            
            HStack(spacing: 12) {
                summaryStat(title: "Total Files", value: "\(batch.queue.count)")
                summaryStat(title: "Input Size", value: Formatters.bytes(UInt64(batch.totalSourceBytes)))
                summaryStat(title: "Output Size", value: batch.totalOutputBytes > 0 ? Formatters.bytes(UInt64(batch.totalOutputBytes)) : "--")
            }
        }
        .padding(12)
        .smartCard()
    }
    
    private func summaryStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Primary Action Card
    private var primaryActionCard: some View {
        VStack(spacing: 10) {
            if batch.isProcessing {
                VStack(spacing: 6) {
                    HStack {
                        Text("Converting files…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("\(Int(batch.overallProgress * 100))%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.electricCyan)
                    }
                    
                    ProgressView(value: batch.overallProgress, total: 1.0)
                        .progressViewStyle(.linear)
                    
                    Button("Cancel") {
                        batch.cancel()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.dangerFill)
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)
                }
            } else {
                let queuedItems = batch.queue.filter { $0.status == .queued || $0.status == .failed }.count
                Button {
                    batch.startProcessing()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text(queuedItems > 0 ? "Convert All (\(queuedItems))" : "Convert All")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
                .controlSize(.regular)
                .disabled(batch.queue.isEmpty || queuedItems == 0)
                
                if batch.completedCount > 0 && batch.queue.allSatisfy({ $0.status == .completed }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.successGreen)
                        Text("All items successfully converted!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.successGreen)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .smartCard()
    }
    
    // MARK: - Helpers & File Picker
    private func openFilePicker() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Images or PDFs for Batch Conversion"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [
            .image,
            .jpeg,
            .png,
            .heic,
            .tiff,
            .bmp,
            .gif,
            .webP,
            .pdf
        ]
        
        if openPanel.runModal() == .OK {
            batch.addFiles(openPanel.urls)
        }
    }
    
    private func selectDestinationFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Destination Folder for Converted Files"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            batch.outputFolderURL = url
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                self.batch.addFiles(urls)
            }
        }
        return true
    }
}
