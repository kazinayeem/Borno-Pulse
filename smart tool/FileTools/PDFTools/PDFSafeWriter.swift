//
//  PDFSafeWriter.swift
//  Borno Pulse
//
//  Crash-safe PDF output: write to a temporary file on the destination volume, reopen and
//  validate it, then atomically move/replace it into place. The destination (including a
//  user's original document) is never touched unless the new file is known to be valid.
//

import Foundation
import PDFKit

public enum PDFStudioError: LocalizedError, Equatable {
    case noDocument
    case unreadableFile(String)
    case passwordProtected(String)
    case unsupportedFormat(String)
    case destinationNotWritable(String)
    case destinationMissing(String)
    case writeFailed(String)
    case verificationFailed(String)
    case invalidPageRange(String)
    case emptyResult(String)
    case cancelled
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .noDocument:
            return "No PDF document is open."
        case .unreadableFile(let name):
            return "“\(name)” could not be opened. It may be damaged or not a valid PDF/image file."
        case .passwordProtected(let name):
            return "“\(name)” is password-protected. Unlock it in the Advanced PDF Editor first."
        case .unsupportedFormat(let detail):
            return "Unsupported file format: \(detail)"
        case .destinationNotWritable(let folder):
            return "You don't have permission to save in “\(folder)”. Choose a different folder."
        case .destinationMissing(let folder):
            return "The destination folder “\(folder)” no longer exists. Choose a different folder."
        case .writeFailed(let name):
            return "Writing “\(name)” failed. Check that the disk has free space and try again."
        case .verificationFailed(let name):
            return "“\(name)” was written but could not be reopened as a valid PDF, so it was discarded. The original file was not changed."
        case .invalidPageRange(let detail):
            return detail
        case .emptyResult(let detail):
            return detail
        case .cancelled:
            return "The operation was cancelled."
        case .failed(let detail):
            return detail
        }
    }
}

public enum PDFSafeWriter {

    /// Writes `document` to `url` atomically and verifies the result reopens with the expected page count.
    public static func write(
        _ document: PDFDocument,
        to url: URL,
        options: [PDFDocumentWriteOption: Any]? = nil,
        expectedPageCount: Int? = nil
    ) throws {
        try write(to: url, expectedPageCount: expectedPageCount ?? document.pageCount) { tempURL in
            if let options {
                return document.write(to: tempURL, withOptions: options)
            }
            return document.write(to: tempURL)
        }
    }

    /// Writes raw PDF data atomically after validating it.
    public static func write(data: Data, to url: URL, expectedPageCount: Int? = nil) throws {
        try write(to: url, expectedPageCount: expectedPageCount) { tempURL in
            (try? data.write(to: tempURL)) != nil
        }
    }

    /// Moves an already generated PDF (e.g. from an external converter) into place after validation.
    public static func install(generatedFile source: URL, at url: URL) throws {
        try write(to: url, expectedPageCount: nil) { tempURL in
            (try? FileManager.default.copyItem(at: source, to: tempURL)) != nil
        }
    }

    private static func write(to url: URL, expectedPageCount: Int?, producer: (URL) -> Bool) throws {
        let fileManager = FileManager.default
        let folder = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw PDFStudioError.destinationMissing(folder.lastPathComponent)
        }
        guard fileManager.isWritableFile(atPath: folder.path) else {
            throw PDFStudioError.destinationNotWritable(folder.lastPathComponent)
        }

        let tempFolder: URL
        do {
            tempFolder = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: url, create: true)
        } catch {
            tempFolder = fileManager.temporaryDirectory.appendingPathComponent("BornoPDF-\(UUID().uuidString)", isDirectory: true)
            try? fileManager.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        }
        defer { try? fileManager.removeItem(at: tempFolder) }

        let tempURL = tempFolder.appendingPathComponent(url.lastPathComponent)
        guard producer(tempURL), fileManager.fileExists(atPath: tempURL.path) else {
            throw PDFStudioError.writeFailed(url.lastPathComponent)
        }
        try verify(tempURL, expectedPageCount: expectedPageCount, displayName: url.lastPathComponent)

        do {
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: url)
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain,
               [NSFileWriteNoPermissionError, NSFileWriteVolumeReadOnlyError].contains(nsError.code) {
                throw PDFStudioError.destinationNotWritable(folder.lastPathComponent)
            }
            throw PDFStudioError.failed("Could not save “\(url.lastPathComponent)”: \(error.localizedDescription)")
        }
    }

    public static func verify(_ url: URL, expectedPageCount: Int?, displayName: String? = nil) throws {
        let name = displayName ?? url.lastPathComponent
        guard let reopened = PDFDocument(url: url), reopened.pageCount > 0 else {
            throw PDFStudioError.verificationFailed(name)
        }
        if let expectedPageCount, reopened.pageCount != expectedPageCount {
            throw PDFStudioError.verificationFailed(name)
        }
    }

    /// Returns `url` if nothing exists there, otherwise “name 2.ext”, “name 3.ext”, …
    public static func uniqueURL(for url: URL) -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return url }
        let folder = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var index = 2
        while true {
            let name = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            let candidate = folder.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    public static func ensureWritableFolder(_ folder: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw PDFStudioError.destinationMissing(folder.lastPathComponent)
        }
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw PDFStudioError.destinationNotWritable(folder.lastPathComponent)
        }
    }

    /// Opens a PDF for reading, reporting locked or invalid files with actionable errors.
    public static func openReadable(_ url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else {
            throw PDFStudioError.unreadableFile(url.lastPathComponent)
        }
        if document.isLocked {
            throw PDFStudioError.passwordProtected(url.lastPathComponent)
        }
        guard document.pageCount > 0 else {
            throw PDFStudioError.unreadableFile(url.lastPathComponent)
        }
        return document
    }

    /// Parses “1-3, 5, 8-10” into zero-based page index groups. Invalid tokens and
    /// out-of-range pages are reported instead of being silently clamped.
    public static func parsePageRanges(_ text: String, pageCount: Int) throws -> [[Int]] {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw PDFStudioError.invalidPageRange("Enter at least one page number or range, for example “1-3, 5”.")
        }
        var groups: [[Int]] = []
        for rawPart in trimmedText.split(separator: ",") {
            let part = rawPart.trimmingCharacters(in: .whitespaces)
            if part.isEmpty { continue }
            let bounds = part.split(separator: "-", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            let numbers = bounds.compactMap { Int($0) }
            guard numbers.count == bounds.count, (1...2).contains(numbers.count) else {
                throw PDFStudioError.invalidPageRange("“\(part)” is not a valid page or range. Use numbers like “4” or “2-6”.")
            }
            let start = numbers[0], end = numbers.last!
            guard start >= 1, end >= 1, start <= pageCount, end <= pageCount else {
                throw PDFStudioError.invalidPageRange("“\(part)” is outside this document's pages (1-\(pageCount)).")
            }
            guard start <= end else {
                throw PDFStudioError.invalidPageRange("“\(part)” runs backwards. Write ranges from low to high, e.g. “\(end)-\(start)”.")
            }
            groups.append(Array((start - 1)...(end - 1)))
        }
        guard !groups.isEmpty else {
            throw PDFStudioError.invalidPageRange("Enter at least one page number or range, for example “1-3, 5”.")
        }
        return groups
    }
}
