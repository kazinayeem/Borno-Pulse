//
//  ImageResizerService.swift
//  Borno Pulse
//

import AppKit
import Combine
import Foundation
import ImageIO

@MainActor
public final class ImageResizerService: ObservableObject {
    public static let shared = ImageResizerService()
    
    @Published public var queue: [ImageFileQueueItem] = []
    @Published public var resizeMode: ResizeMode = .preset
    @Published public var selectedPreset: ResizePreset = .socialPost
    @Published public var customWidth: Double = 1920
    @Published public var customHeight: Double = 1080
    @Published public var scalePercentage: Double = 50.0
    @Published public var maintainAspectRatio: Bool = true
    @Published public var allowUpscaling: Bool = false
    @Published public var outputDirectory: URL?
    @Published public var isProcessing = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    
    private var resizeTask: Task<Void, Never>?
    
    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
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
        }
        statusMessage = "Added \(queue.count) images for resizing"
    }
    
    public func clearQueue() {
        queue.removeAll()
        currentProgress = 0.0
        statusMessage = "Queue cleared"
    }
    
    public func selectOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Destination"
        openPanel.title = "Choose Destination for Resized Images"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.outputDirectory = url
        }
    }
    
    public func resizeAll() {
        guard !isProcessing, !queue.isEmpty, let outDir = outputDirectory else { return }
        isProcessing = true
        currentProgress = 0.0
        statusMessage = "Resizing images..."
        
        let items = queue
        let mode = resizeMode
        let preset = selectedPreset
        let targetW = customWidth
        let targetH = customHeight
        let scale = scalePercentage / 100.0
        let keepAspect = maintainAspectRatio
        let upscaling = allowUpscaling
        
        resizeTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let total = Double(items.count)
            
            for (index, item) in items.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.statusMessage = "Resizing \(item.filename)... (\(index + 1)/\(items.count))"
                    self.currentProgress = Double(index) / total
                    if let qIdx = self.queue.firstIndex(where: { $0.id == item.id }) {
                        self.queue[qIdx].status = .processing
                    }
                }
                
                let result = ImageResizerService.resizeSingleImage(
                    inputURL: item.url,
                    outputDir: outDir,
                    mode: mode,
                    preset: preset,
                    customWidth: targetW,
                    customHeight: targetH,
                    scale: scale,
                    maintainAspect: keepAspect,
                    allowUpscale: upscaling
                )
                
                await MainActor.run {
                    if let qIdx = self.queue.firstIndex(where: { $0.id == item.id }) {
                        if case .success(let outSize) = result {
                            self.queue[qIdx].status = .completed
                            self.queue[qIdx].outputSizeBytes = outSize
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
                self.statusMessage = "Resizing completed."
            }
        }
    }
    
    public func cancel() {
        resizeTask?.cancel()
        resizeTask = nil
        isProcessing = false
        statusMessage = "Resizing cancelled"
    }
    
    public nonisolated static func resizeSingleImage(
        inputURL: URL,
        outputDir: URL,
        mode: ResizeMode,
        preset: ResizePreset,
        customWidth: Double,
        customHeight: Double,
        scale: Double,
        maintainAspect: Bool,
        allowUpscale: Bool
    ) -> Result<UInt64, Error> {
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return .failure(NSError(domain: "ImageResizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed decoding source image."]))
        }
        
        let origW = CGFloat(cgImage.width)
        let origH = CGFloat(cgImage.height)
        let cW = CGFloat(customWidth)
        let cH = CGFloat(customHeight)
        
        var destW: CGFloat
        var destH: CGFloat
        
        switch mode {
        case .preset:
            let target = preset.targetSize
            if maintainAspect {
                let ratio = min(target.width / origW, target.height / origH)
                destW = origW * ratio
                destH = origH * ratio
            } else {
                destW = target.width
                destH = target.height
            }
        case .pixels:
            if maintainAspect {
                let ratio = cW / origW
                destW = cW
                destH = origH * ratio
            } else {
                destW = cW
                destH = cH
            }
        case .percentage:
            destW = origW * CGFloat(scale)
            destH = origH * CGFloat(scale)
        }
        
        // Check upscaling rule
        if !allowUpscale {
            if destW > origW || destH > origH {
                destW = min(destW, origW)
                destH = min(destH, origH)
            }
        }
        
        let targetSize = CGSize(width: max(destW, 1), height: max(destH, 1))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return .failure(NSError(domain: "ImageResizer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed creating bitmap context."]))
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        
        guard let resizedCG = context.makeImage() else {
            return .failure(NSError(domain: "ImageResizer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed rendering resized image."]))
        }
        
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let ext = inputURL.pathExtension
        let outputURL = outputDir.appendingPathComponent("\(baseName)_\(Int(targetSize.width))x\(Int(targetSize.height)).\(ext)")
        
        let uti = (ext.lowercased() == "png") ? (kUTTypePNG as CFString) : (kUTTypeJPEG as CFString)
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, uti, 1, nil) else {
            return .failure(NSError(domain: "ImageResizer", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed creating destination file."]))
        }
        
        CGImageDestinationAddImage(destination, resizedCG, nil)
        guard CGImageDestinationFinalize(destination) else {
            return .failure(NSError(domain: "ImageResizer", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed finalizing output file."]))
        }
        
        let outSize = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return .success(UInt64(outSize))
    }
}
