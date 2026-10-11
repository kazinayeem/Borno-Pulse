//
//  PDFToImagesService.swift
//  Borno Pulse
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
    @Published public var lastError: String?
    @Published public var exportedURLs: [URL] = []

    private var task: Task<Void, Never>?

    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }

    public func loadPDF(url: URL) {
        lastError = nil
        do {
            let doc = try PDFSafeWriter.openReadable(url)
            selectedPDFURL = url
            pdfDocument = doc
            startPage = 1
            endPage = doc.pageCount
            exportedCount = 0
            exportedURLs = []
            statusMessage = "Loaded \(url.lastPathComponent) (\(doc.pageCount) pages)"
        } catch {
            selectedPDFURL = nil
            pdfDocument = nil
            lastError = error.localizedDescription
            statusMessage = error.localizedDescription
        }
    }

    public func selectOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Output Folder"
        openPanel.title = "Choose Destination for Rendered Images"
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.outputDirectory = url
        }
    }

    /// Validates the requested page range; returns zero-based indices or an error message.
    public static func pageIndices(exportAll: Bool, start: Int, end: Int, pageCount: Int) -> Result<ClosedRange<Int>, PDFStudioError> {
        guard pageCount > 0 else { return .failure(.emptyResult("The document has no pages.")) }
        if exportAll { return .success(0...(pageCount - 1)) }
        guard start >= 1, end >= 1, start <= pageCount, end <= pageCount else {
            return .failure(.invalidPageRange("Pages must be between 1 and \(pageCount)."))
        }
        guard start <= end else {
            return .failure(.invalidPageRange("The first page (\(start)) must not be after the last page (\(end))."))
        }
        return .success((start - 1)...(end - 1))
    }

    public func exportImages() {
        guard !isProcessing, let inURL = selectedPDFURL, let doc = pdfDocument else { return }
        lastError = nil
        guard let outDir = outputDirectory else {
            lastError = "Choose an output folder first."
            return
        }
        let range: ClosedRange<Int>
        switch Self.pageIndices(exportAll: exportAllPages, start: startPage, end: endPage, pageCount: doc.pageCount) {
        case .success(let value): range = value
        case .failure(let error):
            lastError = error.localizedDescription
            statusMessage = error.localizedDescription
            return
        }
        do {
            try PDFSafeWriter.ensureWritableFolder(outDir)
        } catch {
            lastError = error.localizedDescription
            return
        }

        isProcessing = true
        exportedCount = 0
        exportedURLs = []
        currentProgress = 0.0
        statusMessage = "Exporting pages to images..."
        let resolution = dpi
        let format = targetFormat

        task = Task { [weak self] in
            guard let self else { return }
            let total = range.count
            var written: [URL] = []
            var failures = 0
            for (offset, pageIndex) in range.enumerated() {
                if Task.isCancelled { break }
                self.statusMessage = "Rendering page \(pageIndex + 1)… (\(offset + 1)/\(total))"
                self.currentProgress = Double(offset) / Double(total)
                let output = await Task.detached(priority: .userInitiated) { () -> URL? in
                    guard let document = PDFDocument(url: inURL), let page = document.page(at: pageIndex) else { return nil }
                    let baseName = inURL.deletingPathExtension().lastPathComponent
                    let target = PDFSafeWriter.uniqueURL(for: outDir.appendingPathComponent("\(baseName)_page_\(pageIndex + 1).\(format.fileExtension)"))
                    return PDFToImagesService.writeImage(of: page, dpi: resolution, format: format, to: target) ? target : nil
                }.value
                if let output { written.append(output) } else { failures += 1 }
            }
            self.isProcessing = false
            self.exportedCount = written.count
            self.exportedURLs = written
            self.currentProgress = 1.0
            if Task.isCancelled {
                self.statusMessage = "Cancelled after \(written.count) page(s)."
            } else if failures > 0 {
                self.statusMessage = "Exported \(written.count) of \(total) pages. \(failures) page(s) could not be rendered or written."
                self.lastError = self.statusMessage
            } else {
                self.statusMessage = "Exported \(written.count) page image(s) to \(outDir.lastPathComponent)."
            }
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        isProcessing = false
        statusMessage = "Export cancelled"
    }

    /// Renders a page as displayed (crop box, /Rotate applied) at `dpi`.
    public nonisolated static func renderImage(of page: PDFPage, dpi: CGFloat, opaque: Bool = true) -> CGImage? {
        let box = page.bounds(for: .cropBox)
        let displayed = PDFEditorGeometry.displayedPageSize(box.size, rotation: page.rotation)
        let scale = dpi / 72
        let width = max(1, Int((displayed.width * scale).rounded())), height = max(1, Int((displayed.height * scale).rounded()))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue
        ) else { return nil }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.scaleBy(x: CGFloat(width) / displayed.width, y: CGFloat(height) / displayed.height)
        page.draw(with: .cropBox, to: context)
        return context.makeImage()
    }

    public nonisolated static func writeImage(of page: PDFPage, dpi: CGFloat, format: ImageFormat, to url: URL) -> Bool {
        guard let image = renderImage(of: page, dpi: dpi),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, format.utTypeIdentifier, 1, nil) else { return false }
        var properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi
        ]
        if format == .jpeg || format == .heic {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.9
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }
}
