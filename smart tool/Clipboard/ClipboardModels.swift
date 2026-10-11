//
//  ClipboardModels.swift
//  Borno Pulse
//

import AppKit
import CryptoKit
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

    /// Short label used in compact rows (picker, menu bar).
    public var shortLabel: String {
        switch self {
        case .text: return "Text"
        case .url: return "URL"
        case .image: return "Image"
        case .file: return "File"
        case .richText: return "Rich Text"
        }
    }
}

public struct ClipboardItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    /// Time the content was last captured (re-copying the same content refreshes it).
    public var timestamp: Date
    public let type: ClipboardContentType
    public let preview: String
    public let contentText: String?
    /// Legacy inline image storage. Migrated to `imageFileName` when history is loaded.
    public var imagePNGData: Data?
    public let filePaths: [String]?
    public var isPinned: Bool
    public var isSensitive: Bool
    public let byteSize: Int64
    public let sourceAppName: String?
    public var sourceBundleID: String?
    /// RTF data restored alongside the plain-text fallback for `.richText` items.
    public var rtfData: Data?
    /// PNG file inside the managed clipboard image store.
    public var imageFileName: String?
    /// Stable digest of the restorable content, used for duplicate detection.
    public var contentHash: String?
    
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
        sourceAppName: String? = nil,
        sourceBundleID: String? = nil,
        rtfData: Data? = nil,
        imageFileName: String? = nil,
        contentHash: String? = nil
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
        self.sourceBundleID = sourceBundleID
        self.rtfData = rtfData
        self.imageFileName = imageFileName
        self.contentHash = contentHash
    }

    public var fileURLs: [URL] {
        (filePaths ?? []).map { URL(fileURLWithPath: $0) }
    }

    /// File references only point at the original files; they cannot be restored once those are gone.
    public var missingFilePaths: [String] {
        (filePaths ?? []).filter { !FileManager.default.fileExists(atPath: $0) }
    }

    /// Text used for search matching across the page, picker and menu bar.
    public var searchableText: String {
        var parts = [preview, type.rawValue, type.shortLabel]
        if let contentText { parts.append(contentText) }
        if let filePaths { parts.append(contentsOf: filePaths) }
        if let sourceAppName { parts.append(sourceAppName) }
        return parts.joined(separator: "\n").lowercased()
    }

    /// Preview that hides detected secrets in glanceable surfaces (picker, menu bar).
    public var maskedPreview: String {
        guard isSensitive else { return preview }
        let visible = preview.prefix(4)
        return "\(visible)•••••••• (hidden secret)"
    }

    public static func hash(type: ClipboardContentType, parts: [Data]) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(type.rawValue.utf8))
        for part in parts {
            hasher.update(data: Data([0]))
            hasher.update(data: part)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// App that owned the frontmost window when content was captured.
/// macOS does not expose which process wrote to the pasteboard, so this is a best-effort attribution.
public struct ClipboardSourceApp: Equatable, Sendable {
    public let name: String?
    public let bundleID: String?

    public init(name: String?, bundleID: String?) {
        self.name = name
        self.bundleID = bundleID
    }
}

/// Why a pasteboard change was not recorded. Surfaced in diagnostics and tests.
public enum ClipboardSkipReason: String, Sendable, Equatable {
    case disabled
    case paused
    case unchanged
    case ownWrite
    case transientContent
    case concealedContent
    case excludedApplication
    case sensitiveContent
    case tooLarge
    case unsupportedContent
}

public enum ClipboardRetention: Int, CaseIterable, Identifiable, Sendable {
    case oneDay = 1
    case oneWeek = 7
    case oneMonth = 30
    case threeMonths = 90
    case forever = 0

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .oneDay: return "1 Day"
        case .oneWeek: return "7 Days"
        case .oneMonth: return "30 Days"
        case .threeMonths: return "90 Days"
        case .forever: return "Until Removed"
        }
    }
}

public enum ClipboardPauseDuration: CaseIterable, Identifiable, Sendable {
    case fifteenMinutes
    case oneHour
    case untilResumed

    public var id: String { label }

    public var seconds: TimeInterval? {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .oneHour: return 60 * 60
        case .untilResumed: return nil
        }
    }

    public var label: String {
        switch self {
        case .fifteenMinutes: return "Pause for 15 Minutes"
        case .oneHour: return "Pause for 1 Hour"
        case .untilResumed: return "Pause Until Resumed"
        }
    }
}

public enum ClipboardMonitoringState: Equatable, Sendable {
    case off
    case paused(until: Date?)
    case monitoring

    public var label: String {
        switch self {
        case .off: return "History Off"
        case .paused: return "Paused"
        case .monitoring: return "Monitoring"
        }
    }

    public var symbol: String {
        switch self {
        case .off: return "doc.on.clipboard"
        case .paused: return "pause.circle"
        case .monitoring: return "doc.on.clipboard.fill"
        }
    }
}
