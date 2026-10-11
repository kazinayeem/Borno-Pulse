//
//  DNSLookupService.swift
//  Borno Pulse
//

import Foundation

public final class DNSLookupService: Sendable {
    public static let shared = DNSLookupService()
    
    private init() {}
    
    public func lookup(host: String, type: DNSRecordType) async throws -> (records: [DNSRecordItem], durationMs: Double) {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else {
            throw NSError(domain: "DNSError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Host cannot be empty"])
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Execute /usr/bin/dig if available
        let digPath = "/usr/bin/dig"
        guard FileManager.default.isExecutableFile(atPath: digPath) else {
            // Fallback via getaddrinfo
            let records = try lookupAddrInfo(host: cleanHost, type: type)
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return (records, duration)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: digPath)
        process.arguments = ["+noall", "+answer", "+time=3", cleanHost, type.rawValue]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        
        var records: [DNSRecordItem] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix(";") else { continue }
            
            // Format: name  ttl  IN  type  value...
            let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if tokens.count >= 5 {
                let name = tokens[0]
                let ttl = Int(tokens[1])
                let rTypeStr = tokens[3]
                let val = tokens[4...].joined(separator: " ")
                let recType = DNSRecordType(rawValue: rTypeStr.uppercased()) ?? type
                records.append(DNSRecordItem(type: recType, name: name, value: val, ttl: ttl))
            }
        }
        
        return (records, duration)
    }
    
    private func lookupAddrInfo(host: String, type: DNSRecordType) throws -> [DNSRecordItem] {
        var hints = addrinfo()
        hints.ai_socktype = SOCK_STREAM
        hints.ai_family = (type == .aaaa) ? AF_INET6 : AF_INET
        
        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &res)
        guard status == 0, let first = res else {
            throw NSError(domain: "DNSError", code: 2, userInfo: [NSLocalizedDescriptionKey: "DNS resolution failed: \(String(cString: gai_strerror(status)))"])
        }
        defer { freeaddrinfo(res) }
        
        var list: [DNSRecordItem] = []
        for ptr in sequence(first: first, next: { $0.pointee.ai_next }) {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(ptr.pointee.ai_addr, ptr.pointee.ai_addrlen, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                let ipStr = String(cString: buffer)
                list.append(DNSRecordItem(type: type, name: host, value: ipStr))
            }
        }
        return list
    }
}
