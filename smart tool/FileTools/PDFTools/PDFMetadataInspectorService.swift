//
//  PDFMetadataInspectorService.swift
//  Borno Pulse
//
//  PDF metadata inspection, editing, and privacy sanitization engine.
//

import AppKit
import Foundation
import PDFKit

public struct PDFDetailedMetadata: Sendable {
    public var title: String?
    public var author: String?
    public var subject: String?
    public var creator: String?
    public var producer: String?
    public var keywords: [String] = []
    public var creationDate: Date?
    public var modificationDate: Date?
    public var pageCount: Int = 0
    public var fileSize: UInt64 = 0
    public var isEncrypted: Bool = false
    public var allowsPrinting: Bool = true
    public var allowsCopying: Bool = true

    public init() {}
}

@MainActor
public final class PDFMetadataInspectorService: ObservableObject {
    public static let shared = PDFMetadataInspectorService()

    @Published public var sourceURL: URL?
    @Published public var document: PDFDocument?
    @Published public var metadata: PDFDetailedMetadata = PDFDetailedMetadata()
    @Published public var statusMessage: String = "No PDF inspected"
    @Published public var isProcessing: Bool = false

    public init() {}

    public func inspectDocument(url: URL) {
        guard let doc = PDFDocument(url: url) else {
            statusMessage = "Cannot open PDF at \(url.lastPathComponent)"
            return
        }

        self.sourceURL = url
        self.document = doc

        var meta = PDFDetailedMetadata()
        meta.pageCount = doc.pageCount
        meta.isEncrypted = doc.isLocked
        meta.allowsPrinting = doc.allowsPrinting
        meta.allowsCopying = doc.allowsCopying

        if let attrs = doc.documentAttributes {
            meta.title = attrs[PDFDocumentAttribute.titleAttribute] as? String
            meta.author = attrs[PDFDocumentAttribute.authorAttribute] as? String
            meta.subject = attrs[PDFDocumentAttribute.subjectAttribute] as? String
            meta.creator = attrs[PDFDocumentAttribute.creatorAttribute] as? String
            meta.producer = attrs[PDFDocumentAttribute.producerAttribute] as? String
            meta.creationDate = attrs[PDFDocumentAttribute.creationDateAttribute] as? Date
            meta.modificationDate = attrs[PDFDocumentAttribute.modificationDateAttribute] as? Date

            if let kw = attrs[PDFDocumentAttribute.keywordsAttribute] as? [String] {
                meta.keywords = kw
            } else if let kwStr = attrs[PDFDocumentAttribute.keywordsAttribute] as? String {
                meta.keywords = kwStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }

        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        meta.fileSize = UInt64(size)

        self.metadata = meta
        self.statusMessage = "Inspected \(url.lastPathComponent) (\(doc.pageCount) pages)"
    }

    public func sanitizeAndExport(to destinationURL: URL) -> Bool {
        guard let doc = document else { return false }

        // Strip metadata dictionary
        let sanitizedAttrs: [PDFDocumentAttribute: Any] = [
            PDFDocumentAttribute.titleAttribute: "",
            PDFDocumentAttribute.authorAttribute: "",
            PDFDocumentAttribute.subjectAttribute: "",
            PDFDocumentAttribute.creatorAttribute: "Borno Pulse (Sanitized)",
            PDFDocumentAttribute.producerAttribute: "Native macOS PDFKit",
            PDFDocumentAttribute.keywordsAttribute: []
        ]
        doc.documentAttributes = sanitizedAttrs

        let success = doc.write(to: destinationURL)
        if success {
            statusMessage = "Exported sanitized copy without tracking metadata to \(destinationURL.lastPathComponent)"
        }
        return success
    }

    public func inspect(url: URL) -> PDFDetailedMetadata {
        inspectDocument(url: url)
        return metadata
    }

    public func sanitizeMetadata(sourceURL: URL, destinationURL: URL) -> Bool {
        inspectDocument(url: sourceURL)
        return sanitizeAndExport(to: destinationURL)
    }
}
