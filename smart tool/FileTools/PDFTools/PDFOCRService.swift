//
//  PDFOCRService.swift
//  Borno Pulse
//
//  On-device Apple Vision text recognition and Searchable PDF generator engine.
//

import AppKit
import Foundation
import PDFKit
import Vision

@MainActor
public final class PDFOCRService: ObservableObject {
    public static let shared = PDFOCRService()

    @Published public var isProcessing: Bool = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    @Published public var recognizedText: String = ""
    @Published public var selectedLanguage: String = "en-US"
    @Published public var supportedLanguages: [String] = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "zh-Hans", "ja-JP"]

    public init() {
        let req = VNRecognizeTextRequest()
        if let langs = try? req.supportedRecognitionLanguages() {
            self.supportedLanguages = langs
        }
    }

    // MARK: - Recognize Text from Image
    public func recognizeText(from image: NSImage) async -> Result<String, Error> {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .failure(NSError(domain: "PDFOCRService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image format for OCR."]))
        }

        isProcessing = true
        currentProgress = 0.3
        statusMessage = "Analyzing text with Apple Vision engine..."

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { [weak self] req, err in
                Task { @MainActor in
                    self?.isProcessing = false
                    self?.currentProgress = 1.0

                    if let error = err {
                        self?.statusMessage = "OCR error: \(error.localizedDescription)"
                        continuation.resume(returning: .failure(error))
                        return
                    }

                    guard let observations = req.results as? [VNRecognizedTextObservation] else {
                        self?.statusMessage = "No text recognized."
                        continuation.resume(returning: .success(""))
                        return
                    }

                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    let fullText = lines.joined(separator: "\n")
                    self?.recognizedText = fullText
                    self?.statusMessage = "Recognized \(lines.count) text lines"
                    continuation.resume(returning: .success(fullText))
                }
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = [self.selectedLanguage]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                self.isProcessing = false
                self.statusMessage = "Failed executing OCR request: \(error.localizedDescription)"
                continuation.resume(returning: .failure(error))
            }
        }
    }

    // MARK: - Recognize Text from PDF Document
    public func recognizeText(from pdfURL: URL) async -> Result<String, Error> {
        guard let doc = PDFDocument(url: pdfURL) else {
            return .failure(NSError(domain: "PDFOCRService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to open PDF document."]))
        }

        isProcessing = true
        currentProgress = 0.0
        statusMessage = "Performing OCR across \(doc.pageCount) pages..."

        var allPageTexts: [String] = []

        for i in 0..<doc.pageCount {
            currentProgress = Double(i) / Double(doc.pageCount)
            statusMessage = "Recognizing text on page \(i + 1) of \(doc.pageCount)..."

            guard let page = doc.page(at: i) else { continue }
            let pageSize = page.bounds(for: .mediaBox).size
            let img = page.thumbnail(of: CGSize(width: pageSize.width * 2, height: pageSize.height * 2), for: .mediaBox)

            if case .success(let pageText) = await recognizeText(from: img), !pageText.isEmpty {
                allPageTexts.append("--- Page \(i + 1) ---\n" + pageText)
            }
        }

        let combined = allPageTexts.joined(separator: "\n\n")
        self.recognizedText = combined
        self.isProcessing = false
        self.currentProgress = 1.0
        self.statusMessage = "Completed OCR across \(doc.pageCount) pages"
        return .success(combined)
    }

    // MARK: - Generate Searchable PDF
    public func generateSearchablePDF(from sourceURL: URL, outputURL: URL) async -> Result<URL, Error> {
        let ext = sourceURL.pathExtension.lowercased()
        if ext == "pdf" {
            guard let doc = PDFDocument(url: sourceURL) else {
                return .failure(NSError(domain: "PDFOCRService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot open PDF."]))
            }

            let searchableDoc = PDFDocument()

            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let pageSize = page.bounds(for: .mediaBox).size
                let img = page.thumbnail(of: CGSize(width: pageSize.width * 2, height: pageSize.height * 2), for: .mediaBox)

                // Recognize text
                if case .success(let text) = await recognizeText(from: img) {
                    // Create page with original image and invisible searchable text annotations
                    if let newPage = createSearchablePage(image: img, text: text, size: pageSize) {
                        searchableDoc.insert(newPage, at: searchableDoc.pageCount)
                    } else {
                        searchableDoc.insert(page, at: searchableDoc.pageCount)
                    }
                } else {
                    searchableDoc.insert(page, at: searchableDoc.pageCount)
                }
            }

            if searchableDoc.write(to: outputURL) {
                statusMessage = "Created Searchable PDF at \(outputURL.lastPathComponent)"
                return .success(outputURL)
            }
        } else {
            // Image source
            guard let img = NSImage(contentsOf: sourceURL) else {
                return .failure(NSError(domain: "PDFOCRService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot open image."]))
            }
            if case .success(let text) = await recognizeText(from: img) {
                let searchableDoc = PDFDocument()
                if let newPage = createSearchablePage(image: img, text: text, size: img.size) {
                    searchableDoc.insert(newPage, at: 0)
                    if searchableDoc.write(to: outputURL) {
                        return .success(outputURL)
                    }
                }
            }
        }

        return .failure(NSError(domain: "PDFOCRService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed generating searchable PDF."]))
    }

    // MARK: - Convenience Wrappers
    public func performOCR(url: URL, languages: [String] = []) {
        if let first = languages.first {
            self.selectedLanguage = first
        }
        let ext = url.pathExtension.lowercased()
        Task {
            if ext == "pdf" {
                _ = await recognizeText(from: url)
            } else if let img = NSImage(contentsOf: url) {
                _ = await recognizeText(from: img)
            }
        }
    }

    public func createSearchablePDF(
        from sourceURL: URL,
        destinationURL: URL,
        languages: [String] = [],
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if let first = languages.first {
            self.selectedLanguage = first
        }
        Task {
            let res = await generateSearchablePDF(from: sourceURL, outputURL: destinationURL)
            completion(res)
        }
    }

    private func createSearchablePage(image: NSImage, text: String, size: CGSize) -> PDFPage? {
        let pdfData = NSMutableData()
        var pageRect = CGRect(origin: .zero, size: size)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return nil
        }

        context.beginPDFPage(nil)

        // Draw original scan
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: pageRect)
        }

        context.endPDFPage()
        context.closePDF()

        guard let renderedDoc = PDFDocument(data: pdfData as Data), let page = renderedDoc.page(at: 0) else {
            return nil
        }

        // Overlay transparent text annotation to make page text selectable & searchable
        let textAnnot = PDFAnnotation(bounds: pageRect, forType: .freeText, withProperties: nil)
        textAnnot.contents = text
        textAnnot.font = NSFont.systemFont(ofSize: 12)
        textAnnot.fontColor = NSColor.clear
        textAnnot.color = NSColor.clear
        page.addAnnotation(textAnnot)

        return page
    }
}
