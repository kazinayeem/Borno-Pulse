//
//  StorageAnalyzerModels.swift
//  Borno Pulse
//

import Foundation

public enum StorageCategory: String, CaseIterable, Sendable, Identifiable {
    case documents = "Documents"
    case media = "Media & Videos"
    case audio = "Audio"
    case images = "Images"
    case archives = "Archives & Packages"
    case developer = "Code & Projects"
    case applications = "Applications"
    case other = "Other"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .documents: return "doc.text.fill"
        case .media: return "film.fill"
        case .audio: return "music.note"
        case .images: return "photo.fill"
        case .archives: return "archivebox.fill"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .applications: return "app.badge.fill"
        case .other: return "questionmark.folder.fill"
        }
    }
    
    public static func category(for extensionString: String) -> StorageCategory {
        let ext = extensionString.lowercased()
        switch ext {
        case "mov", "mp4", "m4v", "mkv", "avi", "webm", "wmv", "flv":
            return .media
        case "mp3", "m4a", "wav", "flac", "aac", "aiff", "ogg":
            return .audio
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "svg", "raw", "psd":
            return .images
        case "pdf", "docx", "doc", "xlsx", "xls", "pptx", "ppt", "txt", "rtf", "pages", "key", "numbers", "md", "csv":
            return .documents
        case "zip", "tar", "gz", "tgz", "bz2", "7z", "dmg", "pkg", "iso", "rar":
            return .archives
        case "swift", "c", "cpp", "h", "m", "py", "js", "ts", "html", "css", "json", "xml", "yaml", "yml", "sh", "rs", "go", "java":
            return .developer
        case "app":
            return .applications
        default:
            return .other
        }
    }
}

public struct StorageItem: Identifiable, Sendable {
    public var id: String { path }
    public var url: URL
    public var path: String { url.path }
    public var name: String
    public var sizeBytes: UInt64
    public var isDirectory: Bool
    public var category: StorageCategory
    public var modificationDate: Date?
    
    public init(url: URL, sizeBytes: UInt64, isDirectory: Bool, modificationDate: Date? = nil) {
        self.url = url
        self.name = url.lastPathComponent
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
        self.modificationDate = modificationDate
        self.category = isDirectory ? .other : StorageCategory.category(for: url.pathExtension)
    }
}
