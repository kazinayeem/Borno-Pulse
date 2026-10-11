//
//  ImagesToPDFService.swift
//  Naem Smart Tool
//

import AppKit
import Combine
import Foundation
import PDFKit

@MainActor
public final class ImagesToPDFService: ObservableObject {
    public static let shared = ImagesToPDFService()
    
    @Published public var imagesQueue: [ImageFileQueueItem] = []
    @Published public var pageSizePreset: PDFPageSizePreset = .a4
    @Published public var pageMargin: PDFPageMargin = .small
    @Published public var isLandscape: Bool = false
    @Published public var outputFilename: String = "Combined_Document.pdf"
    @Published public var outputDirectory: URL?
    @Published public var isProcessing = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    
    private var task: Task<Void, Never>?
    
    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    public func addImages(urls: [URL]) {
        for url in urls {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            var dimensions: CGSize? = nil
            if let image = NSImage(contentsOf: url) {
                dimensions = image.size
            }
            let item = ImageFileQueueItem(
                url: url,
                originalFormat: url.pathExtension.uppercased(),
                originalSizeBytes: UInt64(size),
                dimensions: dimensions
            )
            imagesQueue.append(item)
        }
        statusMessage = "Added \(imagesQueue.count) images to combine"
    }
    
    public func removeImage(id: UUID) {
        imagesQueue.removeAll { $0.id == id }
    }
    
    public func clearQueue() {
        imagesQueue.removeAll()
        statusMessage = "Queue cleared"
    }
    
    public func moveImage(from source: IndexSet, to destination: Int) {
        imagesQueue.move(fromOffsets: source, toOffset: destination)
    }
    
    public func selectOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Destination Folder"
        openPanel.title = "Choose Destination for Generated PDF"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.outputDirectory = url
        }
    }
    
    public func generatePDF() {
        guard !isProcessing, !imagesQueue.isEmpty, let outDir = outputDirectory else { return }
        isProcessing = true
        currentProgress = 0.0
        statusMessage = "Building PDF from images..."
        
        let items = imagesQueue
        let preset = pageSizePreset
        let margin = pageMargin.inset
        let landscape = isLandscape
        let fileName = outputFilename.hasSuffix(".pdf") ? outputFilename : "\(outputFilename).pdf"
        let outURL = outDir.appendingPathComponent(fileName)
        
        task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let pdfDoc = PDFDocument()
            let total = Double(items.count)
            
            for (index, item) in items.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.statusMessage = "Adding page \(index + 1) of \(items.count)..."
                    self.currentProgress = Double(index) / total
                }
                
                guard let image = NSImage(contentsOf: item.url) else { continue }
                
                var targetPageSize: CGSize
                if preset == .matchImage {
                    targetPageSize = image.size
                } else {
                    var baseSize = preset.pointSize
                    if landscape && baseSize.width < baseSize.height {
                        baseSize = CGSize(width: baseSize.height, height: baseSize.width)
                    }
                    targetPageSize = baseSize
                }
                
                let pageImage = NSImage(size: targetPageSize)
                pageImage.lockFocus()
                
                let rect = CGRect(origin: .zero, size: targetPageSize)
                NSColor.white.setFill()
                rect.fill()
                
                let contentRect = CGRect(
                    x: margin,
                    y: margin,
                    width: max(targetPageSize.width - (margin * 2), 1),
                    height: max(targetPageSize.height - (margin * 2), 1)
                )
                
                // Calculate aspect fit
                let imgSize = image.size
                let scale = min(contentRect.width / imgSize.width, contentRect.height / imgSize.height)
                let drawnW = imgSize.width * scale
                let drawnH = imgSize.height * scale
                let drawnRect = CGRect(
                    x: contentRect.midX - (drawnW / 2),
                    y: contentRect.midY - (drawnH / 2),
                    width: drawnW,
                    height: drawnH
                )
                
                image.draw(in: drawnRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                pageImage.unlockFocus()
                
                if let newPage = PDFPage(image: pageImage) {
                    newPage.setBounds(CGRect(origin: .zero, size: targetPageSize), for: .mediaBox)
                    pdfDoc.insert(newPage, at: pdfDoc.pageCount)
                }
            }
            
            let success = pdfDoc.write(to: outURL)
            
            await MainActor.run {
                self.isProcessing = false
                self.currentProgress = 1.0
                if success {
                    self.statusMessage = "Successfully generated \(fileName) (\(items.count) pages)."
                } else {
                    self.statusMessage = "Failed writing PDF file."
                }
            }
        }
    }
}
