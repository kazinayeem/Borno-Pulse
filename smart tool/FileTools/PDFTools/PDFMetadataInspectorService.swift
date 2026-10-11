//
//  PDFMetadataInspectorService.swift
//  Borno Pulse
//
//  PDF metadata inspection, editing, and privacy sanitization.
//
//  Sanitizing builds a brand-new document from copies of the pages, so the original Info
//  dictionary and XMP metadata stream are not carried over. PDFKit always records its own
//  Producer/creation date when writing; that cannot be suppressed through public API and is
//  reported to the user.
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
    public var isLocked: Bool = false
    public var allowsPrinting: Bool = true
    public var allowsCopying: Bool = true
    public var allowsChanges: Bool = true
    public var allowsCommenting: Bool = true
    public var allowsFormFilling: Bool = true
    public var pdfVersion: String = ""
    public var annotationCount: Int = 0
    public var annotationAuthors: [String] = []
    public var formFieldCount: Int = 0

    public init() {}
}

public struct PDFSanitizeOptions: Sendable {
    public var removeAnnotationAuthors: Bool = true
    public var removeAllAnnotations: Bool = false

    public init(removeAnnotationAuthors: Bool = true, removeAllAnnotations: Bool = false) {
        self.removeAnnotationAuthors = removeAnnotationAuthors
        self.removeAllAnnotations = removeAllAnnotations
    }
}

@MainActor
public final class PDFMetadataInspectorService: ObservableObject {
    public static let shared = PDFMetadataInspectorService()

    @Published public var sourceURL: URL?
    @Published public var document: PDFDocument?
    @Published public var metadata: PDFDetailedMetadata = PDFDetailedMetadata()
    @Published public var statusMessage: String = "No PDF inspected"
    @Published public var isProcessing: Bool = false
    @Published public var lastError: String?

    public init() {}

    public func inspectDocument(url: URL) {
        lastError = nil
        guard let doc = PDFDocument(url: url) else {
            document = nil
            sourceURL = nil
            lastError = PDFStudioError.unreadableFile(url.lastPathComponent).localizedDescription
            statusMessage = lastError ?? ""
            return
        }
        sourceURL = url
        document = doc
        var meta = Self.inspect(document: doc)
        meta.fileSize = UInt64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        metadata = meta
        if doc.isLocked {
            lastError = "This PDF is password-protected. Only basic information can be shown, and it cannot be sanitized until it is unlocked."
        }
        statusMessage = "Inspected \(url.lastPathComponent) (\(doc.pageCount) pages)"
    }

    public nonisolated static func inspect(document doc: PDFDocument) -> PDFDetailedMetadata {
        var meta = PDFDetailedMetadata()
        meta.pageCount = doc.pageCount
        meta.isEncrypted = doc.isEncrypted
        meta.isLocked = doc.isLocked
        meta.allowsPrinting = doc.allowsPrinting
        meta.allowsCopying = doc.allowsCopying
        meta.allowsChanges = doc.allowsDocumentChanges
        meta.allowsCommenting = doc.allowsCommenting
        meta.allowsFormFilling = doc.allowsFormFieldEntry
        meta.pdfVersion = "\(doc.majorVersion).\(doc.minorVersion)"

        if let attrs = doc.documentAttributes {
            meta.title = nonEmpty(attrs[PDFDocumentAttribute.titleAttribute] as? String)
            meta.author = nonEmpty(attrs[PDFDocumentAttribute.authorAttribute] as? String)
            meta.subject = nonEmpty(attrs[PDFDocumentAttribute.subjectAttribute] as? String)
            meta.creator = nonEmpty(attrs[PDFDocumentAttribute.creatorAttribute] as? String)
            meta.producer = nonEmpty(attrs[PDFDocumentAttribute.producerAttribute] as? String)
            meta.creationDate = attrs[PDFDocumentAttribute.creationDateAttribute] as? Date
            meta.modificationDate = attrs[PDFDocumentAttribute.modificationDateAttribute] as? Date
            if let keywords = attrs[PDFDocumentAttribute.keywordsAttribute] as? [String] {
                meta.keywords = keywords.filter { !$0.isEmpty }
            } else if let keywords = attrs[PDFDocumentAttribute.keywordsAttribute] as? String {
                meta.keywords = keywords.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            }
        }

        if !doc.isLocked {
            var authors = Set<String>()
            for index in 0..<doc.pageCount {
                guard let page = doc.page(at: index) else { continue }
                for annotation in page.annotations {
                    if annotation.type == "Widget" {
                        meta.formFieldCount += 1
                    } else if annotation.type != "Popup" && annotation.type != "Link" {
                        meta.annotationCount += 1
                    }
                    if let author = annotation.userName, !author.isEmpty { authors.insert(author) }
                }
            }
            meta.annotationAuthors = authors.sorted()
        }
        return meta
    }

    private nonisolated static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }

    // MARK: - Sanitize

    public func sanitizeAndExport(to destinationURL: URL, options: PDFSanitizeOptions = PDFSanitizeOptions()) -> Bool {
        guard let doc = document else {
            lastError = PDFStudioError.noDocument.localizedDescription
            return false
        }
        do {
            try Self.sanitize(doc, to: destinationURL, options: options)
            statusMessage = "Saved sanitized copy to \(destinationURL.lastPathComponent)"
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Sanitize failed: \(error.localizedDescription)"
            return false
        }
    }

    public nonisolated static func sanitize(_ doc: PDFDocument, to destinationURL: URL, options: PDFSanitizeOptions) throws {
        guard !doc.isLocked else { throw PDFStudioError.passwordProtected(destinationURL.lastPathComponent) }
        if let source = doc.documentURL, source.standardizedFileURL == destinationURL.standardizedFileURL {
            throw PDFStudioError.failed("Choose a different file name. The sanitized copy never replaces the original.")
        }
        let clean = PDFDocument()
        for index in 0..<doc.pageCount {
            guard let copy = doc.page(at: index)?.copy() as? PDFPage else { continue }
            for annotation in copy.annotations {
                if options.removeAllAnnotations, annotation.type != "Widget" {
                    copy.removeAnnotation(annotation)
                } else if options.removeAnnotationAuthors {
                    annotation.userName = nil
                    annotation.modificationDate = nil
                }
            }
            clean.insert(copy, at: clean.pageCount)
        }
        clean.documentAttributes = [:]
        try PDFSafeWriter.write(clean, to: destinationURL, expectedPageCount: doc.pageCount)

        guard let reopened = PDFDocument(url: destinationURL) else { throw PDFStudioError.verificationFailed(destinationURL.lastPathComponent) }
        let attrs = reopened.documentAttributes ?? [:]
        let leaked = [PDFDocumentAttribute.titleAttribute, .authorAttribute, .subjectAttribute, .keywordsAttribute].contains { key in
            if let text = attrs[key] as? String { return !text.isEmpty }
            if let list = attrs[key] as? [String] { return !list.isEmpty }
            return false
        }
        if leaked {
            try? FileManager.default.removeItem(at: destinationURL)
            throw PDFStudioError.failed("Metadata could not be removed from this document. No file was kept.")
        }
    }

    // MARK: - Edit

    public func saveEditedCopy(to destinationURL: URL, title: String, author: String, subject: String, keywords: String) -> Bool {
        guard let doc = document, !doc.isLocked else {
            lastError = PDFStudioError.noDocument.localizedDescription
            return false
        }
        if let source = sourceURL, source.standardizedFileURL == destinationURL.standardizedFileURL {
            lastError = "Choose a different file name. Edited metadata is saved to a copy."
            return false
        }
        let copy = PDFDocument()
        for index in 0..<doc.pageCount {
            if let page = doc.page(at: index)?.copy() as? PDFPage { copy.insert(page, at: copy.pageCount) }
        }
        var attributes: [AnyHashable: Any] = [:]
        if !title.isEmpty { attributes[PDFDocumentAttribute.titleAttribute] = title }
        if !author.isEmpty { attributes[PDFDocumentAttribute.authorAttribute] = author }
        if !subject.isEmpty { attributes[PDFDocumentAttribute.subjectAttribute] = subject }
        let keywordList = keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !keywordList.isEmpty { attributes[PDFDocumentAttribute.keywordsAttribute] = keywordList }
        copy.documentAttributes = attributes
        do {
            try PDFSafeWriter.write(copy, to: destinationURL, expectedPageCount: doc.pageCount)
            statusMessage = "Saved copy with updated metadata to \(destinationURL.lastPathComponent)"
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
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
