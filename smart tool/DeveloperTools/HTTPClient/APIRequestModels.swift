//
//  APIRequestModels.swift
//  Borno Pulse
//

import Foundation

public enum HTTPMethod: String, CaseIterable, Identifiable, Codable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    
    public var id: String { rawValue }
}

public struct HTTPHeaderItem: Identifiable, Codable, Sendable {
    public var id: UUID
    public var key: String
    public var value: String
    public var isEnabled: Bool
    
    public var isSensitive: Bool {
        let l = key.lowercased()
        return l.contains("auth") || l.contains("cookie") || l.contains("token") || l.contains("secret") || l.contains("key")
    }
    
    public init(id: UUID = UUID(), key: String, value: String, isEnabled: Bool = true) {
        self.id = id
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }
}

public struct HTTPQueryParam: Identifiable, Codable, Sendable {
    public var id: UUID
    public var key: String
    public var value: String
    public var isEnabled: Bool
    
    public init(id: UUID = UUID(), key: String, value: String, isEnabled: Bool = true) {
        self.id = id
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }
}

public struct APIResponse: Sendable {
    public let statusCode: Int
    public let statusDescription: String
    public let headers: [String: String]
    public let bodyString: String
    public let formattedBody: String
    public let durationMillis: Double
    public let byteCount: Int64
    public let isJSON: Bool
    
    public var isSuccess: Bool {
        statusCode >= 200 && statusCode < 300
    }
}

public struct APIRequestHistoryItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let urlString: String
    public let method: HTTPMethod
    public let statusCode: Int
    public let durationMillis: Double
    public let byteCount: Int64
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        urlString: String,
        method: HTTPMethod,
        statusCode: Int,
        durationMillis: Double,
        byteCount: Int64
    ) {
        self.id = id
        self.timestamp = timestamp
        self.urlString = urlString
        self.method = method
        self.statusCode = statusCode
        self.durationMillis = durationMillis
        self.byteCount = byteCount
    }
}
