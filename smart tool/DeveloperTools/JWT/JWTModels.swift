//
//  JWTModels.swift
//  Borno Pulse
//

import Foundation

public struct JWTClaimItem: Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let value: String
    public let standardDescription: String?
    
    public init(key: String, value: String, standardDescription: String? = nil) {
        self.key = key
        self.value = value
        self.standardDescription = standardDescription
    }
}

public struct JWTTokenDetails: Sendable {
    public let algorithm: String?
    public let tokenType: String?
    public let headerJSON: String
    public let payloadJSON: String
    public let signature: String
    
    // Standard Registered Claims
    public let issuer: String?
    public let subject: String?
    public let audience: String?
    public let expirationDate: Date?
    public let notBeforeDate: Date?
    public let issuedAtDate: Date?
    public let jwtId: String?
    
    public let isExpired: Bool
    public let remainingSeconds: TimeInterval?
    public let claims: [JWTClaimItem]
    
    public init(
        algorithm: String?,
        tokenType: String?,
        headerJSON: String,
        payloadJSON: String,
        signature: String,
        issuer: String? = nil,
        subject: String? = nil,
        audience: String? = nil,
        expirationDate: Date? = nil,
        notBeforeDate: Date? = nil,
        issuedAtDate: Date? = nil,
        jwtId: String? = nil,
        isExpired: Bool = false,
        remainingSeconds: TimeInterval? = nil,
        claims: [JWTClaimItem] = []
    ) {
        self.algorithm = algorithm
        self.tokenType = tokenType
        self.headerJSON = headerJSON
        self.payloadJSON = payloadJSON
        self.signature = signature
        self.issuer = issuer
        self.subject = subject
        self.audience = audience
        self.expirationDate = expirationDate
        self.notBeforeDate = notBeforeDate
        self.issuedAtDate = issuedAtDate
        self.jwtId = jwtId
        self.isExpired = isExpired
        self.remainingSeconds = remainingSeconds
        self.claims = claims
    }
}
