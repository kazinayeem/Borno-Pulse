//
//  ImageFormatConverterService.swift
//  Naem Smart Tool
//

import AppKit
import Combine
import Foundation
import ImageIO

@MainActor
public final class ImageFormatConverterService: ObservableObject {
    public static let shared = ImageFormatConverterService()
    
    @Published public var queue: [ImageFileQueueItem] = []
    @Published public var targetFormat: ImageFormat = .jpeg
    @Published public var outputDirectory: URL?
    @Published public var backgroundColor: NSColor = .white
    @Published public var isProcessing = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    @Published public var completedCount = 0
    @Published public var failedCount = 0
    
    private var conversionTask: Task<Void, Never>?
    
    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    public func addFiles(urls: [URL]) {
        for url in urls {
            // Verify readability and dimensions via CGImageSource
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { continue }
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            var dimensions: CGSize? = nil
            
            if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                let width = props[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
                let height = props[kCGImagePropertyPixelHeight] as? CGFloat ?? 0
                if width > 0 && height > 0 {
                    dimensions = CGSize(width: width, height: height)
                }
            }
            
            let item = ImageFileQueueItem(
                url: url,
                originalFormat: url.pathExtension.uppercased(),
                originalSizeBytes: UInt64(fileSize),
                dimensions: dimensions
            )
            queue.append(item)
        }
        statusMessage = "Added \(queue.count) files to queue"
    }
    
    public func clearQueue() {
        queue.removeAll()
        completedCount = 0
        failedCount = 0
        currentProgress = 0.0
        statusMessage = "Queue cleared"
    }
    
    public func selectOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Output Folder"
        openPanel.title = "Choose Destination for Converted Images"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.outputDirectory = url
        }
    }
    
    public func convertAll() {
        guard !isProcessing, !queue.isEmpty, let outDir = outputDirectory else { return }
        isProcessing = true
        completedCount = 0
        failedCount = 0
        currentProgress = 0.0
        statusMessage = "Converting images..."
        
        let items = queue
        let format = targetFormat
        let bgColor = backgroundColor
        
        conversionTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let total = Double(items.count)
            
            for (index, item) in items.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.statusMessage = "Converting \(item.filename)... (\(index + 1)/\(items.count))"
                    self.currentProgress = Double(index) / total
                    if let qIdx = self.queue.firstIndex(where: { $0.id == item.id }) {
                        self.queue[qIdx].status = .processing
                    }
                }
                
                let result = ImageFormatConverterService.convertSingleImage(
                    inputURL: item.url,
                    outputDir: outDir,
                    targetFormat: format,
                    backgroundColor: bgColor
                )
                
                await MainActor.run {
                    if let qIdx = self.queue.firstIndex(where: { $0.id == item.id }) {
                        if case .success(let outSize) = result {
                            self.queue[qIdx].status = .completed
                            self.queue[qIdx].outputSizeBytes = outSize
                            self.completedCount += 1
                        } else if case .failure(let err) = result {
                            self.queue[qIdx].status = .failed
                            self.queue[qIdx].errorMessage = err.localizedDescription
                            self.failedCount += 1
                        }
                    }
                }
            }
            
            await MainActor.run {
                self.isProcessing = false
                self.currentProgress = 1.0
                self.statusMessage = "Completed \(self.completedCount) conversions (\(self.failedCount) failed)"
            }
        }
    }
    
    public func cancel() {
        conversionTask?.cancel()
        conversionTask = nil
        isProcessing = false
        statusMessage = "Conversion cancelled"
    }
    
    private nonisolated static func convertSingleImage(
        inputURL: URL,
        outputDir: URL,
        targetFormat: ImageFormat,
        backgroundColor: NSColor
    ) -> Result<UInt64, Error> {
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return .failure(NSError(domain: "ImageConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to decode image source."]))
        }
        
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let outputURL = outputDir.appendingPathComponent("\(baseName).\(targetFormat.fileExtension)")
        
        let finalImage: CGImage
        if !targetFormat.supportsAlpha {
            // Flatten alpha channel with selected background color
            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                return .failure(NSError(domain: "ImageConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed creating graphics context."]))
            }
            
            // Draw custom background
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            guard let flattened = context.makeImage() else {
                return .failure(NSError(domain: "ImageConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed flattening image alpha."]))
            }
            finalImage = flattened
        } else {
            finalImage = cgImage
        }
        
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, targetFormat.utTypeIdentifier, 1, nil) else {
            return .failure(NSError(domain: "ImageConverter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unsupported destination format on this system."]))
        }
        
        // Pass original orientation metadata if available
        var destinationProperties: [CFString: Any] = [:]
        if let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            if let orientation = sourceProperties[kCGImagePropertyOrientation] {
                destinationProperties[kCGImagePropertyOrientation] = orientation
            }
        }
        
        CGImageDestinationAddImage(destination, finalImage, destinationProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return .failure(NSError(domain: "ImageConverter", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed writing converted image."]))
        }
        
        let outputSize = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return .success(UInt64(outputSize))
    }
}
