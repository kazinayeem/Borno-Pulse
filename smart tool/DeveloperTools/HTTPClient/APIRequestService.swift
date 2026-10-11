//
//  APIRequestService.swift
//  Borno Pulse
//

import Foundation

public final class APIRequestService: Sendable {
    public static let shared = APIRequestService()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        // Enforce strict system TLS validation (never bypass certificate checks)
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Execute Request
    public func execute(
        urlString: String,
        method: HTTPMethod,
        headers: [HTTPHeaderItem],
        queryParams: [HTTPQueryParam],
        bodyString: String?,
        allowLocalNetwork: Bool = true
    ) async throws -> APIResponse {
        guard var urlComponents = URLComponents(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw NSError(domain: "HTTPError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL string"])
        }
        
        guard let scheme = urlComponents.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw NSError(domain: "HTTPError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid scheme. Only http:// and https:// are supported."])
        }
        
        // Private network guard
        if let host = urlComponents.host?.lowercased() {
            let isLocal = host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasPrefix("192.168.") || host.hasPrefix("10.")
            if isLocal && !allowLocalNetwork {
                throw NSError(domain: "HTTPError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Local network destination blocked. Enable 'Allow Local / Private Network' in settings to test local endpoints."])
            }
        }
        
        // Append Query Parameters
        let activeParams = queryParams.filter { $0.isEnabled && !$0.key.isEmpty }
        if !activeParams.isEmpty {
            var existingItems = urlComponents.queryItems ?? []
            for p in activeParams {
                existingItems.append(URLQueryItem(name: p.key, value: p.value))
            }
            urlComponents.queryItems = existingItems
        }
        
        guard let finalURL = urlComponents.url else {
            throw NSError(domain: "HTTPError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not construct URL with query parameters"])
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        
        // Attach Headers
        for h in headers where h.isEnabled && !h.key.isEmpty {
            request.setValue(h.value, forHTTPHeaderField: h.key)
        }
        
        // Attach Body
        if method != .get && method != .head, let b = bodyString, !b.isEmpty {
            request.httpBody = b.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                // If starts with { or [, set application/json
                let trimmed = b.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await session.data(for: request)
        let durationMillis = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "HTTPError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Non-HTTP response received"])
        }
        
        // Process Headers
        var respHeaders: [String: String] = [:]
        for (k, v) in httpResponse.allHeaderFields {
            respHeaders["\(k)"] = "\(v)"
        }
        
        let bodyStr = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? "(Binary data)"
        
        // Pretty JSON check
        var isJSON = false
        var formatted = bodyStr
        if let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted, .sortedKeys]),
           let prettyStr = String(data: prettyData, encoding: .utf8) {
            isJSON = true
            formatted = prettyStr
        }
        
        let apiResp = APIResponse(
            statusCode: httpResponse.statusCode,
            statusDescription: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
            headers: respHeaders,
            bodyString: bodyStr,
            formattedBody: formatted,
            durationMillis: durationMillis,
            byteCount: Int64(data.count),
            isJSON: isJSON
        )
        
        // Record into local history
        saveHistory(item: APIRequestHistoryItem(
            urlString: finalURL.absoluteString,
            method: method,
            statusCode: httpResponse.statusCode,
            durationMillis: durationMillis,
            byteCount: Int64(data.count)
        ))
        
        return apiResp
    }
    
    // MARK: - Secret Redaction Helper
    public static func redactHeaders(_ headers: [HTTPHeaderItem]) -> [HTTPHeaderItem] {
        return headers.map { item in
            if item.isSensitive {
                return HTTPHeaderItem(id: item.id, key: item.key, value: "[REDACTED_SECRET]", isEnabled: item.isEnabled)
            }
            return item
        }
    }
    
    // MARK: - Local History
    private var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NaemSmartTool/DeveloperTools", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("http_history.json")
    }
    
    public func loadHistory() -> [APIRequestHistoryItem] {
        guard let data = try? Data(contentsOf: historyFileURL),
              let list = try? JSONDecoder().decode([APIRequestHistoryItem].self, from: data) else {
            return []
        }
        return list
    }
    
    private func saveHistory(item: APIRequestHistoryItem) {
        var current = loadHistory()
        current.insert(item, at: 0)
        if current.count > 100 { current = Array(current.prefix(100)) }
        if let data = try? JSONEncoder().encode(current) {
            try? data.write(to: historyFileURL, options: .atomic)
        }
    }
    
    public func clearHistory() {
        try? FileManager.default.removeItem(at: historyFileURL)
    }
}
