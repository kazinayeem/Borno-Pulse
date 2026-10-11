//
//  PDFAssemblyService.swift
//  Borno Pulse
//
//  Unified document assembly, drag-and-drop page reordering, and mixed PDF/image merger engine.
//

import AppKit
import Foundation
import PDFKit

@MainActor
public final class PDFAssemblyService: ObservableObject {
    public static let shared = PDFAssemblyService()

    @Published public var pages: [PDFStudioPageItem] = []
    @Published public var pageSizePreset: PDFPageSizePreset = .a4
    @Published public var pageMargin: PDFPageMargin = .small
    @Published public var isLandscape: Bool = false
    @Published public var imageFitMode: ImageFitMode = .contain
    @Published public var outputFilename: String = "Assembled_Document.pdf"
    @Published public var outputDirectory: URL?
    @Published public var isProcessing: Bool = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready"

    private let thumbnailCache = NSCache<NSString, NSImage>()

    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        self.thumbnailCache.countLimit = 200
    }

    // MARK: - Import Files
    public func addFiles(urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                addPDFFile(url: url)
            } else if ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "bmp", "webp"].contains(ext) {
                addImageFile(url: url)
            }
        }
        statusMessage = "Workspace contains \(pages.count) total pages"
    }

    private func addPDFFile(url: URL) {
        guard let doc = PDFDocument(url: url) else { return }
        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let item = PDFStudioPageItem(
                sourceURL: url,
                sourceType: .pdfPage,
                originalPageIndex: index,
                rotationAngle: page.rotation,
                customWidth: bounds.width,
                customHeight: bounds.height,
                cachedThumbnail: generatePDFThumbnail(page: page),
                pageTitle: "\(url.deletingPathExtension().lastPathComponent) (p. \(index + 1))"
            )
            pages.append(item)
        }
    }

    private func addImageFile(url: URL) {
        var dimensions: CGSize? = nil
        var thumb: NSImage? = nil
        if let image = NSImage(contentsOf: url) {
            dimensions = image.size
            thumb = createThumbnail(from: image, size: CGSize(width: 120, height: 160))
        }

        let item = PDFStudioPageItem(
            sourceURL: url,
            sourceType: .image,
            originalPageIndex: 0,
            rotationAngle: 0,
            customWidth: dimensions?.width,
            customHeight: dimensions?.height,
            cachedThumbnail: thumb,
            pageTitle: url.lastPathComponent
        )
        pages.append(item)
    }

    // MARK: - Reordering & Operations
    public func movePages(fromOffsets source: IndexSet, toOffset destination: Int) {
        pages.move(fromOffsets: source, toOffset: destination)
        statusMessage = "Reordered pages"
    }

    public func movePage(fromIndex: Int, toIndex: Int) {
        guard fromIndex >= 0 && fromIndex < pages.count,
              toIndex >= 0 && toIndex < pages.count,
              fromIndex != toIndex else { return }
        let item = pages.remove(at: fromIndex)
        pages.insert(item, at: toIndex)
        statusMessage = "Moved page to position \(toIndex + 1)"
    }

    public func rotatePage(id: UUID, delta: Int = 90) {
        if let idx = pages.firstIndex(where: { $0.id == id }) {
            pages[idx].rotationAngle = (pages[idx].rotationAngle + delta) % 360
            statusMessage = "Rotated page \(idx + 1)"
        }
    }

    public func duplicatePage(id: UUID) {
        if let idx = pages.firstIndex(where: { $0.id == id }) {
            let original = pages[idx]
            let duplicate = PDFStudioPageItem(
                sourceURL: original.sourceURL,
                sourceType: original.sourceType,
                originalPageIndex: original.originalPageIndex,
                rotationAngle: original.rotationAngle,
                customWidth: original.customWidth,
                customHeight: original.customHeight,
                cachedThumbnail: original.cachedThumbnail,
                pageTitle: "\(original.pageTitle) (Copy)"
            )
            pages.insert(duplicate, at: idx + 1)
            statusMessage = "Duplicated page \(idx + 1)"
        }
    }

    public func removePage(id: UUID) {
        pages.removeAll { $0.id == id }
        statusMessage = "Removed page. \(pages.count) remaining"
    }

    public func removeSelectedPages() {
        let countBefore = pages.count
        pages.removeAll { $0.isSelected }
        let removed = countBefore - pages.count
        statusMessage = "Removed \(removed) selected page(s)"
    }

    public func clearAllPages() {
        pages.removeAll()
        statusMessage = "Workspace cleared"
    }

    public func togglePageSelection(id: UUID) {
        if let idx = pages.firstIndex(where: { $0.id == id }) {
            pages[idx].isSelected.toggle()
        }
    }

    public func selectAllPages() {
        for idx in pages.indices {
            pages[idx].isSelected = true
        }
    }

    public func deselectAllPages() {
        for idx in pages.indices {
            pages[idx].isSelected = false
        }
    }

    // MARK: - Document Building & Rendering
    public func buildMergedDocument() -> PDFDocument {
        let doc = PDFDocument()
        let presetSize = pageSizePreset.pointSize
        let margin = pageMargin.inset
        let isLand = isLandscape
        let fit = imageFitMode

        for item in pages {
            if item.sourceType == .pdfPage {
                // Native PDF Page: preserve selectable text and vector graphics!
                if let sourceDoc = PDFDocument(url: item.sourceURL),
                   let page = sourceDoc.page(at: item.originalPageIndex) {
                    page.rotation = item.rotationAngle
                    doc.insert(page, at: doc.pageCount)
                }
            } else if item.sourceType == .image {
                // Image Page: Render into PDF Page context with specified dimensions
                if let image = NSImage(contentsOf: item.sourceURL) {
                    var targetSize = presetSize == .zero ? image.size : presetSize
                    if isLand && targetSize.width < targetSize.height {
                        targetSize = CGSize(width: targetSize.height, height: targetSize.width)
                    }

                    if let pdfPage = renderImageToPDFPage(
                        image: image,
                        targetSize: targetSize,
                        margin: margin,
                        fitMode: fit,
                        rotation: item.rotationAngle
                    ) {
                        doc.insert(pdfPage, at: doc.pageCount)
                    }
                }
            }
        }
        return doc
    }

    // MARK: - Export Merged Document
    public func exportMergedDocument(to destinationURL: URL? = nil) -> Result<URL, Error> {
        guard !pages.isEmpty else {
            return .failure(NSError(domain: "PDFAssemblyService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No pages to assemble."]))
        }

        let targetURL: URL
        if let explicit = destinationURL {
            targetURL = explicit
        } else if let outDir = outputDirectory {
            let filename = outputFilename.hasSuffix(".pdf") ? outputFilename : "\(outputFilename).pdf"
            targetURL = outDir.appendingPathComponent(filename)
        } else {
            let savePanel = NSSavePanel()
            savePanel.title = "Save Assembled PDF"
            savePanel.nameFieldStringValue = outputFilename.hasSuffix(".pdf") ? outputFilename : "\(outputFilename).pdf"
            guard savePanel.runModal() == .OK, let url = savePanel.url else {
                return .failure(NSError(domain: "PDFAssemblyService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export cancelled."]))
            }
            targetURL = url
        }

        isProcessing = true
        currentProgress = 0.5
        statusMessage = "Generating assembled PDF..."

        let document = buildMergedDocument()
        let success = document.write(to: targetURL)

        isProcessing = false
        currentProgress = 1.0

        if success {
            statusMessage = "Exported \(document.pageCount) pages to \(targetURL.lastPathComponent)"
            return .success(targetURL)
        } else {
            statusMessage = "Failed writing PDF to destination."
            return .failure(NSError(domain: "PDFAssemblyService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed writing PDF file."]))
        }
    }

    // MARK: - Helper Thumbnail & Rendering
    private func generatePDFThumbnail(page: PDFPage) -> NSImage {
        let bounds = page.bounds(for: .mediaBox)
        let thumbSize = CGSize(width: 120, height: 160)
        return page.thumbnail(of: thumbSize, for: .mediaBox)
    }

    private func createThumbnail(from image: NSImage, size: CGSize) -> NSImage {
        let img = NSImage(size: size)
        img.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
        img.unlockFocus()
        return img
    }

    private func renderImageToPDFPage(
        image: NSImage,
        targetSize: CGSize,
        margin: CGFloat,
        fitMode: ImageFitMode,
        rotation: Int
    ) -> PDFPage? {
        let pdfData = NSMutableData()
        var pageRect = CGRect(origin: .zero, size: targetSize)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return nil
        }

        context.beginPDFPage(nil)

        let printableRect = pageRect.insetBy(dx: margin, dy: margin)
        let imageSize = image.size
        var drawRect: CGRect

        switch fitMode {
        case .contain:
            let scale = min(printableRect.width / imageSize.width, printableRect.height / imageSize.height)
            let scaledW = imageSize.width * scale
            let scaledH = imageSize.height * scale
            let originX = printableRect.minX + (printableRect.width - scaledW) / 2.0
            let originY = printableRect.minY + (printableRect.height - scaledH) / 2.0
            drawRect = CGRect(x: originX, y: originY, width: scaledW, height: scaledH)
        case .cover:
            let scale = max(printableRect.width / imageSize.width, printableRect.height / imageSize.height)
            let scaledW = imageSize.width * scale
            let scaledH = imageSize.height * scale
            let originX = printableRect.minX + (printableRect.width - scaledW) / 2.0
            let originY = printableRect.minY + (printableRect.height - scaledH) / 2.0
            drawRect = CGRect(x: originX, y: originY, width: scaledW, height: scaledH)
        case .stretch:
            drawRect = printableRect
        }

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: drawRect)
        }

        context.endPDFPage()
        context.closePDF()

        if let renderedDoc = PDFDocument(data: pdfData as Data), let page = renderedDoc.page(at: 0) {
            page.rotation = rotation
            return page
        }
        return nil
    }

    // MARK: - Split & Extraction
    public func splitDocument(
        sourceURL: URL,
        splitMode: String,
        splitInterval: Int = 1,
        splitRangesText: String = "",
        destinationFolder: URL
    ) -> [URL] {
        guard let doc = PDFDocument(url: sourceURL) else { return [] }
        var outputURLs: [URL] = []
        let baseName = sourceURL.deletingPathExtension().lastPathComponent

        if splitMode == "each" {
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let newDoc = PDFDocument()
                newDoc.insert(page, at: 0)
                let outURL = destinationFolder.appendingPathComponent("\(baseName)_page_\(i + 1).pdf")
                if newDoc.write(to: outURL) {
                    outputURLs.append(outURL)
                }
            }
        } else if splitMode == "interval" {
            let interval = max(1, splitInterval)
            var part = 1
            var pageIndex = 0
            while pageIndex < doc.pageCount {
                let newDoc = PDFDocument()
                for _ in 0..<interval {
                    if pageIndex < doc.pageCount, let page = doc.page(at: pageIndex) {
                        newDoc.insert(page, at: newDoc.pageCount)
                        pageIndex += 1
                    }
                }
                let outURL = destinationFolder.appendingPathComponent("\(baseName)_part_\(part).pdf")
                if newDoc.write(to: outURL) {
                    outputURLs.append(outURL)
                }
                part += 1
            }
        } else if splitMode == "range" {
            let ranges = parsePageRanges(splitRangesText, maxPages: doc.pageCount)
            for (idx, pageIndices) in ranges.enumerated() {
                let newDoc = PDFDocument()
                for pIdx in pageIndices {
                    if let page = doc.page(at: pIdx) {
                        newDoc.insert(page, at: newDoc.pageCount)
                    }
                }
                let outURL = destinationFolder.appendingPathComponent("\(baseName)_range_\(idx + 1).pdf")
                if newDoc.write(to: outURL) {
                    outputURLs.append(outURL)
                }
            }
        }
        return outputURLs
    }

    public func extractPages(
        sourceURL: URL,
        pageRangesText: String,
        destinationURL: URL
    ) -> Bool {
        guard let doc = PDFDocument(url: sourceURL) else { return false }
        let ranges = parsePageRanges(pageRangesText, maxPages: doc.pageCount)
        let newDoc = PDFDocument()
        for pageIndices in ranges {
            for pIdx in pageIndices {
                if let page = doc.page(at: pIdx) {
                    newDoc.insert(page, at: newDoc.pageCount)
                }
            }
        }
        return newDoc.write(to: destinationURL)
    }

    private func parsePageRanges(_ text: String, maxPages: Int) -> [[Int]] {
        var result: [[Int]] = []
        let parts = text.components(separatedBy: ",")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("-") {
                let bounds = trimmed.components(separatedBy: "-")
                if bounds.count == 2,
                   let start = Int(bounds[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                   let end = Int(bounds[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                    let clampedStart = max(1, min(start, maxPages))
                    let clampedEnd = max(1, min(end, maxPages))
                    let range = (min(clampedStart, clampedEnd)...max(clampedStart, clampedEnd)).map { $0 - 1 }
                    result.append(range)
                }
            } else if let single = Int(trimmed) {
                let clamped = max(1, min(single, maxPages))
                result.append([clamped - 1])
            }
        }
        return result.isEmpty ? [Array(0..<maxPages)] : result
    }
}
