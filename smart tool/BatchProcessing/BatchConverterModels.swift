//
//  BatchConverterModels.swift
//  Borno Pulse
//

import AppKit
import Foundation
import SwiftUI

public enum BatchOperationKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case convertImage = "Convert Image Format"
    case compressImage = "Compress Image"
    case resizeImage = "Resize Dimensions"
    case pdfToImages = "PDF to Image Pages"
    case imagesToPDF = "Images to PDF Document"
    case compressPDF = "Compress PDF"
    case mergePDFs = "Merge PDFs"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .convertImage: return "arrow.triangle.2.circlepath"
        case .compressImage: return "arrow.down.right.and.arrow.up.left"
        case .resizeImage: return "aspectratio"
        case .pdfToImages: return "doc.richtext"
        case .imagesToPDF: return "doc.badge.plus"
        case .compressPDF: return "arrow.down.doc.fill"
        case .mergePDFs: return "doc.on.doc.fill"
        }
    }
}

public enum BatchItemStatus: String, Codable, Sendable {
    case queued = "Queued"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
}

public struct BatchQueueItem: Identifiable, Sendable {
    public let id: UUID
    public let sourceURL: URL
    public let sourceSize: Int64
    public var operation: BatchOperationKind
    public var targetFormat: String // "jpg", "png", "webp", "pdf"
    public var destinationURL: URL?
    public var status: BatchItemStatus
    public var progress: Double
    public var outputSize: Int64
    public var errorMessage: String?
    
    public var sourceFilename: String {
        sourceURL.lastPathComponent
    }
    
    public var sizeSavingsPercentage: Double {
        guard sourceSize > 0 && outputSize > 0 else { return 0 }
        let diff = Double(sourceSize - outputSize)
        return (diff / Double(sourceSize)) * 100.0
    }
    
    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        sourceSize: Int64,
        operation: BatchOperationKind = .convertImage,
        targetFormat: String = "jpg",
        destinationURL: URL? = nil,
        status: BatchItemStatus = .queued,
        progress: Double = 0.0,
        outputSize: Int64 = 0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.sourceSize = sourceSize
        self.operation = operation
        self.targetFormat = targetFormat
        self.destinationURL = destinationURL
        self.status = status
        self.progress = progress
        self.outputSize = outputSize
        self.errorMessage = errorMessage
    }
}
