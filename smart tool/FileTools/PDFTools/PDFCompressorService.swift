//
//  PDFCompressorService.swift
//  Borno Pulse
//

import AppKit
import Combine
import Foundation
import PDFKit

@MainActor
public final class PDFCompressorService: ObservableObject {
    public static let shared = PDFCompressorService()
    
    @Published public var queue: [PDFFileQueueItem] = []
    @Published public var selectedPreset: PDFCompressionPreset = .balanced
    @Published public var outputDirectory: URL?
    @Published public var isProcessing = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    @Published public var totalOriginalBytes: UInt64 = 0
    @Published public var totalCompressedBytes: UInt64 = 0
    
    private var task: Task<Void, Never>?
    
    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    public func addFiles(urls: [URL]) {
        for url in urls {
            guard let doc = PDFDocument(url: url) else { continue }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let item = PDFFileQueueItem(
                url: url,
                pageCount: doc.pageCount,
                fileSize: UInt64(size),
                isEncrypted: doc.isLocked
            )
            queue.append(item)
            totalOriginalBytes += UInt64(size)
        }
        statusMessage = "Added \(queue.count) PDF document(s)"
    }
    
    public func clearQueue() {
        queue.removeAll()
        totalOriginalBytes = 0
        totalCompressedBytes = 0
        currentProgress = 0.0
        statusMessage = "Queue cleared"
    }
    
    public func selectOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Destination"
        openPanel.title = "Choose Destination for Compressed PDFs"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.outputDirectory = url
        }
    }
    
    public func compressAll() {
        guard !isProcessing, !queue.isEmpty, let outDir = outputDirectory else { return }
        isProcessing = true
        totalCompressedBytes = 0
        currentProgress = 0.0
        statusMessage = "Compressing PDF documents..."
        
        let items = queue
        let preset = selectedPreset
        
        task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let total = Double(items.count)
            var accumSize: UInt64 = 0
            
            for (index, item) in items.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.statusMessage = "Optimizing \(item.filename)... (\(index + 1)/\(items.count))"
                    self.currentProgress = Double(index) / total
                    if let qIdx = self.queue.firstIndex(where: { $0.id == item.id }) {
                        self.queue[qIdx].status = .processing
                    }
                }
                
                let result = PDFCompressorService.compressSinglePDF(inputURL: item.url, outputDir: outDir, preset: preset)
                
                await MainActor.run {
                    if let qIdx = self.queue.firstIndex(where: { $0.id == item.id }) {
                        if case .success(let outSize) = result {
                            self.queue[qIdx].status = .completed
                            self.queue[qIdx].outputSizeBytes = outSize
                            accumSize += outSize
                            self.totalCompressedBytes = accumSize
                        } else if case .failure(let err) = result {
                            self.queue[qIdx].status = .failed
                            self.queue[qIdx].errorMessage = err.localizedDescription
                        }
                    }
                }
            }
            
            await MainActor.run {
                self.isProcessing = false
                self.currentProgress = 1.0
                let saved = self.totalOriginalBytes > self.totalCompressedBytes ? (self.totalOriginalBytes - self.totalCompressedBytes) : 0
                let pct = self.totalOriginalBytes > 0 ? (Double(saved) / Double(self.totalOriginalBytes)) * 100.0 : 0
                self.statusMessage = "Optimization complete! Reclaimed \(Formatters.bytes(saved)) (\(String(format: "%.1f", pct))% reduction)."
            }
        }
    }
    
    public func cancel() {
        task?.cancel()
        task = nil
        isProcessing = false
        statusMessage = "Compression cancelled"
    }
    
    public nonisolated static func compressSinglePDF(
        inputURL: URL,
        outputDir: URL,
        preset: PDFCompressionPreset
    ) -> Result<UInt64, Error> {
        guard let sourceDoc = PDFDocument(url: inputURL) else {
            return .failure(NSError(domain: "PDFCompressor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed opening PDF document."]))
        }
        
        let outputDoc = PDFDocument()
        let scale = preset.dpi / 72.0
        
        for i in 0..<sourceDoc.pageCount {
            guard let page = sourceDoc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            
            // Render page to optimized bitmap image
            let renderSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let image = NSImage(size: renderSize)
            image.lockFocus()
            
            guard let context = NSGraphicsContext.current?.cgContext else {
                image.unlockFocus()
                continue
            }
            
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: renderSize))
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)
            image.unlockFocus()
            
            if let newPage = PDFPage(image: image) {
                newPage.setBounds(bounds, for: .mediaBox)
                outputDoc.insert(newPage, at: outputDoc.pageCount)
            }
        }
        
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let outputURL = outputDir.appendingPathComponent("\(baseName)_compressed.pdf")
        
        guard outputDoc.write(to: outputURL) else {
            return .failure(NSError(domain: "PDFCompressor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed writing optimized PDF."]))
        }
        
        let outSize = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return .success(UInt64(outSize))
    }
}
