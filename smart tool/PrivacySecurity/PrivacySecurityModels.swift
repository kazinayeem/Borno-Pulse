//
//  PrivacySecurityModels.swift
//  Borno Pulse
//

import Foundation

public enum HashAlgorithmKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case sha256 = "SHA-256 (Recommended)"
    case sha384 = "SHA-384"
    case sha512 = "SHA-512"
    case sha1 = "SHA-1 (Legacy / Insecure)"
    case md5 = "MD5 (Cryptographically Broken)"
    
    public var id: String { rawValue }
    
    public var securityAdvisory: String {
        switch self {
        case .sha256, .sha384, .sha512:
            return "Modern cryptographic standard approved for integrity verification."
        case .sha1:
            return "Legacy digest with known collision vulnerabilities. Not recommended for security-critical checks."
        case .md5:
            return "Cryptographically broken with practical collision attacks. Use only for legacy file checksums."
        }
    }
}

public struct FileHashResult: Identifiable, Sendable {
    public let id: UUID
    public let filename: String
    public let fileURL: URL
    public let fileSize: Int64
    public let algorithm: HashAlgorithmKind
    public let computedHashHex: String
    public var expectedHash: String?
    
    public var isMatch: Bool? {
        guard let expected = expectedHash, !expected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return computedHashHex.lowercased() == expected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    public init(
        id: UUID = UUID(),
        filename: String,
        fileURL: URL,
        fileSize: Int64,
        algorithm: HashAlgorithmKind,
        computedHashHex: String,
        expectedHash: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.algorithm = algorithm
        self.computedHashHex = computedHashHex
        self.expectedHash = expectedHash
    }
}

public struct PermissionAuditItem: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let featureImpact: String
    public let isGranted: Bool
    public let statusText: String
    public let systemSettingsURL: String?
    
    public init(
        name: String,
        featureImpact: String,
        isGranted: Bool,
        statusText: String,
        systemSettingsURL: String? = nil
    ) {
        self.name = name
        self.featureImpact = featureImpact
        self.isGranted = isGranted
        self.statusText = statusText
        self.systemSettingsURL = systemSettingsURL
    }
}
