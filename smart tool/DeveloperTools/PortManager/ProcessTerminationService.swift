//
//  ProcessTerminationService.swift
//  Borno Pulse
//
//  Safely controls process termination with identity verification, system daemon
//  protection, graceful SIGTERM -> SIGKILL sequencing, and Docker integration.
//

import AppKit
import Darwin
import Foundation

public enum TerminationResult: Sendable {
    case success(message: String)
    case requiresForceKill(message: String)
    case failed(reason: String)
}

public final class ProcessTerminationService: Sendable {
    public static let shared = ProcessTerminationService()
    
    private init() {}
    
    // Critical macOS system daemons that must NEVER be terminated through Port Manager
    private let protectedSystemProcesses: Set<String> = [
        "launchd",
        "kernel_task",
        "WindowServer",
        "loginwindow",
        "logd",
        "fseventsd",
        "syspolicyd",
        "opendirectoryd",
        "trustd",
        "rapportd",
        "identityservicesd",
        "securityd",
        "diskarbitrationd",
        "coreaudiod",
        "AirPlayXPCHelper",
        "mds",
        "mds_stores"
    ]
    
    // MARK: - Validation
    public func validateCanTerminate(item: PortItem) -> (canTerminate: Bool, reason: String?) {
        let currentPid = getpid()
        if item.pid == currentPid {
            return (false, "Cannot stop Borno Pulse from its own Port Manager.")
        }
        
        if item.pid <= 1 {
            return (false, "Cannot terminate PID \(item.pid) (root init system).")
        }
        
        let procName = item.processName.trimmingCharacters(in: .whitespaces)
        if protectedSystemProcesses.contains(procName) {
            return (false, "Refusing to terminate critical macOS system daemon '\(procName)' (PID: \(item.pid)).")
        }
        
        // Check if process still exists and belongs to the expected name
        if !isProcessAlive(pid: item.pid) {
            return (false, "Process \(procName) (PID: \(item.pid)) has already terminated.")
        }
        
        if !verifyProcessIdentity(pid: item.pid, expectedName: item.processName) {
            return (false, "Process identity mismatch: PID \(item.pid) has been recycled by another process. Aborting for safety.")
        }
        
        return (true, nil)
    }
    
    // MARK: - Graceful Termination (SIGTERM)
    public func terminateGracefully(item: PortItem, timeout: TimeInterval = 1.5) async -> TerminationResult {
        let validation = validateCanTerminate(item: item)
        guard validation.canTerminate else {
            return .failed(reason: validation.reason ?? "Safety validation failed.")
        }
        
        let pid = item.pid
        let res = kill(pid, SIGTERM)
        if res != 0 {
            let err = errno
            if err == EPERM {
                return .failed(reason: "Permission denied terminating \(item.processName) (PID: \(pid)). It may be owned by root or another user.")
            } else if err == ESRCH {
                return .success(message: "Process \(item.processName) (PID: \(pid)) had already exited.")
            } else {
                return .failed(reason: "Failed to send SIGTERM to PID \(pid): errno \(err).")
            }
        }
        
        // Wait for process to exit
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            if !isProcessAlive(pid: pid) {
                return .success(message: "Successfully stopped \(item.processName) (PID: \(pid)) gracefully.")
            }
        }
        
        // Process is still running after timeout
        return .requiresForceKill(message: "\(item.processName) (PID: \(pid)) did not exit within \(String(format: "%.1f", timeout))s. You can force-stop it with SIGKILL.")
    }
    
    // MARK: - Force Termination (SIGKILL)
    public func forceTerminate(item: PortItem) async -> TerminationResult {
        let validation = validateCanTerminate(item: item)
        guard validation.canTerminate else {
            return .failed(reason: validation.reason ?? "Safety validation failed.")
        }
        
        let pid = item.pid
        let res = kill(pid, SIGKILL)
        if res != 0 {
            let err = errno
            if err == EPERM {
                return .failed(reason: "Permission denied force-terminating \(item.processName) (PID: \(pid)). Requires elevated permissions.")
            } else if err == ESRCH {
                return .success(message: "Process \(item.processName) (PID: \(pid)) has exited.")
            } else {
                return .failed(reason: "Failed to send SIGKILL to PID \(pid): errno \(err).")
            }
        }
        
        // Short delay to ensure OS clears PID table
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        if !isProcessAlive(pid: pid) {
            return .success(message: "Force-stopped \(item.processName) (PID: \(pid)).")
        } else {
            return .failed(reason: "Process \(item.processName) (PID: \(pid)) did not exit even after SIGKILL.")
        }
    }
    
    // MARK: - Docker Container Stop
    public func stopDockerContainer(containerID: String) async -> TerminationResult {
        let success = await DockerService.shared.stopContainer(id: containerID)
        if success {
            return .success(message: "Docker container \(containerID.prefix(12)) stopped successfully.")
        } else {
            return .failed(reason: "Failed to stop Docker container \(containerID.prefix(12)). Check Docker daemon status.")
        }
    }
    
    // MARK: - Helpers
    public func isProcessAlive(pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        // Sending signal 0 checks for existence without delivering a signal
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM // Process exists, but we don't have permission to signal it
    }
    
    public func verifyProcessIdentity(pid: pid_t, expectedName: String) -> Bool {
        var bsdInfo = proc_bsdinfo()
        let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
        guard size == MemoryLayout<proc_bsdinfo>.size else { return false }
        
        let currentName = withUnsafePointer(to: &bsdInfo.pbi_comm) { ptr in
            String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }.trimmingCharacters(in: .whitespaces)
        
        guard !currentName.isEmpty else { return false }
        let exp = expectedName.trimmingCharacters(in: .whitespaces)
        
        return currentName.localizedCaseInsensitiveContains(exp) || exp.localizedCaseInsensitiveContains(currentName)
    }
}
