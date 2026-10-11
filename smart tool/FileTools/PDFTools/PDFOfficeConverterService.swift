//
//  PDFOfficeConverterService.swift
//  Borno Pulse
//
//  Offline Word, RTF, Markdown, HTML, and Text to PDF converter engine.
//

import AppKit
import Foundation
import PDFKit

@MainActor
public final class PDFOfficeConverterService: ObservableObject {
    public static let shared = PDFOfficeConverterService()

    @Published public var isProcessing: Bool = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    @Published public var isLibreOfficeAvailable: Bool = false
    @Published public var outputDirectory: URL?

    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        self.isLibreOfficeAvailable = Self.checkLibreOfficeAvailable()
    }

    public static func checkLibreOfficeAvailable() -> Bool {
        let paths = [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            "/usr/local/bin/soffice",
            "/opt/homebrew/bin/soffice"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    public static func libreOfficePath() -> String? {
        let paths = [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            "/usr/local/bin/soffice",
            "/opt/homebrew/bin/soffice"
        ]
        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }

    @discardableResult
    public func convertOfficeDocument(from url: URL, to destinationURL: URL? = nil) -> Result<URL, Error> {
        isProcessing = true
        currentProgress = 0.2
        statusMessage = "Analyzing document structure..."

        let ext = url.pathExtension.lowercased()
        let outDir = destinationURL?.deletingLastPathComponent() ?? outputDirectory ?? FileManager.default.temporaryDirectory
        let baseName = url.deletingPathExtension().lastPathComponent
        let outURL = destinationURL ?? outDir.appendingPathComponent("\(baseName).pdf")

        defer {
            isProcessing = false
            currentProgress = 1.0
        }

        // 1. RTF / RTFD / TXT / HTML / Markdown
        if ["rtf", "rtfd", "txt", "html", "htm", "md", "markdown"].contains(ext) {
            currentProgress = 0.5
            statusMessage = "Rendering document to PDF..."
            return renderTextBasedDocument(url: url, outputURL: outURL)
        }

        // 2. DOCX
        if ext == "docx" || ext == "doc" {
            if let soffice = Self.libreOfficePath() {
                statusMessage = "Converting via local LibreOffice engine..."
                let process = Process()
                process.executableURL = URL(fileURLWithPath: soffice)
                process.arguments = ["--headless", "--convert-to", "pdf", url.path, "--outdir", outDir.path]
                do {
                    try process.run()
                    process.waitUntilExit()
                    let generatedURL = outDir.appendingPathComponent("\(baseName).pdf")
                    if FileManager.default.fileExists(atPath: generatedURL.path) {
                        if generatedURL != outURL {
                            try? FileManager.default.moveItem(at: generatedURL, to: outURL)
                        }
                        statusMessage = "Converted \(baseName).\(ext) to PDF"
                        return .success(outURL)
                    }
                } catch {
                    // Fallback to native TextKit
                }
            }

            statusMessage = "Converting via native macOS text system..."
            return renderTextBasedDocument(url: url, outputURL: outURL)
        }

        statusMessage = "Unsupported office document format: .\(ext)"
        return .failure(NSError(domain: "PDFOfficeConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported document format: .\(ext)"]))
    }

    public func convertFile(url: URL) async -> Result<URL, Error> {
        return convertOfficeDocument(from: url)
    }

    private func renderTextBasedDocument(url: URL, outputURL: URL) -> Result<URL, Error> {
        let ext = url.pathExtension.lowercased()
        var attributedString: NSAttributedString?

        if ext == "txt" || ext == "md" || ext == "markdown" {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                let font = NSFont.systemFont(ofSize: 13)
                attributedString = NSAttributedString(string: text, attributes: [.font: font])
            }
        } else if ext == "rtf" {
            attributedString = try? NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        } else if ext == "rtfd" {
            attributedString = try? NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)
        } else if ext == "html" || ext == "htm" {
            attributedString = try? NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil)
        } else if ext == "docx" {
            // Native WordML / DOCX parsing
            attributedString = try? NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.wordML], documentAttributes: nil)
            if attributedString == nil {
                // Secondary attempt via generic options
                attributedString = try? NSAttributedString(url: url, options: [:], documentAttributes: nil)
            }
        }

        guard let attr = attributedString, attr.length > 0 else {
            statusMessage = "Unable to extract printable content from \(url.lastPathComponent)."
            return .failure(NSError(domain: "PDFOfficeConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not read formatted content."]))
        }

        // Render to paginated PDF
        let pdfData = NSMutableData()
        var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let margin: CGFloat = 40.0
        let contentRect = pageRect.insetBy(dx: margin, dy: margin)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return .failure(NSError(domain: "PDFOfficeConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed creating PDF context."]))
        }

        let framesetter = CTFramesetterCreateWithAttributedString(attr as CFAttributedString)
        var textRange = CFRangeMake(0, 0)
        let totalLength = attr.length

        while textRange.location < totalLength {
            context.beginPDFPage(nil)

            let path = CGPath(rect: contentRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, textRange, path, nil)
            CTFrameDraw(frame, context)

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            if visibleRange.length == 0 { break }
            textRange.location += visibleRange.length

            context.endPDFPage()
        }

        context.closePDF()

        do {
            try (pdfData as Data).write(to: outputURL)
            statusMessage = "Successfully converted to \(outputURL.lastPathComponent)"
            return .success(outputURL)
        } catch {
            return .failure(error)
        }
    }
}
