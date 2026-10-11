//
//  PDFAssemblyService.swift
//  Borno Pulse
//
//  Document assembly for Images to PDF, Merge PDFs, Merge Images & PDFs, Page Organizer and
//  Rotate & Reorder, plus split/extract. PDF pages are copied (never moved out of their
//  source document), keeping text, vectors, annotations and links. Images are drawn at full
//  resolution with EXIF orientation applied.
//

import AppKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

public struct PDFAssemblyImportReport: Sendable {
    public var addedPages = 0
    public var skippedUnsupported: [String] = []
    public var failed: [String] = []

    public var message: String? {
        var parts: [String] = []
        if !skippedUnsupported.isEmpty {
            parts.append("Not supported by this tool: " + skippedUnsupported.joined(separator: ", "))
        }
        if !failed.isEmpty {
            parts.append("Could not open: " + failed.joined(separator: ", "))
        }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }
}

public struct PDFAssemblyBuildItem: Sendable {
    public let sourceURL: URL
    public let sourceType: DocumentPageSourceType
    public let pageIndex: Int
    public let rotation: Int
}

public struct PDFAssemblyBuildSettings: Sendable {
    public var pageSize: CGSize
    public var margin: CGFloat
    public var landscape: Bool
    public var fitMode: ImageFitMode
}

@MainActor
public final class PDFAssemblyService: ObservableObject {
    public static let shared = PDFAssemblyService()

    private static var workspaces: [PDFStudioTool: PDFAssemblyService] = [:]

    /// Each assembly-style tool keeps its own page list so switching tools never mixes inputs.
    public static func workspace(for tool: PDFStudioTool) -> PDFAssemblyService {
        if let existing = workspaces[tool] { return existing }
        let service = PDFAssemblyService()
        service.acceptedTypes = acceptedTypes(for: tool)
        service.outputFilename = defaultFilename(for: tool)
        workspaces[tool] = service
        return service
    }

    public static func acceptedTypes(for tool: PDFStudioTool) -> Set<DocumentPageSourceType> {
        switch tool {
        case .imagesToPDF: return [.image]
        case .mergeMixed: return [.image, .pdfPage]
        default: return [.pdfPage]
        }
    }

    static func defaultFilename(for tool: PDFStudioTool) -> String {
        switch tool {
        case .imagesToPDF: return "Images.pdf"
        case .mergePDFs: return "Merged.pdf"
        case .mergeMixed: return "Combined.pdf"
        case .pageOrganizer: return "Organized.pdf"
        case .rotateReorder: return "Rotated.pdf"
        default: return "Assembled_Document.pdf"
        }
    }

    public static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tif", "tiff", "bmp", "gif", "webp"]

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
    @Published public var importIssues: String?
    public var acceptedTypes: Set<DocumentPageSourceType> = [.pdfPage, .image]

    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }

    // MARK: - Import

    @discardableResult
    public func addFiles(urls: [URL]) -> PDFAssemblyImportReport {
        var report = PDFAssemblyImportReport()
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                guard acceptedTypes.contains(.pdfPage) else {
                    report.skippedUnsupported.append(url.lastPathComponent)
                    continue
                }
                guard let doc = PDFDocument(url: url) else {
                    report.failed.append("\(url.lastPathComponent) (damaged)")
                    continue
                }
                guard !doc.isLocked else {
                    report.failed.append("\(url.lastPathComponent) (password-protected)")
                    continue
                }
                report.addedPages += addPDF(doc, url: url)
            } else if Self.imageExtensions.contains(ext) {
                guard acceptedTypes.contains(.image) else {
                    report.skippedUnsupported.append(url.lastPathComponent)
                    continue
                }
                if addImageFile(url: url) {
                    report.addedPages += 1
                } else {
                    report.failed.append("\(url.lastPathComponent) (unreadable image)")
                }
            } else {
                report.skippedUnsupported.append(url.lastPathComponent)
            }
        }
        importIssues = report.message
        statusMessage = report.addedPages > 0
            ? "Added \(report.addedPages) page(s). Workspace contains \(pages.count) page(s)."
            : "No pages added."
        return report
    }

    private func addPDF(_ doc: PDFDocument, url: URL) -> Int {
        var added = 0
        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index) else { continue }
            let bounds = page.bounds(for: .cropBox)
            var item = PDFStudioPageItem(
                sourceURL: url,
                sourceType: .pdfPage,
                originalPageIndex: index,
                rotationAngle: page.rotation,
                customWidth: bounds.width,
                customHeight: bounds.height,
                cachedThumbnail: page.thumbnail(of: CGSize(width: 150, height: 190), for: .cropBox),
                pageTitle: "\(url.deletingPathExtension().lastPathComponent) (p. \(index + 1))"
            )
            item.thumbnailRotation = page.rotation
            pages.append(item)
            added += 1
        }
        return added
    }

    private func addImageFile(url: URL) -> Bool {
        guard let image = Self.orientedImage(url: url, maxPixel: 300) else { return false }
        let pixels = Self.orientedPixelSize(url: url) ?? CGSize(width: image.width, height: image.height)
        pages.append(PDFStudioPageItem(
            sourceURL: url,
            sourceType: .image,
            originalPageIndex: 0,
            rotationAngle: 0,
            customWidth: pixels.width,
            customHeight: pixels.height,
            cachedThumbnail: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)),
            pageTitle: url.lastPathComponent
        ))
        return true
    }

    // MARK: - Page Operations

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

    public func movePage(id: UUID, by offset: Int) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        movePage(fromIndex: index, toIndex: max(0, min(pages.count - 1, index + offset)))
    }

    public func movePage(id: UUID, before targetID: UUID) {
        guard id != targetID,
              let from = pages.firstIndex(where: { $0.id == id }),
              let to = pages.firstIndex(where: { $0.id == targetID }) else { return }
        movePage(fromIndex: from, toIndex: to)
    }

    public func reverseOrder() {
        pages.reverse()
        statusMessage = "Reversed page order"
    }

    public func rotatePage(id: UUID, delta: Int = 90) {
        if let idx = pages.firstIndex(where: { $0.id == id }) {
            pages[idx].rotationAngle = Self.normalizedRotation(pages[idx].rotationAngle + delta)
            statusMessage = "Rotated page \(idx + 1)"
        }
    }

    /// Rotates the selected pages, or every page when nothing is selected.
    public func rotateSelectedOrAll(delta: Int) {
        let targetAll = !pages.contains(where: \.isSelected)
        for index in pages.indices where targetAll || pages[index].isSelected {
            pages[index].rotationAngle = Self.normalizedRotation(pages[index].rotationAngle + delta)
        }
        statusMessage = targetAll ? "Rotated all pages by \(delta)°" : "Rotated selected pages by \(delta)°"
    }

    nonisolated static func normalizedRotation(_ value: Int) -> Int {
        ((value % 360) + 360) % 360
    }

    public func duplicatePage(id: UUID) {
        if let idx = pages.firstIndex(where: { $0.id == id }) {
            let original = pages[idx]
            var duplicate = PDFStudioPageItem(
                sourceURL: original.sourceURL,
                sourceType: original.sourceType,
                originalPageIndex: original.originalPageIndex,
                rotationAngle: original.rotationAngle,
                customWidth: original.customWidth,
                customHeight: original.customHeight,
                cachedThumbnail: original.cachedThumbnail,
                pageTitle: "\(original.pageTitle) (Copy)"
            )
            duplicate.thumbnailRotation = original.thumbnailRotation
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
        statusMessage = "Removed \(countBefore - pages.count) selected page(s)"
    }

    public func clearAllPages() {
        pages.removeAll()
        importIssues = nil
        statusMessage = "Workspace cleared"
    }

    public func togglePageSelection(id: UUID) {
        if let idx = pages.firstIndex(where: { $0.id == id }) {
            pages[idx].isSelected.toggle()
        }
    }

    public func selectAllPages() {
        for idx in pages.indices { pages[idx].isSelected = true }
    }

    public func deselectAllPages() {
        for idx in pages.indices { pages[idx].isSelected = false }
    }

    // MARK: - Building

    public var buildItems: [PDFAssemblyBuildItem] {
        pages.map { PDFAssemblyBuildItem(sourceURL: $0.sourceURL, sourceType: $0.sourceType, pageIndex: $0.originalPageIndex, rotation: $0.rotationAngle) }
    }

    public var buildSettings: PDFAssemblyBuildSettings {
        PDFAssemblyBuildSettings(pageSize: pageSizePreset.pointSize, margin: pageMargin.inset, landscape: isLandscape, fitMode: imageFitMode)
    }

    public func buildMergedDocument() -> PDFDocument {
        (try? Self.buildDocument(items: buildItems, settings: buildSettings)) ?? PDFDocument()
    }

    public nonisolated static func buildDocument(
        items: [PDFAssemblyBuildItem],
        settings: PDFAssemblyBuildSettings,
        progress: ((Int) -> Void)? = nil
    ) throws -> PDFDocument {
        let output = PDFDocument()
        var sources: [URL: PDFDocument] = [:]
        for (index, item) in items.enumerated() {
            switch item.sourceType {
            case .pdfPage, .officeDocument:
                let source: PDFDocument
                if let cached = sources[item.sourceURL] {
                    source = cached
                } else {
                    source = try PDFSafeWriter.openReadable(item.sourceURL)
                    sources[item.sourceURL] = source
                }
                guard let page = source.page(at: item.pageIndex), let copy = page.copy() as? PDFPage else {
                    throw PDFStudioError.failed("Page \(item.pageIndex + 1) of “\(item.sourceURL.lastPathComponent)” is no longer available.")
                }
                copy.rotation = normalizedRotation(item.rotation)
                output.insert(copy, at: output.pageCount)
            case .image:
                guard let image = orientedImage(url: item.sourceURL, maxPixel: nil) else {
                    throw PDFStudioError.unreadableFile(item.sourceURL.lastPathComponent)
                }
                let pixelSize = CGSize(width: image.width, height: image.height)
                var target = settings.pageSize == .zero ? imagePointSize(url: item.sourceURL, pixelSize: pixelSize) : settings.pageSize
                if settings.pageSize != .zero, settings.landscape, target.width < target.height {
                    target = CGSize(width: target.height, height: target.width)
                }
                let margin = settings.pageSize == .zero ? 0 : settings.margin
                guard let page = renderImagePage(image, pageSize: target, margin: margin, fitMode: settings.fitMode) else {
                    throw PDFStudioError.failed("Could not render “\(item.sourceURL.lastPathComponent)” into a PDF page.")
                }
                page.rotation = normalizedRotation(item.rotation)
                output.insert(page, at: output.pageCount)
            }
            progress?(index + 1)
        }
        guard output.pageCount == items.count else {
            throw PDFStudioError.failed("Only \(output.pageCount) of \(items.count) pages could be assembled.")
        }
        return output
    }

    // MARK: - Export

    /// Builds and writes the document off the main thread, reporting progress. The output is
    /// written atomically and verified to reopen with the expected page count.
    public func export(to destinationURL: URL) async -> Result<URL, Error> {
        guard !pages.isEmpty else {
            return .failure(PDFStudioError.emptyResult("Add at least one page before exporting."))
        }
        let items = buildItems
        let settings = buildSettings
        isProcessing = true
        currentProgress = 0
        statusMessage = "Assembling \(items.count) page(s)…"
        let total = Double(items.count)

        let result = await Task.detached(priority: .userInitiated) { () -> Result<URL, Error> in
            do {
                let document = try PDFAssemblyService.buildDocument(items: items, settings: settings) { done in
                    Task { @MainActor in
                        PDFAssemblyService.reportProgress(Double(done) / total)
                    }
                }
                try PDFSafeWriter.write(document, to: destinationURL, expectedPageCount: items.count)
                return .success(destinationURL)
            } catch {
                return .failure(error)
            }
        }.value

        isProcessing = false
        currentProgress = 1
        switch result {
        case .success(let url):
            statusMessage = "Exported \(items.count) page(s) to \(url.lastPathComponent)"
        case .failure(let error):
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
        return result
    }

    private static func reportProgress(_ value: Double) {
        for service in workspaces.values where service.isProcessing {
            service.currentProgress = value
        }
        if shared.isProcessing { shared.currentProgress = value }
    }

    /// Synchronous export kept for callers that do not need progress.
    public func exportMergedDocument(to destinationURL: URL? = nil) -> Result<URL, Error> {
        guard !pages.isEmpty else {
            return .failure(PDFStudioError.emptyResult("No pages to assemble."))
        }
        let filename = outputFilename.lowercased().hasSuffix(".pdf") ? outputFilename : "\(outputFilename).pdf"
        guard let targetURL = destinationURL ?? outputDirectory?.appendingPathComponent(filename) else {
            return .failure(PDFStudioError.failed("Choose a destination folder."))
        }
        do {
            let document = try Self.buildDocument(items: buildItems, settings: buildSettings)
            try PDFSafeWriter.write(document, to: targetURL, expectedPageCount: pages.count)
            statusMessage = "Exported \(document.pageCount) pages to \(targetURL.lastPathComponent)"
            return .success(targetURL)
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
            return .failure(error)
        }
    }

    // MARK: - Image Helpers

    /// Full-resolution (or `maxPixel`-limited) image with EXIF orientation applied.
    public nonisolated static func orientedImage(url: URL, maxPixel: Int?) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        let longest = max(width, height)
        guard longest > 0 else { return CGImageSourceCreateImageAtIndex(source, 0, nil) }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(longest, maxPixel ?? longest),
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    nonisolated static func orientedPixelSize(url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        return orientation >= 5 ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }

    /// Page size in points for “Match Image Dimensions”, honoring the image's DPI (72 if absent).
    nonisolated static func imagePointSize(url: URL, pixelSize: CGSize) -> CGSize {
        var dpi: Double = 72
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let value = (properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue, value >= 36 {
            dpi = value
        }
        let scale = CGFloat(72 / dpi)
        return CGSize(width: max(1, pixelSize.width * scale), height: max(1, pixelSize.height * scale))
    }

    nonisolated static func renderImagePage(_ image: CGImage, pageSize: CGSize, margin: CGFloat, fitMode: ImageFitMode) -> PDFPage? {
        let pdfData = NSMutableData()
        var pageRect = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else { return nil }
        context.beginPDFPage(nil)

        let printable = pageRect.insetBy(dx: margin, dy: margin)
        let imageSize = CGSize(width: image.width, height: image.height)
        let drawRect: CGRect
        switch fitMode {
        case .contain, .cover:
            let scale = fitMode == .contain
                ? min(printable.width / imageSize.width, printable.height / imageSize.height)
                : max(printable.width / imageSize.width, printable.height / imageSize.height)
            let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            drawRect = CGRect(x: printable.midX - size.width / 2, y: printable.midY - size.height / 2, width: size.width, height: size.height)
        case .stretch:
            drawRect = printable
        }
        context.saveGState()
        context.clip(to: printable)
        context.interpolationQuality = .high
        context.draw(image, in: drawRect)
        context.restoreGState()
        context.endPDFPage()
        context.closePDF()
        return PDFDocument(data: pdfData as Data)?.page(at: 0)
    }

    // MARK: - Split & Extract

    /// Splits `sourceURL` into separate files. Ranges are validated; output names never overwrite
    /// existing files. Returns the written files.
    public nonisolated static func split(
        sourceURL: URL,
        mode: String,
        interval: Int = 1,
        rangesText: String = "",
        destinationFolder: URL
    ) throws -> [URL] {
        let doc = try PDFSafeWriter.openReadable(sourceURL)
        try PDFSafeWriter.ensureWritableFolder(destinationFolder)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let groups: [(name: String, pages: [Int])]
        switch mode {
        case "each":
            groups = (0..<doc.pageCount).map { ("\(baseName)_page_\($0 + 1)", [$0]) }
        case "interval":
            let step = max(1, interval)
            groups = stride(from: 0, to: doc.pageCount, by: step).enumerated().map { part, start in
                ("\(baseName)_part_\(part + 1)", Array(start..<min(start + step, doc.pageCount)))
            }
        case "range":
            groups = try PDFSafeWriter.parsePageRanges(rangesText, pageCount: doc.pageCount).map { pages in
                let label = pages.count == 1 ? "\(pages[0] + 1)" : "\(pages[0] + 1)-\(pages[pages.count - 1] + 1)"
                return ("\(baseName)_pages_\(label)", pages)
            }
        default:
            throw PDFStudioError.failed("Unknown split mode “\(mode)”.")
        }

        var written: [URL] = []
        for group in groups {
            let part = PDFDocument()
            for pageIndex in group.pages {
                if let copy = doc.page(at: pageIndex)?.copy() as? PDFPage {
                    part.insert(copy, at: part.pageCount)
                }
            }
            let url = PDFSafeWriter.uniqueURL(for: destinationFolder.appendingPathComponent("\(group.name).pdf"))
            try PDFSafeWriter.write(part, to: url, expectedPageCount: group.pages.count)
            written.append(url)
        }
        return written
    }

    /// Writes the pages listed in `pageRangesText` (in the order given) to `destinationURL`.
    @discardableResult
    public nonisolated static func extract(sourceURL: URL, pageRangesText: String, destinationURL: URL) throws -> Int {
        if destinationURL.standardizedFileURL == sourceURL.standardizedFileURL {
            throw PDFStudioError.failed("Choose a different file name. Extracting into the source document would overwrite it.")
        }
        let doc = try PDFSafeWriter.openReadable(sourceURL)
        let indices = try PDFSafeWriter.parsePageRanges(pageRangesText, pageCount: doc.pageCount).flatMap { $0 }
        let output = PDFDocument()
        for pageIndex in indices {
            if let copy = doc.page(at: pageIndex)?.copy() as? PDFPage {
                output.insert(copy, at: output.pageCount)
            }
        }
        try PDFSafeWriter.write(output, to: destinationURL, expectedPageCount: indices.count)
        return indices.count
    }

    // Backwards-compatible wrappers.

    public func splitDocument(
        sourceURL: URL,
        splitMode: String,
        splitInterval: Int = 1,
        splitRangesText: String = "",
        destinationFolder: URL
    ) -> [URL] {
        (try? Self.split(sourceURL: sourceURL, mode: splitMode, interval: splitInterval, rangesText: splitRangesText, destinationFolder: destinationFolder)) ?? []
    }

    public func extractPages(sourceURL: URL, pageRangesText: String, destinationURL: URL) -> Bool {
        (try? Self.extract(sourceURL: sourceURL, pageRangesText: pageRangesText, destinationURL: destinationURL)) != nil
    }
}
