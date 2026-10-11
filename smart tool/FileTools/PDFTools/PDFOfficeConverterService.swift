//
//  PDFOfficeConverterService.swift
//  Borno Pulse
//
//  Offline document to PDF conversion.
//  • Native (always available): DOCX, DOC, ODT, RTF, RTFD, TXT, HTML and Markdown via the
//    macOS text system, paginated with TextKit so embedded images and fonts are kept.
//  • Optional: if LibreOffice is installed, it is used for higher-fidelity Word/OpenDocument
//    conversion and to add PowerPoint/Excel support.
//

import AppKit
import Foundation
import PDFKit

@MainActor
public final class PDFOfficeConverterService: ObservableObject {
    public static let shared = PDFOfficeConverterService()

    public static let nativeExtensions: Set<String> = ["docx", "doc", "odt", "rtf", "rtfd", "txt", "text", "html", "htm", "md", "markdown"]
    public static let libreOfficeOnlyExtensions: Set<String> = ["pptx", "ppt", "odp", "xlsx", "xls", "ods"]
    public static let libreOfficePreferredExtensions: Set<String> = ["docx", "doc", "odt"]
    public static let letterPageSize = CGSize(width: 612, height: 792)

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
        libreOfficePath() != nil
    }

    public static func libreOfficePath() -> String? {
        [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            "/usr/local/bin/soffice",
            "/opt/homebrew/bin/soffice"
        ].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public var supportedExtensions: Set<String> {
        isLibreOfficeAvailable ? Self.nativeExtensions.union(Self.libreOfficeOnlyExtensions) : Self.nativeExtensions
    }

    public func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Conversion

    public func convertDocument(from url: URL, to destinationURL: URL) async -> Result<URL, Error> {
        let ext = url.pathExtension.lowercased()
        guard isSupported(url) else {
            let hint = Self.libreOfficeOnlyExtensions.contains(ext)
                ? "Install LibreOffice to convert .\(ext) files offline."
                : "Supported: \(supportedExtensions.sorted().map { ".\($0)" }.joined(separator: ", "))."
            return .failure(PDFStudioError.unsupportedFormat(".\(ext). \(hint)"))
        }
        if destinationURL.standardizedFileURL == url.standardizedFileURL {
            return .failure(PDFStudioError.failed("Choose a different destination file."))
        }
        isProcessing = true
        currentProgress = 0.1
        statusMessage = "Reading \(url.lastPathComponent)…"
        defer {
            isProcessing = false
            currentProgress = 1
        }

        if let soffice = Self.libreOfficePath(),
           Self.libreOfficePreferredExtensions.union(Self.libreOfficeOnlyExtensions).contains(ext) {
            statusMessage = "Converting with LibreOffice…"
            currentProgress = 0.4
            let result = await Task.detached(priority: .userInitiated) {
                Self.convertWithLibreOffice(soffice: soffice, source: url, destination: destinationURL)
            }.value
            if case .success = result {
                statusMessage = "Converted \(url.lastPathComponent) to \(destinationURL.lastPathComponent)"
                return result
            }
            if Self.libreOfficeOnlyExtensions.contains(ext) { return result }
            statusMessage = "LibreOffice failed; using the macOS text system…"
        }

        do {
            let attributed = try Self.loadAttributedString(from: url)
            currentProgress = 0.6
            statusMessage = "Paginating…"
            guard let data = Self.renderPDF(attributed, pageSize: Self.letterPageSize, margin: 54) else {
                throw PDFStudioError.failed("The document could not be laid out into pages.")
            }
            try PDFSafeWriter.write(data: data, to: destinationURL)
            let pages = PDFDocument(url: destinationURL)?.pageCount ?? 0
            statusMessage = "Converted \(url.lastPathComponent) to a \(pages)-page PDF"
            return .success(destinationURL)
        } catch {
            statusMessage = "Conversion failed: \(error.localizedDescription)"
            return .failure(error)
        }
    }

    /// Synchronous conversion using the native engine only (kept for existing callers).
    @discardableResult
    public func convertOfficeDocument(from url: URL, to destinationURL: URL? = nil) -> Result<URL, Error> {
        let outDir = destinationURL?.deletingLastPathComponent() ?? outputDirectory ?? FileManager.default.temporaryDirectory
        let target = destinationURL ?? outDir.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent).pdf")
        guard Self.nativeExtensions.contains(url.pathExtension.lowercased()) else {
            return .failure(PDFStudioError.unsupportedFormat(".\(url.pathExtension)"))
        }
        do {
            let attributed = try Self.loadAttributedString(from: url)
            guard let data = Self.renderPDF(attributed, pageSize: Self.letterPageSize, margin: 54) else {
                throw PDFStudioError.failed("The document could not be laid out into pages.")
            }
            try PDFSafeWriter.write(data: data, to: target)
            return .success(target)
        } catch {
            return .failure(error)
        }
    }

    public static func loadAttributedString(from url: URL) throws -> NSAttributedString {
        let ext = url.pathExtension.lowercased()
        let documentType: NSAttributedString.DocumentType?
        switch ext {
        case "docx": documentType = .officeOpenXML
        case "doc": documentType = .docFormat
        case "odt": documentType = .openDocument
        case "rtf": documentType = .rtf
        case "rtfd": documentType = .rtfd
        case "html", "htm": documentType = .html
        default: documentType = nil
        }

        let result: NSAttributedString
        if let documentType {
            do {
                result = try NSAttributedString(url: url, options: [.documentType: documentType], documentAttributes: nil)
            } catch {
                throw PDFStudioError.unreadableFile(url.lastPathComponent)
            }
        } else {
            guard let text = readPlainText(url) else {
                throw PDFStudioError.unreadableFile(url.lastPathComponent)
            }
            if ext == "md" || ext == "markdown" {
                result = markdownAttributedString(text)
            } else {
                result = NSAttributedString(string: text, attributes: [
                    .font: NSFont(name: "Menlo", size: 10.5) ?? NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
                    .foregroundColor: NSColor.black
                ])
            }
        }
        guard result.length > 0, !result.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || result.containsAttachments(in: NSRange(location: 0, length: result.length)) else {
            throw PDFStudioError.emptyResult("“\(url.lastPathComponent)” contains no printable content.")
        }
        return result
    }

    private static func readPlainText(_ url: URL) -> String? {
        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        var encoding = String.Encoding.utf8
        return try? String(contentsOf: url, usedEncoding: &encoding)
    }

    // MARK: - Markdown

    /// Converts Markdown into styled text (headings, emphasis, code, lists, quotes) for printing.
    public static func markdownAttributedString(_ markdown: String) -> NSAttributedString {
        let bodyFont = NSFont(name: "Helvetica", size: 11.5) ?? NSFont.systemFont(ofSize: 11.5)
        let output = NSMutableAttributedString()
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return NSAttributedString(string: markdown, attributes: [.font: bodyFont, .foregroundColor: NSColor.black])
        }

        var lastBlockID: Int?
        for run in parsed.runs {
            let text = String(parsed[run.range].characters)
            let intent = run.presentationIntent
            let components = intent?.components ?? []
            let blockID = components.first?.identity

            let isNewBlock = blockID != lastBlockID || output.length == 0
            if lastBlockID != nil, blockID != lastBlockID {
                output.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont]))
            }
            lastBlockID = blockID

            var font = bodyFont
            var color = NSColor.black
            let paragraph = NSMutableParagraphStyle()
            paragraph.paragraphSpacing = 6
            var prefix = ""

            for component in components {
                switch component.kind {
                case .header(let level):
                    let sizes: [CGFloat] = [22, 18, 15, 13, 12, 11.5]
                    font = NSFont(name: "Helvetica-Bold", size: sizes[min(max(level, 1), 6) - 1]) ?? NSFont.boldSystemFont(ofSize: 14)
                    paragraph.paragraphSpacingBefore = 8
                case .codeBlock:
                    font = NSFont(name: "Menlo", size: 10) ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
                    paragraph.headIndent = 12
                    paragraph.firstLineHeadIndent = 12
                case .blockQuote:
                    color = NSColor(white: 0.3, alpha: 1)
                    paragraph.headIndent = 18
                    paragraph.firstLineHeadIndent = 18
                case .listItem(let ordinal):
                    let isOrdered = components.contains { if case .orderedList = $0.kind { return true } else { return false } }
                    if isNewBlock {
                        prefix = isOrdered ? "\(ordinal). " : "• "
                    }
                    paragraph.headIndent = 18
                    paragraph.firstLineHeadIndent = 4
                default:
                    break
                }
            }

            if let inline = run.inlinePresentationIntent {
                var traits: NSFontDescriptor.SymbolicTraits = []
                if inline.contains(.stronglyEmphasized) { traits.insert(.bold) }
                if inline.contains(.emphasized) { traits.insert(.italic) }
                if inline.contains(.code) {
                    font = NSFont(name: "Menlo", size: font.pointSize - 1) ?? NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
                } else if !traits.isEmpty {
                    let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits))
                    font = NSFont(descriptor: descriptor, size: font.pointSize) ?? font
                }
            }

            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
            if let link = run.link {
                attributes[.link] = link
                attributes[.foregroundColor] = NSColor(srgbRed: 0.05, green: 0.3, blue: 0.8, alpha: 1)
            }
            output.append(NSAttributedString(string: prefix + text, attributes: attributes))
        }
        return output
    }

    // MARK: - Pagination

    /// Lays out `attributed` with TextKit page by page and draws it into a PDF.
    public static func renderPDF(_ attributed: NSAttributedString, pageSize: CGSize, margin: CGFloat) -> Data? {
        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let contentSize = CGSize(width: pageSize.width - margin * 2, height: pageSize.height - margin * 2)

        var containers: [NSTextContainer] = []
        while true {
            let container = NSTextContainer(size: contentSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            containers.append(container)
            let range = layoutManager.glyphRange(for: container)
            if NSMaxRange(range) >= layoutManager.numberOfGlyphs || range.length == 0 || containers.count > 5000 {
                if range.length == 0, containers.count > 1 {
                    layoutManager.removeTextContainer(at: containers.count - 1)
                    containers.removeLast()
                }
                break
            }
        }

        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        for container in containers {
            context.beginPDFPage(nil)
            context.saveGState()
            context.translateBy(x: 0, y: pageSize.height)
            context.scaleBy(x: 1, y: -1)
            let graphics = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphics
            let glyphRange = layoutManager.glyphRange(for: container)
            let origin = CGPoint(x: margin, y: margin)
            layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
        return containers.isEmpty ? nil : data as Data
    }

    // MARK: - LibreOffice

    nonisolated static func convertWithLibreOffice(soffice: String, source: URL, destination: URL) -> Result<URL, Error> {
        let workFolder = FileManager.default.temporaryDirectory.appendingPathComponent("BornoOffice-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workFolder) }
        do {
            try FileManager.default.createDirectory(at: workFolder, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: soffice)
            process.arguments = ["--headless", "--norestore", "--convert-to", "pdf", "--outdir", workFolder.path, source.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            let deadline = Date().addingTimeInterval(180)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
            if process.isRunning {
                process.terminate()
                throw PDFStudioError.failed("LibreOffice did not finish within 3 minutes.")
            }
            let generated = workFolder.appendingPathComponent("\(source.deletingPathExtension().lastPathComponent).pdf")
            guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: generated.path) else {
                throw PDFStudioError.failed("LibreOffice could not convert “\(source.lastPathComponent)”.")
            }
            try PDFSafeWriter.install(generatedFile: generated, at: destination)
            return .success(destination)
        } catch {
            return .failure(error)
        }
    }
}
