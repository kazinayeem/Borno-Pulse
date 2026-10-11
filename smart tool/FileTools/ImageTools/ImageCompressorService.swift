//
//  ImageCompressorService.swift
//  Naem Smart Tool
//

import AppKit
import Combine
import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor
public final class ImageCompressorService: ObservableObject {
    public static let shared = ImageCompressorService()
    
    @Published public var queue: [ImageFileQueueItem] = []
    @Published public var selectedPreset: ImageCompressionPreset = .balanced
    @Published public var qualityValue: Float = 0.70
    @Published public var outputDirectory: URL?
    @Published public var isProcessing = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    @Published public var totalOriginalBytes: UInt64 = 0
    @Published public var totalCompressedBytes: UInt64 = 0
    
    private var compressionTask: Task<Void, Never>?
    
    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    public func applyPreset(_ preset: ImageCompressionPreset) {
        self.selectedPreset = preset
        self.qualityValue = preset.qualityValue
    }
    
    public func addFiles(urls: [URL]) {
        for url in urls {
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
            totalOriginalBytes += UInt64(fileSize)
        }
        statusMessage = "Added \(queue.count) images for compression"
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
        openPanel.title = "Choose Destination for Compressed Images"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.outputDirectory = url
        }
    }
    
    public var estimatedTotalOutputBytes: UInt64 {
        // Approximate reduction based on quality factor
        let factor = Double(qualityValue) * 0.85
        return UInt64(Double(totalOriginalBytes) * factor)
    }
    
    public func compressAll() {
        guard !isProcessing, !queue.isEmpty, let outDir = outputDirectory else { return }
        isProcessing = true
        totalCompressedBytes = 0
        currentProgress = 0.0
        statusMessage = "Compressing images..."
        
        let items = queue
        let q = qualityValue
        
        compressionTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let total = Double(items.count)
            var accumCompressed: UInt64 = 0
            
            for (index, item) in items.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.statusMessage = "Compressing \(item.filename)... (\(index + 1)/\(items.count))"
                    self.currentProgress = Double(index) / total
                    if let qIdx = self.queue.firstIndex(where: { $0.id == item.id }) {
                        self.queue[qIdx].status = .processing
                    }
                }
                
                let result = ImageCompressorService.compressSingleImage(
                    inputURL: item.url,
                    outputDir: outDir,
                    quality: q
                )
                
                await MainActor.run {
                    if let qIdx = self.queue.firstIndex(where: { $0.id == item.id }) {
                        if case .success(let outSize) = result {
                            self.queue[qIdx].status = .completed
                            self.queue[qIdx].outputSizeBytes = outSize
                            accumCompressed += outSize
                            self.totalCompressedBytes = accumCompressed
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
                self.statusMessage = "Compression complete! Reclaimed \(Formatters.bytes(saved)) (\(String(format: "%.1f", pct))% reduction)."
            }
        }
    }
    
    public func cancel() {
        compressionTask?.cancel()
        compressionTask = nil
        isProcessing = false
        statusMessage = "Compression cancelled"
    }
    
    private nonisolated static func compressSingleImage(
        inputURL: URL,
        outputDir: URL,
        quality: Float
    ) -> Result<UInt64, Error> {
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return .failure(NSError(domain: "ImageCompressor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed decoding image."]))
        }
        
        let ext = inputURL.pathExtension.lowercased()
        let isPNG = ext == "png"
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        
        // Target destination format: if PNG and user wants strong lossy compression, converting to JPG provides dramatic size reduction
        let outFormatUTI: CFString
        let outExtension: String
        
        if isPNG {
            outFormatUTI = UTType.png.identifier as CFString
            outExtension = "png"
        } else {
            outFormatUTI = UTType.jpeg.identifier as CFString
            outExtension = "jpg"
        }
        
        let outputURL = outputDir.appendingPathComponent("\(baseName)_compressed.\(outExtension)")
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, outFormatUTI, 1, nil) else {
            return .failure(NSError(domain: "ImageCompressor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed creating destination."]))
        }
        
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality as NSNumber
        ]
        
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return .failure(NSError(domain: "ImageCompressor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed writing compressed image."]))
        }
        
        let outSize = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return .success(UInt64(outSize))
    }
}
