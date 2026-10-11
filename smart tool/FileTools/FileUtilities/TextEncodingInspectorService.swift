//
//  TextEncodingInspectorService.swift
//  Naem Smart Tool
//

import Combine
import Foundation

public struct TextFileInfo: Sendable {
    public var encodingName: String
    public var hasBOM: Bool
    public var lineEndings: String
    public var lineCount: Int
    public var wordCount: Int
    public var characterCount: Int
    public var fileSize: UInt64
    public var samplePreview: String
    
    public init(
        encodingName: String = "UTF-8",
        hasBOM: Bool = false,
        lineEndings: String = "LF (UNIX)",
        lineCount: Int = 0,
        wordCount: Int = 0,
        characterCount: Int = 0,
        fileSize: UInt64 = 0,
        samplePreview: String = ""
    ) {
        self.encodingName = encodingName
        self.hasBOM = hasBOM
        self.lineEndings = lineEndings
        self.lineCount = lineCount
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.fileSize = fileSize
        self.samplePreview = samplePreview
    }
}

@MainActor
public final class TextEncodingInspectorService: ObservableObject {
    public static let shared = TextEncodingInspectorService()
    
    @Published public var selectedFileURL: URL?
    @Published public var fileInfo: TextFileInfo = TextFileInfo()
    @Published public var statusMessage: String = "No text file selected"
    
    public init() {}
    
    public func inspectFile(url: URL) {
        self.selectedFileURL = url
        
        guard let data = try? Data(contentsOf: url) else {
            statusMessage = "Unable to read file."
            return
        }
        
        let size = UInt64(data.count)
        var encodingString = "Unknown"
        var stringContent: String?
        var hasBOM = false
        
        // Detect BOM
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            hasBOM = true
            encodingString = "UTF-8 with BOM"
            stringContent = String(data: data.dropFirst(3), encoding: .utf8)
        } else if data.starts(with: [0xFF, 0xFE]) {
            hasBOM = true
            encodingString = "UTF-16 Little Endian (LE)"
            stringContent = String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        } else if data.starts(with: [0xFE, 0xFF]) {
            hasBOM = true
            encodingString = "UTF-16 Big Endian (BE)"
            stringContent = String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        } else if let str = String(data: data, encoding: .utf8) {
            encodingString = "UTF-8 (Standard Unicode)"
            stringContent = str
        } else if let str = String(data: data, encoding: .ascii) {
            encodingString = "US-ASCII (7-bit)"
            stringContent = str
        } else if let str = String(data: data, encoding: .isoLatin1) {
            encodingString = "ISO-8859-1 (Latin-1)"
            stringContent = str
        } else if let str = String(data: data, encoding: .windowsCP1252) {
            encodingString = "Windows-1252"
            stringContent = str
        }
        
        let content = stringContent ?? ""
        var lineEndings = "LF (UNIX / macOS)"
        if content.contains("\r\n") {
            lineEndings = "CRLF (Windows)"
        } else if content.contains("\r") && !content.contains("\n") {
            lineEndings = "CR (Classic Mac OS)"
        }
        
        let lines = content.components(separatedBy: .newlines).count
        let words = content.split { $0.isWhitespace }.count
        let chars = content.count
        let sample = String(content.prefix(1000))
        
        self.fileInfo = TextFileInfo(
            encodingName: encodingString,
            hasBOM: hasBOM,
            lineEndings: lineEndings,
            lineCount: lines,
            wordCount: words,
            characterCount: chars,
            fileSize: size,
            samplePreview: sample
        )
        self.statusMessage = "Inspected \(url.lastPathComponent)"
    }
}
