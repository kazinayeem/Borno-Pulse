//
//  ClamshellManager.swift
//  Borno Pulse
//
//  Comprehensive Clamshell Mode & Lid-Closed Operation Controller.
//  Accurately audits Apple hardware requirements, manages native IOKit power assertions,
//  tracks session durations, monitors sleep/wake transitions, and independently verifies
//  development background workloads (Docker, servers, processes).
//

import AppKit
import Combine
import CoreGraphics
import Foundation
import IOKit.pwr_mgt
import IOKit.ps

// MARK: - Clamshell Duration
public enum ClamshellDuration: Hashable, Identifiable, Codable, Sendable {
    case oneHour
    case twoHours
    case threeHours
    case custom(hours: Int, minutes: Int)
    case untilStopped

    public var id: String {
        switch self {
        case .oneHour: return "1h"
        case .twoHours: return "2h"
        case .threeHours: return "3h"
        case .custom(let h, let m): return "custom_\(h)_\(m)"
        case .untilStopped: return "until_stopped"
        }
    }

    public var label: String {
        switch self {
        case .oneHour: return "1 Hour"
        case .twoHours: return "2 Hours"
        case .threeHours: return "3 Hours"
        case .custom(let h, let m):
            if h > 0 && m > 0 {
                return "Custom (\(h)h \(m)m)"
            } else if h > 0 {
                return "Custom (\(h)h)"
            } else {
                return "Custom (\(m)m)"
            }
        case .untilStopped: return "Until Stopped"
        }
    }

    public var totalSeconds: Int? {
        switch self {
        case .oneHour: return 3600
        case .twoHours: return 7200
        case .threeHours: return 10800
        case .custom(let h, let m):
            let sec = (h * 3600) + (m * 60)
            return max(60, sec)
        case .untilStopped: return nil
        }
    }
}

// MARK: - Clamshell Operating Mode
public enum ClamshellOperatingMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Official Apple Clamshell Mode (AC Power + External Display connected).
    case supportedClamshell = "Official Clamshell Mode"
    /// Safest supported alternative when external display or AC power are unavailable:
    /// Display is dimmed / asleep, system idle sleep prevented, lid kept open or slightly ajar for ventilation.
    case displayOffAwakeAlternative = "Display-Off Background Awake"

    public var id: String { rawValue }

    public var shortDescription: String {
        switch self {
        case .supportedClamshell:
            return "Lid closed with external display & AC power connected."
        case .displayOffAwakeAlternative:
            return "Display off / asleep, system awake, lid open/ajar for airflow."
        }
    }
}

// MARK: - Clamshell Readiness Check Item
public struct ClamshellReadinessItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let isMet: Bool
    public let isCriticalForClamshell: Bool

    public init(id: String, title: String, detail: String, isMet: Bool, isCriticalForClamshell: Bool) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isMet = isMet
        self.isCriticalForClamshell = isCriticalForClamshell
    }
}

// MARK: - Development Process Status
public struct DevProcessInfo: Identifiable, Sendable {
    public let id: Int32
    public let name: String
    public let pid: Int32
    public let cpuPercent: Double
    public let memoryFormatted: String

    public init(id: Int32, name: String, pid: Int32, cpuPercent: Double, memoryFormatted: String) {
        self.id = id
        self.name = name
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.memoryFormatted = memoryFormatted
    }
}

// MARK: - Workload Diagnostic Report
public struct WorkloadDiagnosticReport: Sendable {
    public let isMacAwake: Bool
    public let powerAssertionActive: Bool
    public let assertionID: UInt32
    public let systemUptimeFormatted: String
    public let devProcesses: [DevProcessInfo]
    public let listeningServerPorts: [Int]
    public let isDockerAvailable: Bool
    public let runningContainersCount: Int
    public let timestamp: Date

    public init(
        isMacAwake: Bool = true,
        powerAssertionActive: Bool = false,
        assertionID: UInt32 = 0,
        systemUptimeFormatted: String = "0h 0m",
        devProcesses: [DevProcessInfo] = [],
        listeningServerPorts: [Int] = [],
        isDockerAvailable: Bool = false,
        runningContainersCount: Int = 0,
        timestamp: Date = Date()
    ) {
        self.isMacAwake = isMacAwake
        self.powerAssertionActive = powerAssertionActive
        self.assertionID = assertionID
        self.systemUptimeFormatted = systemUptimeFormatted
        self.devProcesses = devProcesses
        self.listeningServerPorts = listeningServerPorts
        self.isDockerAvailable = isDockerAvailable
        self.runningContainersCount = runningContainersCount
        self.timestamp = timestamp
    }
}

// MARK: - Clamshell Manager Engine
@MainActor
public final class ClamshellManager: ObservableObject {
    public static let shared = ClamshellManager()

    // MARK: - Published State
    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var activeMode: ClamshellOperatingMode = .supportedClamshell
    @Published public var selectedDuration: ClamshellDuration = .oneHour
    @Published public var customHours: Int = 1
    @Published public var customMinutes: Int = 30
    @Published public private(set) var remainingSeconds: Int? = nil
    @Published public private(set) var startedAt: Date? = nil

    // Hardware Telemetry
    @Published public private(set) var isMacBook: Bool = true
    @Published public private(set) var hardwareModel: String = ""
    @Published public private(set) var isACPowerConnected: Bool = false
    @Published public private(set) var externalDisplayCount: Int = 0
    @Published public private(set) var externalDisplayNames: [String] = []
    @Published public private(set) var isOfficialClamshellSupported: Bool = false
    @Published public private(set) var readinessItems: [ClamshellReadinessItem] = []

    // Sleep & Wake Tracking
    @Published public private(set) var lastSleepEvent: Date? = nil
    @Published public private(set) var lastWakeEvent: Date? = nil
    @Published public private(set) var wasSleepInterrupted: Bool = false
    @Published public private(set) var sleepInterruptionMessage: String? = nil

    // Workload Verification
    @Published public private(set) var workloadReport: WorkloadDiagnosticReport = WorkloadDiagnosticReport()
    @Published public private(set) var isVerifyingWorkloads: Bool = false

    // Private Internals
    private var assertionID: IOPMAssertionID = 0
    private var countdownTimer: Timer?
    private var telemetryTimer: Timer?

    private init() {
        refreshHardwareTelemetry()
        setupNotificationObservers()

        // Periodic telemetry refresh every 5 seconds (runs on main runloop directly)
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshHardwareTelemetry()
        }
    }

    deinit {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
        }
    }

    // MARK: - Hardware & Environment Inspection
    public func refreshHardwareTelemetry() {
        // 1. Hardware Model
        var size: Int = 0
        if sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 {
            var modelChars = [CChar](repeating: 0, count: size)
            if sysctlbyname("hw.model", &modelChars, &size, nil, 0) == 0 {
                self.hardwareModel = String(cString: modelChars)
            }
        }
        if self.hardwareModel.isEmpty {
            self.hardwareModel = "Mac"
        }

        // 2. Display Topology Inspection
        var displayCount: UInt32 = 0
        var hasBuiltin = false
        var externalDisplays: [String] = []

        if CGGetOnlineDisplayList(0, nil, &displayCount) == .success, displayCount > 0 {
            var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
            if CGGetOnlineDisplayList(displayCount, &displays, &displayCount) == .success {
                for d in displays.prefix(Int(displayCount)) {
                    if CGDisplayIsBuiltin(d) != 0 {
                        hasBuiltin = true
                    } else {
                        let w = CGDisplayPixelsWide(d)
                        let h = CGDisplayPixelsHigh(d)
                        externalDisplays.append("External Display (\(w)×\(h))")
                    }
                }
            }
        }

        self.isMacBook = hasBuiltin
        self.externalDisplayCount = externalDisplays.count
        self.externalDisplayNames = externalDisplays

        // 3. Power Source Inspection (AC Power vs Battery)
        // Uses Apple's direct IOPSGetProvidingPowerSourceType API to avoid fragile
        // CFDictionary bridging and autoreleasepool dangling pointer bugs.
        var acConnected = false
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
            let pType = String(IOPSGetProvidingPowerSourceType(info).takeUnretainedValue())
            acConnected = (pType == kIOPSACPowerValue)
        }
        self.isACPowerConnected = acConnected

        // 4. Official Apple Clamshell Mode Capability Rule:
        // On Apple Silicon & Intel MacBooks, macOS kernel enforces hardware lid-sleep unless:
        // - AC Power is connected AND
        // - At least one external display is connected and active.
        self.isOfficialClamshellSupported = isMacBook && acConnected && !externalDisplays.isEmpty

        // 5. Build Readiness Checklist
        var items: [ClamshellReadinessItem] = []

        items.append(ClamshellReadinessItem(
            id: "laptop_hw",
            title: "MacBook Hardware",
            detail: isMacBook ? "Portable Mac (\(hardwareModel)) detected" : "Desktop Mac (\(hardwareModel)) has no lid",
            isMet: isMacBook,
            isCriticalForClamshell: true
        ))

        items.append(ClamshellReadinessItem(
            id: "ac_power",
            title: "AC Power Adapter",
            detail: acConnected ? "Connected to power source" : "Running on battery (Lid-closed operation requires AC power)",
            isMet: acConnected,
            isCriticalForClamshell: true
        ))

        items.append(ClamshellReadinessItem(
            id: "ext_display",
            title: "External Display",
            detail: !externalDisplays.isEmpty ? "\(externalDisplays.count) external display(s) connected" : "None detected (Apple clamshell requires an external display)",
            isMet: !externalDisplays.isEmpty,
            isCriticalForClamshell: true
        ))

        items.append(ClamshellReadinessItem(
            id: "official_support",
            title: "Official Apple Clamshell Support",
            detail: isOfficialClamshellSupported
                ? "Full Apple Clamshell Mode is supported on this setup"
                : "Standard lid-closed sleep cannot be overridden without external display & AC power",
            isMet: isOfficialClamshellSupported,
            isCriticalForClamshell: false
        ))

        self.readinessItems = items
    }

    // MARK: - Notifications Setup
    private func setupNotificationObservers() {
        // App lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )

        // System Sleep & Wake events
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Screen configuration changes (detect connecting/disconnecting monitors)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func appWillTerminate() {
        stop()
    }

    @objc private func screenParametersChanged() {
        refreshHardwareTelemetry()
    }

    @objc private func systemWillSleep() {
        lastSleepEvent = Date()
        if isActive {
            wasSleepInterrupted = true
            sleepInterruptionMessage = "macOS entered sleep at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)). Lid closure puts Mac to sleep unless official clamshell prerequisites (AC + External display) are active."
        }
    }

    @objc private func systemDidWake() {
        lastWakeEvent = Date()
        refreshHardwareTelemetry()
    }

    // MARK: - Session Control
    public func startSession(duration: ClamshellDuration? = nil, mode: ClamshellOperatingMode? = nil) {
        guard !isActive else { return }

        refreshHardwareTelemetry()

        if let d = duration {
            self.selectedDuration = d
        }

        // Determine mode: If official requirements are met, use official clamshell mode.
        // Otherwise, fall back honestly to Display-Off Background Awake mode.
        let targetMode = mode ?? (isOfficialClamshellSupported ? .supportedClamshell : .displayOffAwakeAlternative)
        self.activeMode = targetMode

        // Acquire native system power assertion
        // We use kIOPMAssertionTypePreventUserIdleSystemSleep which prevents idle system sleep
        // while honoring Apple's security and thermal boundaries.
        let assertionReason = (targetMode == .supportedClamshell)
            ? "Borno Pulse: Official Clamshell Mode Session" as CFString
            : "Borno Pulse: Display-Off Background Awake Session" as CFString

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            assertionReason,
            &assertionID
        )

        if result == kIOReturnSuccess {
            self.isActive = true
            self.startedAt = Date()
            self.wasSleepInterrupted = false
            self.sleepInterruptionMessage = nil

            // Calculate duration seconds
            let seconds: Int?
            switch selectedDuration {
            case .oneHour, .twoHours, .threeHours, .untilStopped:
                seconds = selectedDuration.totalSeconds
            case .custom(let h, let m):
                seconds = (h * 3600) + (m * 60)
            }

            self.remainingSeconds = seconds

            countdownTimer?.invalidate()
            if let initialSeconds = seconds, initialSeconds > 0 {
                countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    if let rem = self.remainingSeconds, rem > 1 {
                        self.remainingSeconds = rem - 1
                    } else {
                        self.stop()
                    }
                }
            }

            // Immediately run workload diagnostic verification
            Task {
                await self.verifyWorkloads()
            }
        } else {
            print("[ClamshellManager] Failed to create power assertion: \(result)")
            self.isActive = false
        }
    }

    public func stop() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        remainingSeconds = nil
        startedAt = nil

        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }

        isActive = false
    }

    public func toggle() {
        if isActive {
            stop()
        } else {
            startSession()
        }
    }

    // MARK: - Background Workload Verification
    public func verifyWorkloads() async {
        isVerifyingWorkloads = true
        defer { isVerifyingWorkloads = false }

        // 1. Check macOS awake state and uptime
        var bootTime = timeval()
        var bootTimeSize = MemoryLayout<timeval>.size
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var uptimeStr = "0h 0m"
        if sysctl(&mib, 2, &bootTime, &bootTimeSize, nil, 0) == 0 {
            let uptimeSeconds = Int(Date().timeIntervalSince1970 - Double(bootTime.tv_sec))
            let hours = uptimeSeconds / 3600
            let minutes = (uptimeSeconds % 3600) / 60
            uptimeStr = "\(hours)h \(minutes)m"
        }

        // 2. Discover active development processes
        // Common developer runtimes: node, python, go, cargo, java, docker, postgres, redis
        let targetProcesses: Set<String> = [
            "node", "python", "python3", "go", "cargo", "rustc",
            "java", "Docker", "dockerd", "com.docker.backend",
            "postgres", "mysqld", "redis-server", "ruby", "bun", "deno"
        ]

        var detectedProcesses: [DevProcessInfo] = []
        var pids = [pid_t](repeating: 0, count: 1024)
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.size * pids.count))
        let count = Int(bytes) / MemoryLayout<pid_t>.size

        if count > 0 {
            for i in 0..<min(count, 512) {
                let pid = pids[i]
                guard pid > 0 else { continue }
                var bsdInfo = proc_bsdinfo()
                let bsdBytes = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
                if bsdBytes == MemoryLayout<proc_bsdinfo>.size {
                    // Bounds-checked conversion preventing buffer overrun beyond 16-byte fixed buffer
                    let name = withUnsafeBytes(of: bsdInfo.pbi_comm) { rawBuffer -> String in
                        let nullTerminated = rawBuffer.prefix(while: { $0 != 0 })
                        return String(decoding: nullTerminated, as: UTF8.self)
                    }

                    if targetProcesses.contains(where: { name.lowercased().contains($0.lowercased()) }) {
                        var taskInfo = proc_taskinfo()
                        let taskBytes = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
                        let memoryFormatted: String
                        if taskBytes == MemoryLayout<proc_taskinfo>.size {
                            let mb = Double(taskInfo.pti_resident_size) / (1024.0 * 1024.0)
                            memoryFormatted = String(format: "%.1f MB", mb)
                        } else {
                            memoryFormatted = "--"
                        }

                        detectedProcesses.append(DevProcessInfo(
                            id: pid,
                            name: name,
                            pid: pid,
                            cpuPercent: 0.0,
                            memoryFormatted: memoryFormatted
                        ))
                    }
                }
            }
        }

        // 3. Discover listening dev server ports (3000, 5173, 8000, 8080, etc.)
        let listeningPorts = PortScannerService.shared.ports
            .filter { $0.listeningState == "LISTEN" }
            .map { $0.port }

        // 4. Verify Docker daemon & containers
        let dockerSummary = await DockerService.shared.fetchSummary()
        let isDockerAvail = dockerSummary.summary.isAvailable
        let runningContainers = dockerSummary.containers.filter { $0.isRunning }.count

        // Update Report
        self.workloadReport = WorkloadDiagnosticReport(
            isMacAwake: true,
            powerAssertionActive: self.isActive,
            assertionID: UInt32(self.assertionID),
            systemUptimeFormatted: uptimeStr,
            devProcesses: detectedProcesses,
            listeningServerPorts: Array(Set(listeningPorts)).sorted(),
            isDockerAvailable: isDockerAvail,
            runningContainersCount: runningContainers,
            timestamp: Date()
        )
    }

    // MARK: - Remaining Time Formatter
    public var formattedRemainingTime: String {
        guard let rem = remainingSeconds else {
            return isActive ? "Until Stopped" : "--"
        }
        let hours = rem / 3600
        let minutes = (rem % 3600) / 60
        let seconds = rem % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
