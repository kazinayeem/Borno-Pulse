//
//  ImageToolModels.swift
//  Borno Pulse
//

import AppKit
import Foundation
import UniformTypeIdentifiers

public enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
    case png = "PNG"
    case jpeg = "JPG / JPEG"
    case heic = "HEIC"
    case tiff = "TIFF"
    case bmp = "BMP"
    
    public var id: String { rawValue }
    
    public var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .tiff: return "tiff"
        case .bmp: return "bmp"
        }
    }
    
    public var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .tiff: return .tiff
        case .bmp: return .bmp
        }
    }
    
    public var utTypeIdentifier: CFString {
        return utType.identifier as CFString
    }
    
    public var supportsAlpha: Bool {
        switch self {
        case .png, .tiff: return true
        case .jpeg, .heic, .bmp: return false
        }
    }
}

public struct ImageFileQueueItem: Identifiable, Sendable {
    public var id: UUID = UUID()
    public var url: URL
    public var filename: String { url.lastPathComponent }
    public var originalFormat: String
    public var originalSizeBytes: UInt64
    public var dimensions: CGSize?
    public var outputSizeBytes: UInt64?
    public var status: FileItemStatus = .pending
    public var errorMessage: String?
    
    public init(url: URL, originalFormat: String = "Image", originalSizeBytes: UInt64 = 0, dimensions: CGSize? = nil) {
        self.url = url
        self.originalFormat = originalFormat
        self.originalSizeBytes = originalSizeBytes
        self.dimensions = dimensions
    }
}

public enum FileItemStatus: String, Sendable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
}

public enum ImageCompressionPreset: String, CaseIterable, Identifiable, Sendable {
    case high = "High Quality (85%)"
    case balanced = "Balanced (70%)"
    case small = "Small File (50%)"
    case custom = "Custom"
    
    public var id: String { rawValue }
    
    public var qualityValue: Float {
        switch self {
        case .high: return 0.85
        case .balanced: return 0.70
        case .small: return 0.50
        case .custom: return 0.75
        }
    }
}

public enum ResizeMode: String, CaseIterable, Identifiable, Sendable {
    case pixels = "Exact Dimensions"
    case percentage = "Percentage Scale"
    case preset = "Preset Template"
    
    public var id: String { rawValue }
}

public enum ResizePreset: String, CaseIterable, Identifiable, Sendable {
    case avatar = "Avatar (512 × 512)"
    case socialPost = "Social Post (1080 × 1080)"
    case fullHD = "Full HD (1920 × 1080)"
    case quadHD = "2K Quad HD (2560 × 1440)"
    case ultraHD = "4K UHD (3840 × 2160)"
    case thumbnail = "Thumbnail (256 × 256)"
    
    public var id: String { rawValue }
    
    public var targetSize: CGSize {
        switch self {
        case .avatar: return CGSize(width: 512, height: 512)
        case .socialPost: return CGSize(width: 1080, height: 1080)
        case .fullHD: return CGSize(width: 1920, height: 1080)
        case .quadHD: return CGSize(width: 2560, height: 1440)
        case .ultraHD: return CGSize(width: 3840, height: 2160)
        case .thumbnail: return CGSize(width: 256, height: 256)
        }
    }
}

public struct ImageMetadataInfo: Sendable {
    public var width: Int = 0
    public var height: Int = 0
    public var format: String = "Unknown"
    public var colorProfile: String = "sRGB"
    public var fileSize: UInt64 = 0
    public var orientation: Int = 1
    public var dpi: Double = 72.0
    public var exifProperties: [String: String] = [:]
    public var gpsProperties: [String: String] = [:]
    public var hasLocationData: Bool { !gpsProperties.isEmpty }
    
    public init() {}
}
