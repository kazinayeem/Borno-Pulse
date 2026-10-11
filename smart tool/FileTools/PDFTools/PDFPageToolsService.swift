//
//  PDFPageToolsService.swift
//  Naem Smart Tool
//

import AppKit
import Combine
import Foundation
import PDFKit

@MainActor
public final class PDFPageToolsService: ObservableObject {
    public static let shared = PDFPageToolsService()
    
    @Published public var sourceURL: URL?
    @Published public var document: PDFDocument?
    @Published public var pageRotations: [Int: Int] = [:] // pageIndex: rotationDegrees (0, 90, 180, 270)
    @Published public var deletedPageIndices: Set<Int> = []
    @Published public var selectedPageIndices: Set<Int> = []
    @Published public var statusMessage: String = "No PDF loaded"
    
    public init() {}
    
    public func loadDocument(url: URL) {
        guard let doc = PDFDocument(url: url) else {
            statusMessage = "Unable to open PDF document."
            return
        }
        self.sourceURL = url
        self.document = doc
        self.pageRotations = [:]
        self.deletedPageIndices = []
        self.selectedPageIndices = []
        self.statusMessage = "Loaded \(url.lastPathComponent) (\(doc.pageCount) pages)"
    }
    
    public func rotateSelectedPages(degrees: Int = 90) {
        let targets = selectedPageIndices.isEmpty ? Array(0..<(document?.pageCount ?? 0)) : Array(selectedPageIndices)
        for idx in targets {
            let current = pageRotations[idx] ?? (document?.page(at: idx)?.rotation ?? 0)
            pageRotations[idx] = (current + degrees) % 360
        }
        statusMessage = "Rotated \(targets.count) page(s)"
    }
    
    public func deleteSelectedPages() {
        guard !selectedPageIndices.isEmpty else { return }
        deletedPageIndices.formUnion(selectedPageIndices)
        selectedPageIndices.removeAll()
        statusMessage = "\(deletedPageIndices.count) page(s) marked for removal in output copy"
    }
    
    public func restoreDeletedPages() {
        deletedPageIndices.removeAll()
        statusMessage = "Restored all pages"
    }
    
    public func exportModifiedDocument() -> Result<URL, Error> {
        guard let doc = document, let inURL = sourceURL else {
            return .failure(NSError(domain: "PDFPageTools", code: 1, userInfo: [NSLocalizedDescriptionKey: "No PDF loaded."]))
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save Modified PDF"
        let base = inURL.deletingPathExtension().lastPathComponent
        savePanel.nameFieldStringValue = "\(base)_modified.pdf"
        
        guard savePanel.runModal() == .OK, let outURL = savePanel.url else {
            return .failure(NSError(domain: "PDFPageTools", code: 2, userInfo: [NSLocalizedDescriptionKey: "Save cancelled."]))
        }
        
        let outputDoc = PDFDocument()
        for i in 0..<doc.pageCount {
            if deletedPageIndices.contains(i) { continue }
            guard let page = doc.page(at: i) else { continue }
            
            if let rot = pageRotations[i] {
                page.rotation = rot
            }
            outputDoc.insert(page, at: outputDoc.pageCount)
        }
        
        guard outputDoc.write(to: outURL) else {
            return .failure(NSError(domain: "PDFPageTools", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed writing PDF."]))
        }
        
        statusMessage = "Exported modified document to \(outURL.lastPathComponent)"
        return .success(outURL)
    }
}
