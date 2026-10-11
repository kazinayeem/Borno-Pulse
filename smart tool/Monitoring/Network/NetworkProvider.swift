//
//  NetworkProvider.swift
//  Borno Pulse
//

import Darwin
import Foundation

public final class NetworkProvider: @unchecked Sendable {
    private var previousInBytes: UInt64 = 0
    private var previousOutBytes: UInt64 = 0
    private var previousTimestamp: Date? = nil
    private let lock = NSLock()
    
    public init() {}
    
    public func sample() -> NetworkMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = NetworkMetrics()
        var currentInBytes: UInt64 = 0
        var currentOutBytes: UInt64 = 0
        var interfacesMap: [String: (displayName: String, ip: String?, isUp: Bool, isWiFi: Bool)] = [:]
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while let cur = ptr {
                let name = String(cString: cur.pointee.ifa_name)
                let flags = cur.pointee.ifa_flags
                let isUp = (flags & UInt32(IFF_UP)) != 0
                let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0
                
                if !isLoopback {
                    if let addr = cur.pointee.ifa_addr {
                        let family = addr.pointee.sa_family
                        
                        // Capture data counters
                        if family == UInt8(AF_LINK) {
                            if let ifaData = cur.pointee.ifa_data {
                                let data = ifaData.assumingMemoryBound(to: if_data.self)
                                currentInBytes += UInt64(data.pointee.ifi_ibytes)
                                currentOutBytes += UInt64(data.pointee.ifi_obytes)
                            }
                        }
                        
                        // Capture IP address
                        if family == UInt8(AF_INET) {
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            if getnameinfo(
                                addr,
                                socklen_t(addr.pointee.sa_len),
                                &hostname,
                                socklen_t(hostname.count),
                                nil,
                                0,
                                NI_NUMERICHOST
                            ) == 0 {
                                let ip = String(cString: hostname)
                                let isWiFi = name.hasPrefix("en0") || name.contains("awdl")
                                let displayName = name == "en0" ? "Wi-Fi / Primary" : (name.hasPrefix("en") ? "Ethernet (\(name))" : name)
                                interfacesMap[name] = (displayName, ip, isUp, isWiFi)
                            }
                        }
                    }
                }
                
                ptr = cur.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        
        metrics.totalReceivedBytes = currentInBytes
        metrics.totalSentBytes = currentOutBytes
        
        let now = Date()
        if let lastTime = previousTimestamp, previousInBytes > 0, previousOutBytes > 0 {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed > 0 {
                let deltaIn = currentInBytes >= previousInBytes ? (currentInBytes - previousInBytes) : 0
                let deltaOut = currentOutBytes >= previousOutBytes ? (currentOutBytes - previousOutBytes) : 0
                
                metrics.downloadSpeedBytesPerSec = Double(deltaIn) / elapsed
                metrics.uploadSpeedBytesPerSec = Double(deltaOut) / elapsed
            }
        }
        
        self.previousInBytes = currentInBytes
        self.previousOutBytes = currentOutBytes
        self.previousTimestamp = now
        
        metrics.activeInterfaces = interfacesMap.map { key, val in
            NetworkInterfaceInfo(
                name: key,
                displayName: val.displayName,
                ipAddress: val.ip,
                isUp: val.isUp,
                isWiFi: val.isWiFi
            )
        }.sorted { $0.name < $1.name }
        
        metrics.state = .available
        return metrics
    }
}
