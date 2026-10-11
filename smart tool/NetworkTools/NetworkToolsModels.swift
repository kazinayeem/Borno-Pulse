//
//  NetworkToolsModels.swift
//  Borno Pulse
//

import Foundation

// MARK: - Connectivity Models
public struct NetworkInterfaceDetail: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let displayName: String
    public let ipv4: String?
    public let ipv6: String?
    public let isUp: Bool
    public let isWiFi: Bool
    public let isEthernet: Bool
    public let isLoopback: Bool
    
    public init(
        name: String,
        displayName: String,
        ipv4: String? = nil,
        ipv6: String? = nil,
        isUp: Bool = true,
        isWiFi: Bool = false,
        isEthernet: Bool = false,
        isLoopback: Bool = false
    ) {
        self.name = name
        self.displayName = displayName
        self.ipv4 = ipv4
        self.ipv6 = ipv6
        self.isUp = isUp
        self.isWiFi = isWiFi
        self.isEthernet = isEthernet
        self.isLoopback = isLoopback
    }
}

// MARK: - Ping Models
public struct PingPacket: Identifiable, Sendable {
    public let id: UUID
    public let seq: Int
    public let rttMs: Double
    public let isSuccess: Bool
    public let errorMessage: String?
    
    public init(id: UUID = UUID(), seq: Int, rttMs: Double, isSuccess: Bool = true, errorMessage: String? = nil) {
        self.id = id
        self.seq = seq
        self.rttMs = rttMs
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
    }
}

public struct PingSummary: Sendable {
    public let host: String
    public let transmitted: Int
    public let received: Int
    public let packetLossPercent: Double
    public let minRttMs: Double
    public let maxRttMs: Double
    public let avgRttMs: Double
    
    public init(
        host: String,
        transmitted: Int = 0,
        received: Int = 0,
        packetLossPercent: Double = 0,
        minRttMs: Double = 0,
        maxRttMs: Double = 0,
        avgRttMs: Double = 0
    ) {
        self.host = host
        self.transmitted = transmitted
        self.received = received
        self.packetLossPercent = packetLossPercent
        self.minRttMs = minRttMs
        self.maxRttMs = maxRttMs
        self.avgRttMs = avgRttMs
    }
}

// MARK: - DNS Models
public enum DNSRecordType: String, CaseIterable, Identifiable, Sendable {
    case a = "A"
    case aaaa = "AAAA"
    case cname = "CNAME"
    case mx = "MX"
    case txt = "TXT"
    case ns = "NS"
    case ptr = "PTR"
    
    public var id: String { rawValue }
}

public struct DNSRecordItem: Identifiable, Sendable {
    public let id: UUID
    public let type: DNSRecordType
    public let name: String
    public let value: String
    public let ttl: Int?
    
    public init(id: UUID = UUID(), type: DNSRecordType, name: String, value: String, ttl: Int? = nil) {
        self.id = id
        self.type = type
        self.name = name
        self.value = value
        self.ttl = ttl
    }
}

// MARK: - SSL Certificate Details
public struct SSLCertificateDetails: Sendable {
    public let host: String
    public let port: Int
    public let commonName: String
    public let issuer: String
    public let validFrom: Date?
    public let validUntil: Date?
    public let remainingDays: Int?
    public let isTrusted: Bool
    public let isExpired: Bool
    public let signatureAlgorithm: String
    public let sanDNSNames: [String]
    
    public init(
        host: String,
        port: Int,
        commonName: String,
        issuer: String,
        validFrom: Date?,
        validUntil: Date?,
        remainingDays: Int?,
        isTrusted: Bool,
        isExpired: Bool,
        signatureAlgorithm: String = "SHA-256 with RSA/ECDSA",
        sanDNSNames: [String] = []
    ) {
        self.host = host
        self.port = port
        self.commonName = commonName
        self.issuer = issuer
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.remainingDays = remainingDays
        self.isTrusted = isTrusted
        self.isExpired = isExpired
        self.signatureAlgorithm = signatureAlgorithm
        self.sanDNSNames = sanDNSNames
    }
}
