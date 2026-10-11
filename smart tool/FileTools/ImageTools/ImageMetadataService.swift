//
//  ImageMetadataService.swift
//  Naem Smart Tool
//

import AppKit
import Combine
import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor
public final class ImageMetadataService: ObservableObject {
    public static let shared = ImageMetadataService()
    
    @Published public var selectedImageURL: URL?
    @Published public var metadataInfo: ImageMetadataInfo = ImageMetadataInfo()
    @Published public var previewImage: NSImage?
    @Published public var statusMessage: String = "No image selected"
    
    public init() {}
    
    public func inspectImage(url: URL) {
        self.selectedImageURL = url
        self.previewImage = NSImage(contentsOf: url)
        
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            statusMessage = "Unable to read image metadata."
            return
        }
        
        var info = ImageMetadataInfo()
        info.fileSize = UInt64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        info.format = url.pathExtension.uppercased()
        
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            info.width = props[kCGImagePropertyPixelWidth] as? Int ?? 0
            info.height = props[kCGImagePropertyPixelHeight] as? Int ?? 0
            info.orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
            info.dpi = props[kCGImagePropertyDPIWidth] as? Double ?? 72.0
            info.colorProfile = props[kCGImagePropertyColorModel] as? String ?? "RGB"
            
            // EXIF
            if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                var dict: [String: String] = [:]
                for (k, v) in exif {
                    dict["\(k)"] = "\(v)"
                }
                info.exifProperties = dict
            }
            
            // GPS
            if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
                var dict: [String: String] = [:]
                for (k, v) in gps {
                    dict["\(k)"] = "\(v)"
                }
                info.gpsProperties = dict
            }
        }
        
        self.metadataInfo = info
        self.statusMessage = "Loaded \(url.lastPathComponent)"
    }
    
    public func exportPrivacyCleanCopy() -> Result<URL, Error> {
        guard let inputURL = selectedImageURL,
              let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return .failure(NSError(domain: "ImageMetadata", code: 1, userInfo: [NSLocalizedDescriptionKey: "No image loaded."]))
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save Privacy-Clean Image (No Location/EXIF)"
        let base = inputURL.deletingPathExtension().lastPathComponent
        let ext = inputURL.pathExtension
        savePanel.nameFieldStringValue = "\(base)_sanitized.\(ext)"
        
        guard savePanel.runModal() == .OK, let outputURL = savePanel.url else {
            return .failure(NSError(domain: "ImageMetadata", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export cancelled."]))
        }
        
        let uti = (ext.lowercased() == "png") ? (UTType.png.identifier as CFString) : (UTType.jpeg.identifier as CFString)
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, uti, 1, nil) else {
            return .failure(NSError(domain: "ImageMetadata", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed creating destination file."]))
        }
        
        // Add image without GPS or camera serial EXIF metadata!
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return .failure(NSError(domain: "ImageMetadata", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed writing sanitized image."]))
        }
        
        return .success(outputURL)
    }
}
