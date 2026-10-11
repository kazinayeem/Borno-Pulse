//
//  ChecksumService.swift
//  Borno Pulse
//

import Combine
import CryptoKit
import Foundation

public struct ChecksumResult: Sendable {
    public var sha256: String
    public var md5: String
    public var sha1: String
    public var fileSize: UInt64
    
    public init(sha256: String = "", md5: String = "", sha1: String = "", fileSize: UInt64 = 0) {
        self.sha256 = sha256
        self.md5 = md5
        self.sha1 = sha1
        self.fileSize = fileSize
    }
}

@MainActor
public final class ChecksumService: ObservableObject {
    public static let shared = ChecksumService()
    
    @Published public var selectedFileURL: URL?
    @Published public var result: ChecksumResult = ChecksumResult()
    @Published public var comparisonHash: String = ""
    @Published public var hashMatchStatus: String? = nil
    @Published public var isComputing: Bool = false
    @Published public var statusMessage: String = "No file selected"
    
    public init() {}
    
    public func computeChecksum(for url: URL) {
        self.selectedFileURL = url
        self.isComputing = true
        self.hashMatchStatus = nil
        self.statusMessage = "Hashing \(url.lastPathComponent)..."
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            do {
                let fileData = try Data(contentsOf: url, options: .mappedIfSafe)
                let sha256Hash = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
                let md5Hash = Insecure.MD5.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
                let sha1Hash = Insecure.SHA1.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
                
                let res = ChecksumResult(
                    sha256: sha256Hash,
                    md5: md5Hash,
                    sha1: sha1Hash,
                    fileSize: UInt64(fileData.count)
                )
                
                await MainActor.run {
                    self.result = res
                    self.isComputing = false
                    self.statusMessage = "Checksum computation completed."
                    self.verifyMatch()
                }
            } catch {
                await MainActor.run {
                    self.isComputing = false
                    self.statusMessage = "Error reading file: \(error.localizedDescription)"
                }
            }
        }
    }
    
    public func verifyMatch() {
        let expected = comparisonHash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !expected.isEmpty else {
            hashMatchStatus = nil
            return
        }
        
        if result.sha256.lowercased() == expected ||
           result.md5.lowercased() == expected ||
           result.sha1.lowercased() == expected {
            hashMatchStatus = "MATCH: Checksum matches file contents perfectly!"
        } else {
            hashMatchStatus = "MISMATCH: Checksum does NOT match this file."
        }
    }
}
