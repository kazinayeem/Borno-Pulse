//
//  StorageAnalyticsModels.swift
//  Borno Pulse
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Storage Analytics Category
public enum StorageAnalyticsCategory: String, CaseIterable, Identifiable, Sendable {
    case applications = "Applications"
    case documents = "Documents"
    case images = "Photos & Images"
    case videos = "Videos"
    case audio = "Audio"
    case downloads = "Downloads"
    case developer = "Developer Files"
    case derivedData = "Xcode DerivedData & Builds"
    case archives = "Archives & Packages"
    case caches = "Caches & Temp Files"
    case other = "Other Files"
    case systemReserved = "System & Reserved"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .applications: return "app.badge.fill"
        case .documents: return "doc.text.fill"
        case .images: return "photo.fill"
        case .videos: return "film.fill"
        case .audio: return "music.note"
        case .downloads: return "arrow.down.circle.fill"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .derivedData: return "hammer.fill"
        case .archives: return "archivebox.fill"
        case .caches: return "sparkles"
        case .other: return "questionmark.folder.fill"
        case .systemReserved: return "apple.logo"
        }
    }
    
    public var color: Color {
        switch self {
        case .applications: return AppTheme.electricBlue
        case .documents: return AppTheme.neonCyan
        case .images: return Color.purple
        case .videos: return Color.pink
        case .audio: return Color.orange
        case .downloads: return AppTheme.warningAmber
        case .developer: return AppTheme.matrixGreen
        case .derivedData: return Color.indigo
        case .archives: return Color.teal
        case .caches: return Color.yellow
        case .other: return AppTheme.textSecondary
        case .systemReserved: return Color.gray
        }
    }
    
    public static func classify(url: URL, isDirectory: Bool = false) -> StorageAnalyticsCategory {
        let path = url.path
        let ext = url.pathExtension.lowercased()
        
        // Priority 1: Xcode DerivedData & Build Artifacts
        if path.contains("/Library/Developer/Xcode/DerivedData") ||
           path.contains("/.build") ||
           path.contains("/DerivedData") {
            return .derivedData
        }
        
        // Priority 2: Caches & Temp Files
        if path.contains("/Library/Caches") ||
           path.contains("/tmp") ||
           path.contains("/var/tmp") ||
           path.contains("/.cache") {
            return .caches
        }
        
        // Priority 3: Applications
        if ext == "app" || ext == "framework" || ext == "bundle" || path.contains("/Applications/") {
            return .applications
        }
        
        // Priority 4: Downloads
        if path.contains("/Downloads/") && (ext == "dmg" || ext == "pkg" || ext == "iso") {
            return .downloads
        }
        
        // Priority 5: Extension-based categorization
        switch ext {
        case "mov", "mp4", "m4v", "mkv", "avi", "webm", "wmv", "flv", "ts":
            return .videos
        case "mp3", "m4a", "wav", "flac", "aac", "aiff", "ogg", "alac", "wma":
            return .audio
        case "jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif", "svg", "raw", "cr2", "nef", "psd", "ai", "gif":
            return .images
        case "pdf", "docx", "doc", "xlsx", "xls", "pptx", "ppt", "txt", "rtf", "pages", "key", "numbers", "md", "csv", "epub":
            return .documents
        case "zip", "tar", "gz", "tgz", "bz2", "7z", "dmg", "pkg", "iso", "rar", "xz":
            return .archives
        case "swift", "c", "cpp", "h", "hpp", "m", "mm", "py", "js", "ts", "jsx", "tsx", "html", "css", "scss",
             "json", "xml", "yaml", "yml", "sh", "rs", "go", "java", "kt", "rb", "php", "sql", "xcworkspace", "xcodeproj":
            return .developer
        default:
            return .other
        }
    }
}

// MARK: - Mounted Volume Information
public struct StorageVolumeInfo: Identifiable, Hashable, Sendable {
    public var id: String { mountURL.path }
    public var name: String
    public var mountURL: URL
    public var totalCapacityBytes: UInt64
    public var availableCapacityBytes: UInt64
    public var usedCapacityBytes: UInt64 {
        totalCapacityBytes > availableCapacityBytes ? (totalCapacityBytes - availableCapacityBytes) : 0
    }
    public var usedPercentage: Double {
        totalCapacityBytes > 0 ? (Double(usedCapacityBytes) / Double(totalCapacityBytes)) * 100.0 : 0.0
    }
    public var isRootVolume: Bool
    public var isRemovable: Bool
    public var fileSystemType: String
    
    public init(
        name: String,
        mountURL: URL,
        totalCapacityBytes: UInt64,
        availableCapacityBytes: UInt64,
        isRootVolume: Bool = false,
        isRemovable: Bool = false,
        fileSystemType: String = "APFS"
    ) {
        self.name = name
        self.mountURL = mountURL
        self.totalCapacityBytes = totalCapacityBytes
        self.availableCapacityBytes = availableCapacityBytes
        self.isRootVolume = isRootVolume
        self.isRemovable = isRemovable
        self.fileSystemType = fileSystemType
    }
}

// MARK: - Storage Item
public struct StorageAnalyticsItem: Identifiable, Sendable {
    public var id: String { path }
    public var url: URL
    public var path: String { url.path }
    public var name: String
    public var sizeBytes: UInt64
    public var isDirectory: Bool
    public var category: StorageAnalyticsCategory
    public var modificationDate: Date?
    public var parentPath: String
    
    public init(
        url: URL,
        sizeBytes: UInt64,
        isDirectory: Bool,
        category: StorageAnalyticsCategory? = nil,
        modificationDate: Date? = nil
    ) {
        self.url = url
        self.name = url.lastPathComponent
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
        self.category = category ?? StorageAnalyticsCategory.classify(url: url, isDirectory: isDirectory)
        self.modificationDate = modificationDate
        self.parentPath = url.deletingLastPathComponent().path
    }
}

// MARK: - Storage Tree Node (for Hierarchical Treemap & Drill-Down)
public final class StorageAnalyticsNode: Identifiable, @unchecked Sendable {
    public let id: UUID = UUID()
    public let url: URL
    public let name: String
    public var sizeBytes: UInt64
    public let isDirectory: Bool
    public let category: StorageAnalyticsCategory
    public var children: [StorageAnalyticsNode] = []
    public weak var parent: StorageAnalyticsNode?
    public var modificationDate: Date?
    
    public init(
        url: URL,
        sizeBytes: UInt64 = 0,
        isDirectory: Bool,
        category: StorageAnalyticsCategory,
        parent: StorageAnalyticsNode? = nil,
        modificationDate: Date? = nil
    ) {
        self.url = url
        self.name = url.lastPathComponent
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
        self.category = category
        self.parent = parent
        self.modificationDate = modificationDate
    }
    
    public func recalculateRecursiveSize() -> UInt64 {
        if !isDirectory {
            return sizeBytes
        }
        var total: UInt64 = 0
        for child in children {
            total += child.recalculateRecursiveSize()
        }
        self.sizeBytes = total
        return total
    }
}

// MARK: - Treemap Tile Representation
public struct TreemapTile: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var sizeBytes: UInt64
    public var percentage: Double
    public var category: StorageAnalyticsCategory
    public var rect: CGRect
    public var isDirectory: Bool
    public var nodeID: UUID?
    public var depth: Int
    
    public init(
        id: String,
        name: String,
        sizeBytes: UInt64,
        percentage: Double,
        category: StorageAnalyticsCategory,
        rect: CGRect = .zero,
        isDirectory: Bool = false,
        nodeID: UUID? = nil,
        depth: Int = 0
    ) {
        self.id = id
        self.name = name
        self.sizeBytes = sizeBytes
        self.percentage = percentage
        self.category = category
        self.rect = rect
        self.isDirectory = isDirectory
        self.nodeID = nodeID
        self.depth = depth
    }
}

// MARK: - Historical Snapshot
public struct HistoricalStorageSnapshot: Identifiable, Codable, Sendable {
    public var id: UUID = UUID()
    public var timestamp: Date
    public var volumeName: String
    public var totalCapacityBytes: UInt64
    public var usedCapacityBytes: UInt64
    public var scannedBytes: UInt64
    public var scannedFileCount: Int
    
    public init(
        timestamp: Date = Date(),
        volumeName: String,
        totalCapacityBytes: UInt64,
        usedCapacityBytes: UInt64,
        scannedBytes: UInt64,
        scannedFileCount: Int
    ) {
        self.timestamp = timestamp
        self.volumeName = volumeName
        self.totalCapacityBytes = totalCapacityBytes
        self.usedCapacityBytes = usedCapacityBytes
        self.scannedBytes = scannedBytes
        self.scannedFileCount = scannedFileCount
    }
}

// MARK: - Scan Scope & Mode
public enum StorageScanMode: String, CaseIterable, Identifiable, Sendable {
    case quick = "Quick Scan (User & Caches)"
    case detailed = "Detailed Scan (Full Volume)"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .quick:
            return "Analyzes ~/Documents, ~/Downloads, ~/Desktop, ~/Library/Caches, and developer directories."
        case .detailed:
            return "Recursively analyzes the accessible filesystem hierarchy of the chosen volume or directory."
        }
    }
}
