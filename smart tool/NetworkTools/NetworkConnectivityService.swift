//
//  NetworkConnectivityService.swift
//  Borno Pulse
//

import Foundation
import Network

public final class NetworkConnectivityService: @unchecked Sendable {
    public static let shared = NetworkConnectivityService()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.naem.network.connectivity")
    
    public private(set) var isInternetReachable: Bool = false
    public private(set) var isCellularOrExpensive: Bool = false
    public private(set) var currentInterfaceType: String = "Unknown"
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isInternetReachable = (path.status == .satisfied)
            self?.isCellularOrExpensive = path.isExpensive
            
            if path.usesInterfaceType(.wifi) {
                self?.currentInterfaceType = "Wi-Fi"
            } else if path.usesInterfaceType(.wiredEthernet) {
                self?.currentInterfaceType = "Wired Ethernet"
            } else if path.usesInterfaceType(.cellular) {
                self?.currentInterfaceType = "Cellular"
            } else if path.usesInterfaceType(.loopback) {
                self?.currentInterfaceType = "Loopback"
            } else {
                self?.currentInterfaceType = "Other"
            }
        }
        monitor.start(queue: queue)
    }
    
    // MARK: - Query BSD Interfaces via getifaddrs
    public func fetchInterfaces() -> [NetworkInterfaceDetail] {
        var results: [String: (name: String, ipv4: String?, ipv6: String?, isUp: Bool)] = [:]
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return []
        }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            let name = String(cString: ifa.ifa_name)
            let flags = Int32(ifa.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            
            guard let addr = ifa.ifa_addr else { continue }
            let family = addr.pointee.sa_family
            
            var ipBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if family == UInt8(AF_INET) {
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &ipBuffer, socklen_t(ipBuffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ipStr = String(cString: ipBuffer)
                    var existing = results[name] ?? (name: name, ipv4: nil, ipv6: nil, isUp: isUp)
                    existing.ipv4 = ipStr
                    results[name] = existing
                }
            } else if family == UInt8(AF_INET6) {
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &ipBuffer, socklen_t(ipBuffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ipStr = String(cString: ipBuffer)
                    var existing = results[name] ?? (name: name, ipv4: nil, ipv6: nil, isUp: isUp)
                    existing.ipv6 = ipStr
                    results[name] = existing
                }
            }
        }
        
        return results.values.map { item in
            let isWifi = item.name.hasPrefix("en0") // Common macOS standard
            let isEth = item.name.hasPrefix("en1") || item.name.hasPrefix("en2") || item.name.hasPrefix("bridge")
            let isLoop = item.name == "lo0"
            let displayName: String = {
                if isWifi { return "Wi-Fi (\(item.name))" }
                if isEth { return "Ethernet (\(item.name))" }
                if isLoop { return "Loopback (\(item.name))" }
                return "Interface (\(item.name))"
            }()
            
            return NetworkInterfaceDetail(
                name: item.name,
                displayName: displayName,
                ipv4: item.ipv4,
                ipv6: item.ipv6,
                isUp: item.isUp,
                isWiFi: isWifi,
                isEthernet: isEth,
                isLoopback: isLoop
            )
        }.sorted { $0.name < $1.name }
    }
}
