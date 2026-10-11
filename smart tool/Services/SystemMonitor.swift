//
//  SystemMonitor.swift
//  Borno Pulse
//

import Combine
import Foundation
import SwiftUI

@MainActor
public final class SystemMonitor: ObservableObject {
    public static let shared = SystemMonitor()
    
    @Published public private(set) var snapshot = SystemMetricsSnapshot()
    @Published public var isMonitoring = false
    @Published public var isPaused = false
    
    // History series for charts
    @Published public private(set) var cpuHistory: [Double] = []
    @Published public private(set) var gpuHistory: [Double] = []
    @Published public private(set) var memoryHistory: [Double] = []
    @Published public private(set) var downloadSpeedHistory: [Double] = []
    @Published public private(set) var uploadSpeedHistory: [Double] = []
    /// Rolling history of CPU temperature readings (°C). Only populated when sensor is available.
    @Published public private(set) var cpuTemperatureHistory: [Double] = []
    
    private let cpuProvider = CPUProvider()
    private let gpuProvider = GPUProvider()
    private let memoryProvider = MemoryProvider()
    private let sensorProvider = SensorProvider()
    private let storageProvider = StorageProvider()
    private let networkProvider = NetworkProvider()
    private let batteryProvider = BatteryProvider()
    
    private var monitoringTask: Task<Void, Never>?
    private var tickCount: UInt64 = 0
    private let maxHistoryPoints = 60
    
    private init() {
        // Initial immediate sample
        refreshNow()
        startMonitoring()
    }
    
    public func startMonitoring() {
        guard monitoringTask == nil else { return }
        isMonitoring = true
        
        monitoringTask = Task.detached(priority: .userInitiated) { [weak self] in
            while !Task.isCancelled {
                let interval = await AppSettings.shared.refreshIntervalSeconds
                
                if let self = self {
                    let paused = await self.isPaused
                    if !paused {
                        await self.performSampleCycle()
                    }
                }
                
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
    
    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
    }
    
    public func pauseMonitoring() {
        isPaused = true
    }
    
    public func resumeMonitoring() {
        isPaused = false
    }
    
    public func refreshNow() {
        Task {
            await performSampleCycle()
        }
    }
    
    private func performSampleCycle() async {
        tickCount &+= 1
        let tick = tickCount
        
        // Lightweight metrics sampled every cycle
        let cpu = cpuProvider.sample()
        let mem = memoryProvider.sample()
        let net = networkProvider.sample()
        
        // GPU and Sensors sampled every cycle or every 2 ticks
        let gpu = (tick % 2 == 0 || tick == 1) ? gpuProvider.sample() : snapshot.gpu
        let sensors = (tick % 2 == 0 || tick == 1) ? sensorProvider.sample() : snapshot.sensors
        
        // Storage and Battery are slow-changing: sampled every 5 ticks
        let storage = (tick % 5 == 0 || tick == 1) ? storageProvider.sample() : snapshot.storage
        let battery = (tick % 5 == 0 || tick == 1) ? batteryProvider.sample() : snapshot.battery
        
        // Assemble snapshot
        var newSnapshot = SystemMetricsSnapshot()
        newSnapshot.timestamp = Date()
        newSnapshot.cpu = cpu
        newSnapshot.gpu = gpu
        newSnapshot.memory = mem
        newSnapshot.sensors = sensors
        newSnapshot.storage = storage
        newSnapshot.network = net
        newSnapshot.battery = battery
        
        // Update history arrays
        self.snapshot = newSnapshot
        
        appendHistory(&self.cpuHistory, value: cpu.totalUsage)
        appendHistory(&self.gpuHistory, value: gpu.deviceUtilization ?? 0.0)
        appendHistory(&self.memoryHistory, value: mem.usagePercentage)
        appendHistory(&self.downloadSpeedHistory, value: net.downloadSpeedBytesPerSec)
        appendHistory(&self.uploadSpeedHistory, value: net.uploadSpeedBytesPerSec)
        
        self.snapshot.cpu.historicalUsage = self.cpuHistory
        self.snapshot.gpu.historicalUsage = self.gpuHistory
        self.snapshot.memory.historicalUsage = self.memoryHistory
        self.snapshot.network.historicalDownload = self.downloadSpeedHistory
        self.snapshot.network.historicalUpload = self.uploadSpeedHistory
    }
    
    private func appendHistory(_ array: inout [Double], value: Double) {
        array.append(value)
        if array.count > maxHistoryPoints {
            array.removeFirst(array.count - maxHistoryPoints)
        }
    }
}
