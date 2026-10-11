//
//  PDFSecurityService.swift
//  Borno Pulse
//

import AppKit
import Combine
import Foundation
import PDFKit

@MainActor
public final class PDFSecurityService: ObservableObject {
    public static let shared = PDFSecurityService()
    
    @Published public var selectedURL: URL?
    @Published public var document: PDFDocument?
    @Published public var metadata: PDFMetadataInfo = PDFMetadataInfo()
    @Published public var passwordInput: String = ""
    @Published public var isUnlocked: Bool = true
    @Published public var statusMessage: String = "No PDF loaded"
    
    public init() {}
    
    public func inspectPDF(url: URL) {
        self.selectedURL = url
        guard let doc = PDFDocument(url: url) else {
            statusMessage = "Unable to open PDF document."
            return
        }
        
        self.document = doc
        self.isUnlocked = !doc.isLocked
        
        var info = PDFMetadataInfo()
        info.pageCount = doc.pageCount
        info.isLocked = doc.isLocked
        
        if let attrs = doc.documentAttributes {
            info.title = attrs[PDFDocumentAttribute.titleAttribute] as? String
            info.author = attrs[PDFDocumentAttribute.authorAttribute] as? String
            info.subject = attrs[PDFDocumentAttribute.subjectAttribute] as? String
            info.creator = attrs[PDFDocumentAttribute.creatorAttribute] as? String
            info.producer = attrs[PDFDocumentAttribute.producerAttribute] as? String
            info.creationDate = attrs[PDFDocumentAttribute.creationDateAttribute] as? Date
        }
        
        self.metadata = info
        self.statusMessage = doc.isLocked ? "PDF is password-encrypted." : "Loaded metadata for \(url.lastPathComponent)"
    }
    
    public func attemptUnlock() -> Bool {
        guard let doc = document, doc.isLocked else { return true }
        if doc.unlock(withPassword: passwordInput) {
            self.isUnlocked = true
            self.statusMessage = "Document unlocked successfully."
            inspectPDF(url: selectedURL!)
            return true
        } else {
            self.statusMessage = "Incorrect password."
            return false
        }
    }
    
    public func exportCleanMetadataCopy() -> Result<URL, Error> {
        guard let doc = document, let inURL = selectedURL, isUnlocked else {
            return .failure(NSError(domain: "PDFSecurity", code: 1, userInfo: [NSLocalizedDescriptionKey: "Document is locked or missing."]))
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save Privacy-Sanitized PDF (Metadata Stripped)"
        let base = inURL.deletingPathExtension().lastPathComponent
        savePanel.nameFieldStringValue = "\(base)_sanitized.pdf"
        
        guard savePanel.runModal() == .OK, let outURL = savePanel.url else {
            return .failure(NSError(domain: "PDFSecurity", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export cancelled."]))
        }
        
        let cleanDoc = PDFDocument()
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i) {
                cleanDoc.insert(page, at: cleanDoc.pageCount)
            }
        }
        
        // Strip document attributes
        cleanDoc.documentAttributes = [
            PDFDocumentAttribute.titleAttribute: "",
            PDFDocumentAttribute.authorAttribute: "",
            PDFDocumentAttribute.subjectAttribute: "",
            PDFDocumentAttribute.creatorAttribute: "Borno Pulse (Sanitized)",
            PDFDocumentAttribute.producerAttribute: "Native CoreGraphics"
        ]
        
        guard cleanDoc.write(to: outURL) else {
            return .failure(NSError(domain: "PDFSecurity", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed writing sanitized PDF."]))
        }
        
        statusMessage = "Sanitized copy exported to \(outURL.lastPathComponent)"
        return .success(outURL)
    }
}
