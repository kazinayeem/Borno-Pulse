//
//  ClipboardModels.swift
//  Borno Pulse
//

import AppKit
import Foundation

public enum ClipboardContentType: String, CaseIterable, Identifiable, Codable, Sendable {
    case text = "Plain Text"
    case url = "Web URL"
    case image = "Image"
    case file = "File Reference"
    case richText = "Rich Text"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .image: return "photo"
        case .file: return "doc.fill"
        case .richText: return "doc.richtext"
        }
    }
}

public struct ClipboardItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: ClipboardContentType
    public let preview: String
    public let contentText: String?
    public let imagePNGData: Data?
    public let filePaths: [String]?
    public var isPinned: Bool
    public var isSensitive: Bool
    public let byteSize: Int64
    public let sourceAppName: String?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ClipboardContentType,
        preview: String,
        contentText: String? = nil,
        imagePNGData: Data? = nil,
        filePaths: [String]? = nil,
        isPinned: Bool = false,
        isSensitive: Bool = false,
        byteSize: Int64 = 0,
        sourceAppName: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.preview = preview
        self.contentText = contentText
        self.imagePNGData = imagePNGData
        self.filePaths = filePaths
        self.isPinned = isPinned
        self.isSensitive = isSensitive
        self.byteSize = byteSize
        self.sourceAppName = sourceAppName
    }
}
