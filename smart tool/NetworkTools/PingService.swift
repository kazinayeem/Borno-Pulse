//
//  PingService.swift
//  Borno Pulse
//

import Foundation

public final class PingService: Sendable {
    public static let shared = PingService()
    
    private init() {}
    
    public func ping(host: String, count: Int = 5, timeoutSeconds: Int = 2) -> AsyncStream<PingPacket> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "\(count)", "-t", "\(timeoutSeconds)", host]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            let outHandle = pipe.fileHandleForReading
            
            continuation.onTermination = { _ in
                if process.isRunning {
                    process.terminate()
                }
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try process.run()
                    
                    var seqCounter = 1
                    var buffer = Data()
                    
                    while process.isRunning || outHandle.availableData.count > 0 {
                        let chunk = outHandle.availableData
                        if chunk.isEmpty && !process.isRunning { break }
                        buffer.append(chunk)
                        
                        if let text = String(data: buffer, encoding: .utf8) {
                            var lines = text.components(separatedBy: "\n")
                            if lines.count > 1 {
                                // Keep last partial line in buffer
                                let remaining = lines.removeLast()
                                buffer = remaining.data(using: .utf8) ?? Data()
                                
                                for line in lines {
                                    if line.contains("icmp_seq=") || line.contains("time=") {
                                        let rtt = Self.parseRTT(from: line)
                                        continuation.yield(PingPacket(seq: seqCounter, rttMs: rtt, isSuccess: rtt > 0))
                                        seqCounter += 1
                                    } else if line.contains("Request timeout") || line.contains("Host is down") {
                                        continuation.yield(PingPacket(seq: seqCounter, rttMs: 0, isSuccess: false, errorMessage: "Timeout"))
                                        seqCounter += 1
                                    }
                                }
                            }
                        }
                    }
                    
                    process.waitUntilExit()
                    continuation.finish()
                } catch {
                    continuation.yield(PingPacket(seq: 1, rttMs: 0, isSuccess: false, errorMessage: error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }
    
    public static func parseRTT(from line: String) -> Double {
        // Look for time=XX.X ms
        if let regex = try? NSRegularExpression(pattern: "time=([0-9.]+)\\s*ms"),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line),
           let rtt = Double(line[range]) {
            return rtt
        }
        return 0.0
    }
}

