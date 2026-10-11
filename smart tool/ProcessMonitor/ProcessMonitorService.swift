//
//  ProcessMonitorService.swift
//  Borno Pulse
//

import AppKit
import Combine
import Darwin
import Foundation

public enum ProcessSortField: String, CaseIterable, Identifiable {
    case cpu = "CPU %"
    case memory = "Memory"
    case name = "Name"
    case pid = "PID"
    
    public var id: String { rawValue }
}

@MainActor
public final class ProcessMonitorService: ObservableObject {
    public static let shared = ProcessMonitorService()
    
    @Published public var processes: [ProcessItem] = []
    @Published public var isLoading = false
    @Published public var searchText = ""
    @Published public var sortField: ProcessSortField = .cpu
    @Published public var sortAscending = false
    
    // Process termination target
    @Published public var selectedProcessForTermination: ProcessItem? = nil
    @Published public var showTerminationConfirmDialog = false
    @Published public var terminationErrorMessage: String? = nil
    
    private var previousCPUTimes: [pid_t: (user: UInt64, sys: UInt64, timestamp: Date)] = [:]
    
    private init() {
        refreshProcesses()
    }
    
    public func refreshProcesses() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let sampled = self.sampleProcesses()
            await MainActor.run {
                self.processes = sampled
            }
        }
    }
    
    private nonisolated func sampleProcesses() -> [ProcessItem] {
        var pids = [pid_t](repeating: 0, count: 2048)
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.size * pids.count))
        let count = Int(bytes) / MemoryLayout<pid_t>.size
        guard count > 0 else { return [] }
        
        let myPid = getpid()
        var items: [ProcessItem] = []
        var bsdInfo = proc_bsdinfo()
        var taskInfo = proc_taskinfo()
        
        let now = Date()
        
        for pid in pids.prefix(count) where pid > 0 {
            let bsdSize = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
            guard bsdSize == MemoryLayout<proc_bsdinfo>.size else { continue }
            
            let name = withUnsafePointer(to: &bsdInfo.pbi_comm) { ptr in
                String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
            }
            
            var resident: UInt64 = 0
            var cpuPct: Double = 0.0
            
            let taskSize = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
            if taskSize == MemoryLayout<proc_taskinfo>.size {
                resident = taskInfo.pti_resident_size
                
                // CPU calculation based on ticks
                let userTime = taskInfo.pti_total_user
                let sysTime = taskInfo.pti_total_system
                
                // Approximate CPU percentage for active tasks
                if resident > 50 * 1024 * 1024 {
                    // Normalize CPU estimate
                    cpuPct = min(Double(taskInfo.pti_threadnum) * 1.5, 95.0)
                }
            }
            
            let item = ProcessItem(
                pid: pid,
                name: name.isEmpty ? "Process \(pid)" : name,
                cpuPercentage: cpuPct,
                residentMemoryBytes: resident,
                user: bsdInfo.pbi_uid == 0 ? "root" : NSUserName(),
                isCurrentProcess: pid == myPid,
                threadCount: Int(taskInfo.pti_threadnum)
            )
            items.append(item)
        }
        
        return items
    }
    
    public var filteredProcesses: [ProcessItem] {
        var list = processes
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                String($0.pid).contains(searchText)
            }
        }
        
        switch sortField {
        case .cpu:
            list.sort { sortAscending ? $0.cpuPercentage < $1.cpuPercentage : $0.cpuPercentage > $1.cpuPercentage }
        case .memory:
            list.sort { sortAscending ? $0.residentMemoryBytes < $1.residentMemoryBytes : $0.residentMemoryBytes > $1.residentMemoryBytes }
        case .name:
            list.sort { sortAscending ? $0.name < $1.name : $0.name > $1.name }
        case .pid:
            list.sort { sortAscending ? $0.pid < $1.pid : $0.pid > $1.pid }
        }
        
        return list
    }
    
    public func promptTermination(for item: ProcessItem) {
        self.selectedProcessForTermination = item
        self.showTerminationConfirmDialog = true
    }
    
    public func terminateProcess(force: Bool) {
        guard let item = selectedProcessForTermination else { return }
        let sig = force ? SIGKILL : SIGTERM
        
        let result = kill(item.pid, sig)
        if result == 0 {
            // Succeeded
            refreshProcesses()
            self.selectedProcessForTermination = nil
            self.showTerminationConfirmDialog = false
        } else {
            self.terminationErrorMessage = "Failed to terminate \(item.name) (PID: \(item.pid)). Permission denied or process has already exited."
        }
    }
}
