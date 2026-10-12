//
//  PDFOCRService.swift
//  Borno Pulse
//
//  On-device Apple Vision text recognition and searchable-PDF generation.
//
//  Searchable PDFs keep each page's original vector content and add an invisible text layer
//  positioned on Vision's line bounding boxes, so search/selection lines up with the visible
//  text. Pages that already contain a text layer are copied unchanged, never duplicated.
//

import AppKit
import CoreText
import Foundation
import PDFKit
import Vision

public struct PDFOCRLine: Sendable {
    public let text: String
    /// Normalized (0...1) bounding box, origin bottom-left, as returned by Vision.
    public let boundingBox: CGRect
}

public struct PDFSearchableReport: Sendable {
    public let outputURL: URL
    public let recognizedPages: Int
    public let preservedTextPages: Int
    public let recognizedLines: Int
}

@MainActor
public final class PDFOCRService: ObservableObject {
    public static let shared = PDFOCRService()
    public nonisolated static let automaticLanguage = "Automatic"

    @Published public var isProcessing: Bool = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    @Published public var recognizedText: String = ""
    @Published public var selectedLanguage: String = "en-US"
    @Published public var supportedLanguages: [String] = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "zh-Hans", "ja-JP"]
    @Published public var forceOCROnTextPages: Bool = false

    private var task: Task<Void, Never>?
    private var hasLoadedSupportedLanguages = false

    public init() {}

    public func loadSupportedLanguagesIfNeeded() {
        guard !hasLoadedSupportedLanguages else { return }
        hasLoadedSupportedLanguages = true
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        if let languages = try? request.supportedRecognitionLanguages(), !languages.isEmpty {
            supportedLanguages = languages
        }
    }

    public var languageChoices: [String] {
        loadSupportedLanguagesIfNeeded()
        return [Self.automaticLanguage] + supportedLanguages
    }

    // MARK: - Vision

    public nonisolated static func recognize(_ image: CGImage, language: String) throws -> [PDFOCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if language == automaticLanguage {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = [language]
        }
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : PDFOCRLine(text: text, boundingBox: observation.boundingBox)
        }
    }

    // MARK: - Text Extraction

    public func extractText(from url: URL) {
        guard !isProcessing else { return }
        let language = selectedLanguage
        let force = forceOCROnTextPages
        isProcessing = true
        recognizedText = ""
        currentProgress = 0
        statusMessage = "Preparing…"

        task = Task { [weak self] in
            guard let self else { return }
            do {
                if url.pathExtension.lowercased() == "pdf" {
                    let doc = try PDFSafeWriter.openReadable(url)
                    var sections: [String] = []
                    var ocrPages = 0
                    for index in 0..<doc.pageCount {
                        if Task.isCancelled { throw PDFStudioError.cancelled }
                        self.statusMessage = "Reading page \(index + 1) of \(doc.pageCount)…"
                        self.currentProgress = Double(index) / Double(doc.pageCount)
                        let existing = doc.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let text: String
                        if !existing.isEmpty && !force {
                            text = existing
                        } else {
                            ocrPages += 1
                            text = try await Task.detached(priority: .userInitiated) { () throws -> String in
                                guard let page = PDFDocument(url: url)?.page(at: index),
                                      let image = PDFToImagesService.renderImage(of: page, dpi: 200) else { return "" }
                                return try PDFOCRService.recognize(image, language: language).map(\.text).joined(separator: "\n")
                            }.value
                        }
                        if !text.isEmpty { sections.append("--- Page \(index + 1) ---\n\(text)") }
                    }
                    self.recognizedText = sections.joined(separator: "\n\n")
                    self.statusMessage = self.recognizedText.isEmpty
                        ? "No text was found in this document."
                        : "Extracted text from \(doc.pageCount) page(s) (\(ocrPages) recognized with OCR, \(doc.pageCount - ocrPages) from the existing text layer)."
                } else {
                    let text = try await Task.detached(priority: .userInitiated) { () throws -> String in
                        guard let image = PDFAssemblyService.orientedImage(url: url, maxPixel: 4000) else {
                            throw PDFStudioError.unreadableFile(url.lastPathComponent)
                        }
                        return try PDFOCRService.recognize(image, language: language).map(\.text).joined(separator: "\n")
                    }.value
                    self.recognizedText = text
                    self.statusMessage = text.isEmpty ? "No text was recognized in this image." : "Recognized \(text.split(separator: "\n").count) line(s)."
                }
            } catch {
                self.statusMessage = "Text extraction failed: \(error.localizedDescription)"
            }
            self.isProcessing = false
            self.currentProgress = 1
        }
    }

    public func cancel() {
        task?.cancel()
    }

    // MARK: - Searchable PDF

    public func makeSearchablePDF(from sourceURL: URL, to destinationURL: URL) async -> Result<PDFSearchableReport, Error> {
        guard !isProcessing else { return .failure(PDFStudioError.failed("OCR is already running.")) }
        if destinationURL.standardizedFileURL == sourceURL.standardizedFileURL {
            return .failure(PDFStudioError.failed("Choose a different file name. The searchable PDF is saved as a new file and never replaces the original."))
        }
        let language = selectedLanguage
        let force = forceOCROnTextPages
        isProcessing = true
        currentProgress = 0
        statusMessage = "Creating searchable PDF…"
        defer {
            isProcessing = false
            currentProgress = 1
        }
        do {
            let report = try await Task.detached(priority: .userInitiated) { () throws -> PDFSearchableReport in
                try PDFOCRService.buildSearchablePDF(source: sourceURL, destination: destinationURL, language: language, forceOCR: force) { done, total in
                    Task { @MainActor in
                        PDFOCRService.shared.currentProgress = Double(done) / Double(max(1, total))
                        PDFOCRService.shared.statusMessage = "Recognizing page \(min(done + 1, total)) of \(total)…"
                    }
                }
            }.value
            statusMessage = "Searchable PDF saved: \(report.recognizedPages) page(s) recognized, \(report.preservedTextPages) page(s) already had text and were kept unchanged."
            return .success(report)
        } catch {
            statusMessage = "Searchable PDF failed: \(error.localizedDescription)"
            return .failure(error)
        }
    }

    public nonisolated static func buildSearchablePDF(
        source: URL,
        destination: URL,
        language: String,
        forceOCR: Bool,
        progress: ((Int, Int) -> Void)? = nil
    ) throws -> PDFSearchableReport {
        if source.standardizedFileURL == destination.standardizedFileURL {
            throw PDFStudioError.failed("Choose a different file name. The searchable PDF is saved as a new file.")
        }
        let output = PDFDocument()
        var recognizedPages = 0
        var preservedPages = 0
        var lineCount = 0

        if source.pathExtension.lowercased() == "pdf" {
            let doc = try PDFSafeWriter.openReadable(source)
            for index in 0..<doc.pageCount {
                progress?(index, doc.pageCount)
                guard let page = doc.page(at: index) else { continue }
                let hasText = !(page.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                if hasText && !forceOCR {
                    if let copy = page.copy() as? PDFPage { output.insert(copy, at: output.pageCount) }
                    preservedPages += 1
                    continue
                }
                guard let image = PDFToImagesService.renderImage(of: page, dpi: 200) else {
                    throw PDFStudioError.failed("Page \(index + 1) could not be rendered for recognition.")
                }
                let lines = try recognize(image, language: language)
                let size = PDFEditorGeometry.displayedPageSize(page.bounds(for: .cropBox).size, rotation: page.rotation)
                guard let newPage = makePage(size: size, lines: lines, drawContent: { context in
                    page.draw(with: .cropBox, to: context)
                }) else {
                    throw PDFStudioError.failed("Page \(index + 1) could not be rebuilt.")
                }
                output.insert(newPage, at: output.pageCount)
                recognizedPages += 1
                lineCount += lines.count
            }
            progress?(doc.pageCount, doc.pageCount)
        } else {
            guard let image = PDFAssemblyService.orientedImage(url: source, maxPixel: nil) else {
                throw PDFStudioError.unreadableFile(source.lastPathComponent)
            }
            let lines = try recognize(image, language: language)
            let size = PDFAssemblyService.imagePointSize(url: source, pixelSize: CGSize(width: image.width, height: image.height))
            guard let page = makePage(size: size, lines: lines, drawContent: { context in
                context.interpolationQuality = .high
                context.draw(image, in: CGRect(origin: .zero, size: size))
            }) else {
                throw PDFStudioError.failed("The image could not be converted.")
            }
            output.insert(page, at: 0)
            recognizedPages = 1
            lineCount = lines.count
            progress?(1, 1)
        }

        try PDFSafeWriter.write(output, to: destination, expectedPageCount: output.pageCount)
        return PDFSearchableReport(outputURL: destination, recognizedPages: recognizedPages, preservedTextPages: preservedPages, recognizedLines: lineCount)
    }

    /// Draws the visible content, then each recognized line as invisible text fitted to its box.
    nonisolated static func makePage(size: CGSize, lines: [PDFOCRLine], drawContent: (CGContext) -> Void) -> PDFPage? {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: size)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        context.beginPDFPage(nil)
        context.saveGState()
        drawContent(context)
        context.restoreGState()

        context.saveGState()
        context.setTextDrawingMode(.invisible)
        for line in lines {
            let box = CGRect(
                x: line.boundingBox.minX * size.width,
                y: line.boundingBox.minY * size.height,
                width: line.boundingBox.width * size.width,
                height: line.boundingBox.height * size.height
            )
            guard box.width > 1, box.height > 1 else { continue }
            let fontSize = max(1, box.height * 0.82)
            let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
            let attributed = NSAttributedString(string: line.text, attributes: [.font: font])
            let ctLine = CTLineCreateWithAttributedString(attributed)
            let naturalWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
            guard naturalWidth > 0 else { continue }
            context.textMatrix = CGAffineTransform(scaleX: box.width / naturalWidth, y: 1)
            context.textPosition = CGPoint(x: box.minX, y: box.minY + box.height * 0.18)
            CTLineDraw(ctLine, context)
        }
        context.restoreGState()
        context.endPDFPage()
        context.closePDF()
        return PDFDocument(data: data as Data)?.page(at: 0)
    }
}
