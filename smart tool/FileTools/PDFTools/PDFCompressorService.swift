//
//  PDFCompressorService.swift
//  Borno Pulse
//
//  Size reduction by re-encoding embedded images through a Quartz filter applied at write
//  time (the documented "QuartzFilter" PDFDocument write option, the same mechanism as
//  Preview's "Reduce File Size"). Text, vector artwork, links and annotations stay intact.
//  Only the explicit "Flatten to Images" preset rasterizes pages. Outputs are verified and
//  never replace the source file.
//

import AppKit
import Combine
import Foundation
import ImageIO
import PDFKit
import Quartz
import UniformTypeIdentifiers

public struct PDFCompressionOutput: Sendable {
    public let url: URL
    public let bytes: UInt64
    public let originalBytes: UInt64
}

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
    @Published public var rejectedFilesMessage: String?

    private var task: Task<Void, Never>?

    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }

    public func addFiles(urls: [URL]) {
        var rejected: [String] = []
        for url in urls {
            guard url.pathExtension.lowercased() == "pdf" else {
                rejected.append("\(url.lastPathComponent) (not a PDF)")
                continue
            }
            guard !queue.contains(where: { $0.url == url }) else { continue }
            guard let doc = PDFDocument(url: url) else {
                rejected.append("\(url.lastPathComponent) (damaged or unreadable)")
                continue
            }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            var item = PDFFileQueueItem(url: url, pageCount: doc.pageCount, fileSize: UInt64(size), isEncrypted: doc.isLocked)
            if doc.isLocked {
                item.status = .failed
                item.errorMessage = "Password-protected. Unlock it first."
            }
            queue.append(item)
            totalOriginalBytes += UInt64(size)
        }
        rejectedFilesMessage = rejected.isEmpty ? nil : "Skipped: " + rejected.joined(separator: ", ")
        statusMessage = "\(queue.count) PDF document(s) in queue"
    }

    public func clearQueue() {
        queue.removeAll()
        totalOriginalBytes = 0
        totalCompressedBytes = 0
        currentProgress = 0.0
        rejectedFilesMessage = nil
        statusMessage = "Queue cleared"
    }

    public func selectOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Destination"
        openPanel.title = "Choose Destination for Compressed PDFs"
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.outputDirectory = url
        }
    }

    public func compressAll() {
        guard !isProcessing, !queue.isEmpty else { return }
        guard let outDir = outputDirectory else {
            statusMessage = "Choose a destination folder first."
            return
        }
        do {
            try PDFSafeWriter.ensureWritableFolder(outDir)
        } catch {
            statusMessage = error.localizedDescription
            return
        }
        isProcessing = true
        totalCompressedBytes = 0
        currentProgress = 0.0
        statusMessage = "Compressing PDF documents..."

        let items = queue.filter { !$0.isEncrypted }
        let preset = selectedPreset

        task = Task { [weak self] in
            guard let self else { return }
            var savedBytes: UInt64 = 0
            var reducedCount = 0
            var unchangedCount = 0
            var failedCount = 0

            for (index, item) in items.enumerated() {
                if Task.isCancelled { break }
                self.statusMessage = "Optimizing \(item.filename)… (\(index + 1)/\(items.count))"
                self.currentProgress = Double(index) / Double(max(1, items.count))
                self.updateItem(item.id) { $0.status = .processing; $0.errorMessage = nil }

                let result = await Task.detached(priority: .userInitiated) {
                    PDFCompressorService.compress(inputURL: item.url, outputDir: outDir, preset: preset)
                }.value

                switch result {
                case .success(let output):
                    reducedCount += 1
                    savedBytes += output.originalBytes - output.bytes
                    self.totalCompressedBytes += output.bytes
                    self.updateItem(item.id) {
                        $0.status = .completed
                        $0.outputSizeBytes = output.bytes
                        $0.errorMessage = output.url.lastPathComponent
                    }
                case .failure(let error):
                    if let studioError = error as? PDFStudioError, case .emptyResult = studioError {
                        unchangedCount += 1
                        self.updateItem(item.id) {
                            $0.status = .completed
                            $0.outputSizeBytes = nil
                            $0.errorMessage = error.localizedDescription
                        }
                    } else {
                        failedCount += 1
                        self.updateItem(item.id) {
                            $0.status = .failed
                            $0.errorMessage = error.localizedDescription
                        }
                    }
                }
            }

            self.isProcessing = false
            self.currentProgress = 1.0
            var parts = ["Reduced \(reducedCount) file(s), saving \(Formatters.bytes(savedBytes))."]
            if unchangedCount > 0 { parts.append("\(unchangedCount) already optimal (no file written).") }
            if failedCount > 0 { parts.append("\(failedCount) failed.") }
            self.statusMessage = parts.joined(separator: " ")
        }
    }

    private func updateItem(_ id: UUID, _ change: (inout PDFFileQueueItem) -> Void) {
        if let index = queue.firstIndex(where: { $0.id == id }) {
            change(&queue[index])
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        isProcessing = false
        statusMessage = "Compression cancelled"
    }

    // MARK: - Engine

    /// Compresses `inputURL` into `outputDir` as “name_compressed.pdf” (or a unique variant).
    /// Fails with `PDFStudioError.emptyResult` when the preset cannot make the file smaller;
    /// in that case nothing is written.
    public nonisolated static func compress(
        inputURL: URL,
        outputDir: URL,
        preset: PDFCompressionPreset
    ) -> Result<PDFCompressionOutput, Error> {
        do {
            let source = try PDFSafeWriter.openReadable(inputURL)
            try PDFSafeWriter.ensureWritableFolder(outputDir)
            let originalBytes = UInt64((try? inputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BornoCompress-\(UUID().uuidString).pdf")
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let wrote: Bool
            switch preset {
            case .highQuality:
                wrote = source.write(to: tempURL)
            case .balanced, .compact:
                guard let settings = preset.imageSettings,
                      let filter = imageCompressionFilter(quality: settings.quality, resolution: settings.resolution) else {
                    throw PDFStudioError.failed("The image compression filter is unavailable on this Mac.")
                }
                wrote = source.write(to: tempURL, withOptions: [quartzFilterOption: filter])
            case .flatten:
                wrote = flattenedData(source, dpi: preset.dpi).map { (try? $0.write(to: tempURL)) != nil } ?? false
            }
            guard wrote else { throw PDFStudioError.writeFailed(inputURL.lastPathComponent) }
            try PDFSafeWriter.verify(tempURL, expectedPageCount: source.pageCount)

            let newBytes = UInt64((try? tempURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            guard newBytes > 0, newBytes < originalBytes else {
                throw PDFStudioError.emptyResult("Already optimized: this preset would not make “\(inputURL.lastPathComponent)” smaller, so no file was written.")
            }

            let baseName = inputURL.deletingPathExtension().lastPathComponent
            let destination = PDFSafeWriter.uniqueURL(for: outputDir.appendingPathComponent("\(baseName)_compressed.pdf"))
            try PDFSafeWriter.install(generatedFile: tempURL, at: destination)
            return .success(PDFCompressionOutput(url: destination, bytes: newBytes, originalBytes: originalBytes))
        } catch {
            return .failure(error)
        }
    }

    /// Key documented in PDFDocument.h for applying a QuartzFilter while writing.
    nonisolated static let quartzFilterOption = PDFDocumentWriteOption(rawValue: "QuartzFilter")

    nonisolated static func imageCompressionFilter(quality: Double, resolution: Int) -> QuartzFilter? {
        QuartzFilter(properties: [
            "Name": "Borno Pulse Image Compression",
            "FilterType": 1,
            "Domains": ["Applications": true, "Printing": true],
            "FilterData": [
                "ColorSettings": [
                    "ImageSettings": [
                        "Compression Quality": quality,
                        "ImageCompression": "ImageJPEGCompress",
                        "ImageScaleSettings": [
                            "ImageResolution": resolution,
                            "ImageScaleInterpolate": true,
                            "ImageSizeMax": 4000,
                            "ImageSizeMin": 0
                        ]
                    ]
                ]
            ]
        ])
    }

    /// Backwards-compatible wrapper returning only the compressed size.
    public nonisolated static func compressSinglePDF(
        inputURL: URL,
        outputDir: URL,
        preset: PDFCompressionPreset
    ) -> Result<UInt64, Error> {
        compress(inputURL: inputURL, outputDir: outputDir, preset: preset).map(\.bytes)
    }

    private nonisolated static func flattenedData(_ document: PDFDocument, dpi: CGFloat) -> Data? {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { return nil }
        let scale = dpi / 72
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let box = page.bounds(for: .cropBox)
            let displayed = PDFEditorGeometry.displayedPageSize(box.size, rotation: page.rotation)
            let width = max(1, Int(displayed.width * scale)), height = max(1, Int(displayed.height * scale))
            guard let bitmap = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return nil }
            bitmap.setFillColor(NSColor.white.cgColor)
            bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
            bitmap.scaleBy(x: scale, y: scale)
            page.draw(with: .cropBox, to: bitmap)
            guard let raster = bitmap.makeImage() else { return nil }

            let jpeg = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(jpeg as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, raster, [kCGImageDestinationLossyCompressionQuality: 0.6] as CFDictionary)
            guard CGImageDestinationFinalize(destination),
                  let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
                  let jpegImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

            var mediaBox = CGRect(origin: .zero, size: displayed)
            context.beginPage(mediaBox: &mediaBox)
            context.draw(jpegImage, in: mediaBox)
            context.endPage()
        }
        context.closePDF()
        return output as Data
    }
}
