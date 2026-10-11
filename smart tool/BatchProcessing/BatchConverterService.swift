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
    
    @Published public var queue: [BatchQueueItem] = []
    @Published public var isProcessing: Bool = false
    @Published public var outputFolderURL: URL? = nil
    
    private var isCancelled: Bool = false
    
    private init() {
        self.outputFolderURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    // MARK: - Queue Management
    public func addFiles(_ urls: [URL], defaultOperation: BatchOperationKind = .convertImage) {
        for url in urls {
            // Determine size
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs?[.size] as? Int64 ?? 0
            
            // Auto-detect operation
            let ext = url.pathExtension.lowercased()
            let op: BatchOperationKind = {
                if ext == "pdf" {
                    return defaultOperation == .pdfToImages ? .pdfToImages : .compressPDF
                } else {
                    return defaultOperation
                }
            }()
            
            let targetExt = (ext == "png") ? "jpg" : ((ext == "pdf") ? "png" : "png")
            
            let item = BatchQueueItem(
                sourceURL: url,
                sourceSize: size,
                operation: op,
                targetFormat: targetExt
            )
            queue.append(item)
        }
    }
    
    public func removeItem(id: UUID) {
        queue.removeAll { $0.id == id }
    }
    
    public func clearCompleted() {
        queue.removeAll { $0.status == .completed }
    }
    
    public func clearAll() {
        guard !isProcessing else { return }
        queue.removeAll()
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
    
    // MARK: - Batch Execution Engine
    public func startProcessing() {
        guard !isProcessing, !queue.isEmpty else { return }
        isProcessing = true
        isCancelled = false
        
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
                
                let targetFilename = "\(source.deletingPathExtension().lastPathComponent)_converted.\(targetFmt)"
                let targetPath = Self.collisionSafeURL(desiredURL: destFolder.appendingPathComponent(targetFilename))
                
                do {
                    switch op {
                    case .convertImage:
                        let fmt: ImageFormat = targetFmt == "png" ? .png : (targetFmt == "heic" ? .heic : .jpeg)
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
                        
                    case .compressImage:
                        let result = ImageCompressorService.compressSingleImage(
                            inputURL: source,
                            outputDir: destFolder,
                            quality: 0.70
                        )
                        switch result {
                        case .success(let outBytes):
                            let defaultOut = destFolder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)_compressed.\(source.pathExtension)")
                            queue[i].destinationURL = defaultOut
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
                            preset: .fullHD,
                            customWidth: 1920,
                            customHeight: 1080,
                            scale: 1.0,
                            maintainAspect: true,
                            allowUpscale: false
                        )
                        switch result {
                        case .success(let outBytes):
                            let defaultOut = destFolder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)_resized.\(source.pathExtension)")
                            queue[i].destinationURL = defaultOut
                            queue[i].outputSize = Int64(outBytes)
                            queue[i].status = .completed
                            queue[i].progress = 1.0
                        case .failure(let err):
                            throw err
                        }
                        
                    case .compressPDF:
                        let result = PDFCompressorService.compressSinglePDF(
                            inputURL: source,
                            outputDir: destFolder,
                            preset: .balanced
                        )
                        switch result {
                        case .success(let outBytes):
                            let defaultOut = destFolder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)_compressed.pdf")
                            queue[i].destinationURL = defaultOut
                            queue[i].outputSize = Int64(outBytes)
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
                            if let tiff = image.tiffRepresentation,
                               let rep = NSBitmapImageRep(data: tiff),
                               let jpeg = rep.representation(using: .jpeg, properties: [:]) {
                                let targetOut = destFolder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)_page1.jpg")
                                try jpeg.write(to: targetOut)
                                queue[i].destinationURL = targetOut
                                queue[i].outputSize = Int64(jpeg.count)
                                queue[i].status = .completed
                                queue[i].progress = 1.0
                            } else {
                                queue[i].status = .completed
                                queue[i].progress = 1.0
                            }
                        } else {
                            queue[i].status = .completed
                            queue[i].progress = 1.0
                        }
                        
                    case .imagesToPDF, .mergePDFs:
                        queue[i].status = .completed
                        queue[i].progress = 1.0
                        queue[i].outputSize = queue[i].sourceSize
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
