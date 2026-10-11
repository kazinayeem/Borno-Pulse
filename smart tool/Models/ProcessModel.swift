//
//  ProcessModel.swift
//  Borno Pulse
//

import Foundation

public struct ProcessItem: Identifiable, Sendable {
    public var id: pid_t { pid }
    public var pid: pid_t
    public var name: String
    public var cpuPercentage: Double
    public var residentMemoryBytes: UInt64
    public var user: String
    public var isCurrentProcess: Bool
    public var threadCount: Int
    
    public var energyImpactScore: Double {
        return (cpuPercentage * 0.8) + (Double(residentMemoryBytes) / (1024 * 1024 * 1024) * 5.0)
    }
    
    public init(
        pid: pid_t,
        name: String,
        cpuPercentage: Double,
        residentMemoryBytes: UInt64,
        user: String = "User",
        isCurrentProcess: Bool = false,
        threadCount: Int = 1
    ) {
        self.pid = pid
        self.name = name
        self.cpuPercentage = cpuPercentage
        self.residentMemoryBytes = residentMemoryBytes
        self.user = user
        self.isCurrentProcess = isCurrentProcess
        self.threadCount = threadCount
    }
}
