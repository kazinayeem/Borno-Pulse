//
//  PDFMergerSplitterService.swift
//  Naem Smart Tool
//

import AppKit
import Combine
import Foundation
import PDFKit

@MainActor
public final class PDFMergerSplitterService: ObservableObject {
    public static let shared = PDFMergerSplitterService()
    
    // Merge State
    @Published public var mergeQueue: [PDFFileQueueItem] = []
    @Published public var mergedFilename: String = "Merged_Document.pdf"
    
    // Split State
    @Published public var splitSourceURL: URL?
    @Published public var splitSourceDoc: PDFDocument?
    @Published public var splitMode: PDFSplitMode = .everyPage
    @Published public var splitRangeStart: Int = 1
    @Published public var splitRangeEnd: Int = 1
    @Published public var splitEveryN: Int = 1
    
    @Published public var outputDirectory: URL?
    @Published public var isProcessing = false
    @Published public var currentProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    
    public init() {
        self.outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    // MARK: - Merge Operations
    public func addMergeFiles(urls: [URL]) {
        for url in urls {
            guard let doc = PDFDocument(url: url) else { continue }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let item = PDFFileQueueItem(url: url, pageCount: doc.pageCount, fileSize: UInt64(size))
            mergeQueue.append(item)
        }
        statusMessage = "Added \(mergeQueue.count) PDFs for merging"
    }
    
    public func clearMergeQueue() {
        mergeQueue.removeAll()
        statusMessage = "Queue cleared"
    }
    
    public func moveMergeItem(from source: IndexSet, to destination: Int) {
        mergeQueue.move(fromOffsets: source, toOffset: destination)
    }
    
    public func executeMerge() {
        guard !isProcessing, !mergeQueue.isEmpty, let outDir = outputDirectory else { return }
        isProcessing = true
        currentProgress = 0.0
        statusMessage = "Merging PDF documents..."
        
        let items = mergeQueue
        let fileName = mergedFilename.hasSuffix(".pdf") ? mergedFilename : "\(mergedFilename).pdf"
        let outputURL = outDir.appendingPathComponent(fileName)
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let finalDoc = PDFDocument()
            let total = Double(items.count)
            
            for (index, item) in items.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.statusMessage = "Merging \(item.filename)... (\(index + 1)/\(items.count))"
                    self.currentProgress = Double(index) / total
                }
                
                guard let doc = PDFDocument(url: item.url) else { continue }
                for p in 0..<doc.pageCount {
                    if let page = doc.page(at: p) {
                        finalDoc.insert(page, at: finalDoc.pageCount)
                    }
                }
            }
            
            let success = finalDoc.write(to: outputURL)
            
            await MainActor.run {
                self.isProcessing = false
                self.currentProgress = 1.0
                if success {
                    self.statusMessage = "Merged \(items.count) files into \(fileName) (\(finalDoc.pageCount) total pages)."
                } else {
                    self.statusMessage = "Failed writing merged PDF."
                }
            }
        }
    }
    
    // MARK: - Split Operations
    public func loadSplitDocument(url: URL) {
        guard let doc = PDFDocument(url: url) else {
            statusMessage = "Failed opening PDF document."
            return
        }
        self.splitSourceURL = url
        self.splitSourceDoc = doc
        self.splitRangeStart = 1
        self.splitRangeEnd = doc.pageCount
        self.statusMessage = "Loaded \(url.lastPathComponent) (\(doc.pageCount) pages)"
    }
    
    public func executeSplit() {
        guard !isProcessing, let doc = splitSourceDoc, let inURL = splitSourceURL, let outDir = outputDirectory else { return }
        isProcessing = true
        currentProgress = 0.0
        statusMessage = "Splitting PDF..."
        
        let baseName = inURL.deletingPathExtension().lastPathComponent
        let mode = splitMode
        let start = splitRangeStart
        let reqEnd = splitRangeEnd
        let everyN = max(1, splitEveryN)
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self, let doc = PDFDocument(url: inURL) else { return }
            var createdCount = 0
            let pageCount = doc.pageCount
            let end = min(pageCount, reqEnd)
            
            switch mode {
            case .everyPage:
                for i in 0..<pageCount {
                    if Task.isCancelled { break }
                    guard let page = doc.page(at: i) else { continue }
                    let singleDoc = PDFDocument()
                    singleDoc.insert(page, at: 0)
                    let outURL = outDir.appendingPathComponent("\(baseName)_page_\(i + 1).pdf")
                    if singleDoc.write(to: outURL) {
                        createdCount += 1
                    }
                    let progress = Double(i) / Double(pageCount)
                    await MainActor.run { self.currentProgress = progress }
                }
                
            case .pageRange:
                let rangeDoc = PDFDocument()
                for i in (start - 1)..<end {
                    if let page = doc.page(at: i) {
                        rangeDoc.insert(page, at: rangeDoc.pageCount)
                    }
                }
                let outURL = outDir.appendingPathComponent("\(baseName)_pages_\(start)-to-\(end).pdf")
                if rangeDoc.write(to: outURL) {
                    createdCount = 1
                }
                
            case .everyNPages:
                var partIndex = 1
                var currentIndex = 0
                while currentIndex < pageCount {
                    if Task.isCancelled { break }
                    let partDoc = PDFDocument()
                    let limit = min(currentIndex + everyN, pageCount)
                    for i in currentIndex..<limit {
                        if let page = doc.page(at: i) {
                            partDoc.insert(page, at: partDoc.pageCount)
                        }
                    }
                    let outURL = outDir.appendingPathComponent("\(baseName)_part_\(partIndex).pdf")
                    if partDoc.write(to: outURL) {
                        createdCount += 1
                    }
                    currentIndex = limit
                    partIndex += 1
                    let progress = Double(currentIndex) / Double(pageCount)
                    await MainActor.run { self.currentProgress = progress }
                }
            }
            
            await MainActor.run {
                self.isProcessing = false
                self.currentProgress = 1.0
                self.statusMessage = "Split complete! Generated \(createdCount) document(s)."
            }
        }
    }
}
