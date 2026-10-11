//
//  FileHashCalculatorService.swift
//  Borno Pulse
//

import CryptoKit
import Foundation

public final class FileHashCalculatorService: Sendable {
    public static let shared = FileHashCalculatorService()
    
    private init() {}
    
    public func computeHash(for fileURL: URL, algorithm: HashAlgorithmKind) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        
        let chunkSize = 1024 * 1024 // 1 MB streaming buffer
        
        switch algorithm {
        case .sha256:
            var hasher = SHA256()
            while autoreleasepool(invoking: {
                let data = handle.readData(ofLength: chunkSize)
                if !data.isEmpty {
                    hasher.update(data: data)
                    return true
                }
                return false
            }) {}
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
            
        case .sha384:
            var hasher = SHA384()
            while autoreleasepool(invoking: {
                let data = handle.readData(ofLength: chunkSize)
                if !data.isEmpty {
                    hasher.update(data: data)
                    return true
                }
                return false
            }) {}
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
            
        case .sha512:
            var hasher = SHA512()
            while autoreleasepool(invoking: {
                let data = handle.readData(ofLength: chunkSize)
                if !data.isEmpty {
                    hasher.update(data: data)
                    return true
                }
                return false
            }) {}
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
            
        case .sha1:
            var hasher = Insecure.SHA1()
            while autoreleasepool(invoking: {
                let data = handle.readData(ofLength: chunkSize)
                if !data.isEmpty {
                    hasher.update(data: data)
                    return true
                }
                return false
            }) {}
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
            
        case .md5:
            var hasher = Insecure.MD5()
            while autoreleasepool(invoking: {
                let data = handle.readData(ofLength: chunkSize)
                if !data.isEmpty {
                    hasher.update(data: data)
                    return true
                }
                return false
            }) {}
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
        }
    }
}
