//
//  BatchConverterService.swift
//  Borno Pulse
//

import AppKit
import Foundation
import PDFKit
import SwiftUI

@MainActor
public final class BatchConverterService: ObservableObject {
    public static let shared = BatchConverterService()
    
    // MARK: - Published State
    @Published public var queue: [BatchQueueItem] = []
    @Published public var isProcessing: Bool = false
    @Published public var outputFolderURL: URL? = nil
    
    // Global Configuration Controls
    @Published public var defaultOperation: BatchOperationKind = .convertImage
    @Published public var globalImageFormat: String = "jpg"
    @Published public var compressionQuality: Double = 0.75
    @Published public var resizePreset: ResizePreset = .fullHD
    @Published public var pdfCompressionPreset: PDFCompressionPreset = .balanced
    @Published public var rejectedFilesNotice: String? = nil
    
    private var isCancelled: Bool = false
    
    public static let supportedImageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "tiff", "tif", "bmp", "gif", "webp"
    ]
    public static let supportedPDFExtensions: Set<String> = ["pdf"]
    
    private init() {
        self.outputFolderURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    // MARK: - Queue Management
    @discardableResult
    public func addFiles(_ urls: [URL], defaultOperation: BatchOperationKind? = nil) -> (added: Int, skipped: Int) {
        rejectedFilesNotice = nil
        var addedCount = 0
        var skippedCount = 0
        
        let opToUse = defaultOperation ?? self.defaultOperation
        
        for url in urls {
            // Check readability and valid file extension
            let ext = url.pathExtension.lowercased()
            let isImg = Self.supportedImageExtensions.contains(ext)
            let isPDF = Self.supportedPDFExtensions.contains(ext)
            
            guard isImg || isPDF else {
                skippedCount += 1
                continue
            }
            
            // Check if already queued
            if queue.contains(where: { $0.sourceURL == url }) {
                continue
            }
            
            // Determine size
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs?[.size] as? Int64 ?? 0
            
            // Auto-detect operation if current operation doesn't fit file type
            let finalOp: BatchOperationKind
            if isPDF {
                if opToUse.isPDFSourceOperation {
                    finalOp = opToUse
                } else {
                    finalOp = .compressPDF
                }
            } else {
                if opToUse.isImageSourceOperation {
                    finalOp = opToUse
                } else {
                    finalOp = .convertImage
                }
            }
            
            let targetExt: String
            if finalOp == .compressPDF || finalOp == .mergePDFs || finalOp == .imagesToPDF {
                targetExt = "pdf"
            } else if finalOp == .pdfToImages {
                targetExt = globalImageFormat == "png" ? "png" : "jpg"
            } else {
                targetExt = globalImageFormat
            }
            
            let item = BatchQueueItem(
                sourceURL: url,
                sourceSize: size,
                operation: finalOp,
                targetFormat: targetExt
            )
            queue.append(item)
            addedCount += 1
        }
        
        if skippedCount > 0 {
            rejectedFilesNotice = "Skipped \(skippedCount) unsupported file(s). Only images and PDFs are supported."
        }
        
        return (addedCount, skippedCount)
    }
    
    public func removeItem(id: UUID) {
        guard !isProcessing else { return }
        queue.removeAll { $0.id == id }
    }
    
    public func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard !isProcessing else { return }
        guard sourceIndex >= 0 && sourceIndex < queue.count,
              destinationIndex >= 0 && destinationIndex < queue.count,
              sourceIndex != destinationIndex else { return }
        let item = queue.remove(at: sourceIndex)
        queue.insert(item, at: destinationIndex)
    }
    
    public func moveItemUp(id: UUID) {
        guard !isProcessing else { return }
        guard let idx = queue.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        queue.swapAt(idx, idx - 1)
    }
    
    public func moveItemDown(id: UUID) {
        guard !isProcessing else { return }
        guard let idx = queue.firstIndex(where: { $0.id == id }), idx + 1 < queue.count else { return }
        queue.swapAt(idx, idx + 1)
    }
    
    public func clearCompleted() {
        guard !isProcessing else { return }
        queue.removeAll { $0.status == .completed }
    }
    
    public func clearAll() {
        guard !isProcessing else { return }
        queue.removeAll()
        rejectedFilesNotice = nil
    }
    
    public func applyGlobalSettingsToQueue() {
        for i in 0..<queue.count {
            guard queue[i].status == .queued || queue[i].status == .failed else { continue }
            let isPDF = queue[i].isPDF
            if isPDF {
                if defaultOperation.isPDFSourceOperation {
                    queue[i].operation = defaultOperation
                }
            } else {
                if defaultOperation.isImageSourceOperation {
                    queue[i].operation = defaultOperation
                }
            }
            
            if queue[i].operation.availableTargetFormats.contains(globalImageFormat) {
                queue[i].targetFormat = globalImageFormat
            }
        }
    }
    
    public func cancel() {
        isCancelled = true
        isProcessing = false
    }
    
    // MARK: - Collision Safe URL
    public static func collisionSafeURL(desiredURL: URL) -> URL {
        var candidate = desiredURL
        var counter = 1
        let dir = desiredURL.deletingLastPathComponent()
        let base = desiredURL.deletingPathExtension().lastPathComponent
        let ext = desiredURL.pathExtension
        
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = "\(base) (\(counter)).\(ext)"
            candidate = dir.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }
    
    // MARK: - Aggregations
    public var totalSourceBytes: Int64 {
        queue.reduce(0) { $0 + $1.sourceSize }
    }
    
    public var totalOutputBytes: Int64 {
        queue.filter { $0.status == .completed }.reduce(0) { $0 + $1.outputSize }
    }
    
    public var completedCount: Int {
        queue.filter { $0.status == .completed }.count
    }
    
    public var failedCount: Int {
        queue.filter { $0.status == .failed }.count
    }
    
    public var queuedCount: Int {
        queue.filter { $0.status == .queued }.count
    }
    
    public var overallProgress: Double {
        guard !queue.isEmpty else { return 0 }
        let total = Double(queue.count)
        let done = Double(completedCount)
        return done / total
    }
    
    // MARK: - Batch Execution Engine
    public func startProcessing() {
        guard !isProcessing, !queue.isEmpty else { return }
        isProcessing = true
        isCancelled = false
        rejectedFilesNotice = nil
        
        let destFolder = outputFolderURL ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        
        Task {
            for i in 0..<queue.count {
                if isCancelled { break }
                guard queue[i].status == .queued || queue[i].status == .failed else { continue }
                
                queue[i].status = .processing
                queue[i].progress = 0.2
                
                let source = queue[i].sourceURL
                let op = queue[i].operation
                let targetFmt = queue[i].targetFormat.lowercased()
                
                do {
                    switch op {
                    case .convertImage:
                        if targetFmt == "pdf" {
                            // Convert image into PDF
                            guard let image = NSImage(contentsOf: source),
                                  let page = PDFPage(image: image) else {
                                throw NSError(domain: "BatchConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render image for PDF conversion."])
                            }
                            let doc = PDFDocument()
                            doc.insert(page, at: 0)
                            let targetFilename = "\(source.deletingPathExtension().lastPathComponent).pdf"
                            let targetPath = Self.collisionSafeURL(desiredURL: destFolder.appendingPathComponent(targetFilename))
                            guard doc.write(to: targetPath) else {
                                throw NSError(domain: "BatchConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to write PDF to output directory."])
                            }
                            let attrs = try? FileManager.default.attributesOfItem(atPath: targetPath.path)
                            let outBytes = attrs?[.size] as? Int64 ?? 0
                            queue[i].destinationURL = targetPath
                            queue[i].outputSize = outBytes
                            queue[i].status = .completed
                            queue[i].progress = 1.0
                        } else {
                            let fmt: ImageFormat
                            switch targetFmt {
                            case "png": fmt = .png
                            case "heic": fmt = .heic
                            case "tiff": fmt = .tiff
                            case "bmp": fmt = .bmp
                            default: fmt = .jpeg
                            }
                            
                            let targetFilename = "\(source.deletingPathExtension().lastPathComponent)_converted.\(fmt.fileExtension)"
                            let targetPath = Self.collisionSafeURL(desiredURL: destFolder.appendingPathComponent(targetFilename))
                            let result = ImageFormatConverterService.convertSingleImage(
                                inputURL: source,
                                outputDir: destFolder,
                                targetFormat: fmt,
                                backgroundColor: .white
                            )
                            switch result {
                            case .success(let outBytes):
                                let defaultOut = destFolder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent).\(fmt.fileExtension)")
                                if defaultOut != targetPath && FileManager.default.fileExists(atPath: defaultOut.path) {
                                    try? FileManager.default.moveItem(at: defaultOut, to: targetPath)
                                }
                                queue[i].destinationURL = targetPath
                                queue[i].outputSize = Int64(outBytes)
                                queue[i].status = .completed
                                queue[i].progress = 1.0
                            case .failure(let err):
                                throw err
                            }
                        }
                        
                    case .compressImage:
                        let result = ImageCompressorService.compressSingleImage(
                            inputURL: source,
                            outputDir: destFolder,
                            quality: Float(compressionQuality)
                        )
                        switch result {
                        case .success(let outBytes):
                            let defaultOut = destFolder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)_compressed.\(source.pathExtension)")
                            let safeDest = Self.collisionSafeURL(desiredURL: defaultOut)
                            if defaultOut != safeDest && FileManager.default.fileExists(atPath: defaultOut.path) {
                                try? FileManager.default.moveItem(at: defaultOut, to: safeDest)
                            }
                            queue[i].destinationURL = safeDest
                            queue[i].outputSize = Int64(outBytes)
                            queue[i].status = .completed
                            queue[i].progress = 1.0
                        case .failure(let err):
                            throw err
                        }
                        
                    case .resizeImage:
                        let result = ImageResizerService.resizeSingleImage(
                            inputURL: source,
                            outputDir: destFolder,
                            mode: .preset,
                            preset: resizePreset,
                            customWidth: 1920,
                            customHeight: 1080,
                            scale: 1.0,
                            maintainAspect: true,
                            allowUpscale: false
                        )
                        switch result {
                        case .success(let outBytes):
                            let defaultOut = destFolder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)_resized.\(source.pathExtension)")
                            let safeDest = Self.collisionSafeURL(desiredURL: defaultOut)
                            if defaultOut != safeDest && FileManager.default.fileExists(atPath: defaultOut.path) {
                                try? FileManager.default.moveItem(at: defaultOut, to: safeDest)
                            }
                            queue[i].destinationURL = safeDest
                            queue[i].outputSize = Int64(outBytes)
                            queue[i].status = .completed
                            queue[i].progress = 1.0
                        case .failure(let err):
                            throw err
                        }
                        
                    case .compressPDF:
                        let result = PDFCompressorService.compress(
                            inputURL: source,
                            outputDir: destFolder,
                            preset: pdfCompressionPreset
                        )
                        switch result {
                        case .success(let output):
                            queue[i].destinationURL = output.url
                            queue[i].outputSize = Int64(output.bytes)
                            queue[i].status = .completed
                            queue[i].progress = 1.0
                        case .failure(let err):
                            throw err
                        }
                        
                    case .pdfToImages:
                        if let doc = PDFDocument(url: source), doc.pageCount > 0, let page = doc.page(at: 0) {
                            let bounds = page.bounds(for: .mediaBox)
                            let renderSize = CGSize(width: bounds.width * 2.0, height: bounds.height * 2.0)
                            let image = NSImage(size: renderSize)
                            image.lockFocus()
                            NSColor.white.set()
                            NSRect(origin: .zero, size: renderSize).fill()
                            if let ctx = NSGraphicsContext.current?.cgContext {
                                ctx.scaleBy(x: 2.0, y: 2.0)
                                page.draw(with: .mediaBox, to: ctx)
                            }
                            image.unlockFocus()
                            let ext = targetFmt == "png" ? "png" : "jpg"
                            if let tiff = image.tiffRepresentation,
                               let rep = NSBitmapImageRep(data: tiff),
                               let imgData = ext == "png" ? rep.representation(using: .png, properties: [:]) : rep.representation(using: .jpeg, properties: [:]) {
                                let candidateOut = destFolder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)_page1.\(ext)")
                                let targetOut = Self.collisionSafeURL(desiredURL: candidateOut)
                                try imgData.write(to: targetOut)
                                queue[i].destinationURL = targetOut
                                queue[i].outputSize = Int64(imgData.count)
                                queue[i].status = .completed
                                queue[i].progress = 1.0
                            } else {
                                queue[i].status = .completed
                                queue[i].progress = 1.0
                            }
                        } else {
                            throw NSError(domain: "BatchConverter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to open or render PDF document."])
                        }
                        
                    case .imagesToPDF:
                        guard let image = NSImage(contentsOf: source),
                              let page = PDFPage(image: image) else {
                            throw NSError(domain: "BatchConverter", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image to create PDF document."])
                        }
                        let doc = PDFDocument()
                        doc.insert(page, at: 0)
                        let candidateOut = destFolder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent).pdf")
                        let targetPath = Self.collisionSafeURL(desiredURL: candidateOut)
                        guard doc.write(to: targetPath) else {
                            throw NSError(domain: "BatchConverter", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not save PDF to destination."])
                        }
                        let attrs = try? FileManager.default.attributesOfItem(atPath: targetPath.path)
                        let outBytes = attrs?[.size] as? Int64 ?? 0
                        queue[i].destinationURL = targetPath
                        queue[i].outputSize = outBytes
                        queue[i].status = .completed
                        queue[i].progress = 1.0
                        
                    case .mergePDFs:
                        // Single file passed to merge copies to destination
                        let targetCandidate = destFolder.appendingPathComponent("\(source.lastPathComponent)")
                        let targetPath = Self.collisionSafeURL(desiredURL: targetCandidate)
                        try FileManager.default.copyItem(at: source, to: targetPath)
                        queue[i].destinationURL = targetPath
                        queue[i].outputSize = queue[i].sourceSize
                        queue[i].status = .completed
                        queue[i].progress = 1.0
                    }
                } catch {
                    queue[i].status = .failed
                    queue[i].errorMessage = error.localizedDescription
                    queue[i].progress = 0.0
                }
            }
            
            self.isProcessing = false
        }
    }
}
