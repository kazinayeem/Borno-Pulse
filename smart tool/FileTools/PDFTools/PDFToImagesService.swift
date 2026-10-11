//
//  PDFToImagesService.swift
//  Naem Smart Tool
//

import AppKit
import Combine
import Foundation
import ImageIO
import PDFKit

@MainActor
public final class PDFToImagesService: ObservableObject {
    public static let shared = PDFToImagesService()
    
    @Published public var selectedPDFURL: URL?
    @Published public var pdfDocument: PDFDocument?
    @Published public var targetFormat: ImageFormat = .png
    @Published public var dpi: CGFloat = 150.0
    @Published public var exportAllPages: Bool = true
    @Published public var startPage: Int = 1
    @Published public var endPage: Int = 1
    @Published public var outputDirectory: URL?
    @Published public var isProcessing = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "No PDF loaded"
    @Published public var exportedCount = 0
    
    private var task: Task<Void, Never>?
    
    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    public func loadPDF(url: URL) {
        guard let doc = PDFDocument(url: url) else {
            statusMessage = "Unable to open PDF document."
            return
        }
        self.selectedPDFURL = url
        self.pdfDocument = doc
        self.startPage = 1
        self.endPage = doc.pageCount
        self.statusMessage = "Loaded \(url.lastPathComponent) (\(doc.pageCount) pages)"
    }
    
    public func selectOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Output Folder"
        openPanel.title = "Choose Destination for Rendered Images"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.outputDirectory = url
        }
    }
    
    public func exportImages() {
        guard !isProcessing, let doc = pdfDocument, let inURL = selectedPDFURL, let outDir = outputDirectory else { return }
        isProcessing = true
        exportedCount = 0
        currentProgress = 0.0
        statusMessage = "Exporting pages to images..."
        
        let start = exportAllPages ? 1 : max(1, startPage)
        let requestedEnd = endPage
        let shouldExportAll = exportAllPages
        let resolution = dpi
        let format = targetFormat
        
        task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self, let doc = PDFDocument(url: inURL) else { return }
            let end = shouldExportAll ? doc.pageCount : min(doc.pageCount, requestedEnd)
            let totalPages = max(1, end - start + 1)
            let baseName = inURL.deletingPathExtension().lastPathComponent
            let scale = resolution / 72.0
            var count = 0
            
            for pageIndex in (start - 1)..<end {
                if Task.isCancelled { break }
                
                guard let page = doc.page(at: pageIndex) else { continue }
                let pageNumber = pageIndex + 1
                
                await MainActor.run {
                    self.statusMessage = "Rendering page \(pageNumber)... (\(count + 1)/\(totalPages))"
                    self.currentProgress = Double(count) / Double(totalPages)
                }
                
                let bounds = page.bounds(for: .mediaBox)
                let pixelWidth = Int(bounds.width * scale)
                let pixelHeight = Int(bounds.height * scale)
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
                
                if let context = CGContext(
                    data: nil,
                    width: pixelWidth,
                    height: pixelHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                ) {
                    context.setFillColor(NSColor.white.cgColor)
                    context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
                    context.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: context)
                    
                    if let cgImage = context.makeImage() {
                        let outURL = outDir.appendingPathComponent("\(baseName)_page_\(pageNumber).\(format.fileExtension)")
                        if let destination = CGImageDestinationCreateWithURL(outURL as CFURL, format.utTypeIdentifier, 1, nil) {
                            CGImageDestinationAddImage(destination, cgImage, nil)
                            if CGImageDestinationFinalize(destination) {
                                count += 1
                            }
                        }
                    }
                }
            }
            
            await MainActor.run {
                self.isProcessing = false
                self.exportedCount = count
                self.currentProgress = 1.0
                self.statusMessage = "Exported \(count) page images successfully."
            }
        }
    }
    
    public func cancel() {
        task?.cancel()
        task = nil
        isProcessing = false
        statusMessage = "Export cancelled"
    }
}
