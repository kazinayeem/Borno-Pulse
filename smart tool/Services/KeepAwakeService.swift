//
//  KeepAwakeService.swift
//  Borno Pulse
//
//  Display and system sleep prevention service using documented macOS IOKit IOPMLib.
//  Ensures power assertions are safely acquired, tracked, and released on quit.
//

import AppKit
import Foundation
import IOKit.pwr_mgt

@MainActor
public final class KeepAwakeService: ObservableObject {
    public static let shared = KeepAwakeService()

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var activeAssertionType: String = ""
    @Published public private(set) var remainingSeconds: Int? = nil

    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    deinit {
        // Safe fallback in case instance is torn down
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
        }
    }

    @objc private func appWillTerminate() {
        stop()
    }

    /// Toggles the sleep prevention state.
    public func toggle(durationSeconds: Int? = nil) {
        if isActive {
            stop()
        } else {
            start(durationSeconds: durationSeconds)
        }
    }

    /// Starts preventing display and system idle sleep.
    public func start(durationSeconds: Int? = nil) {
        guard !isActive else { return }

        let reason = "Borno Pulse Quick Action: Keep Display Awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        if result == kIOReturnSuccess {
            isActive = true
            activeAssertionType = "Display & System Awake"
            
            if let duration = durationSeconds, duration > 0 {
                remainingSeconds = duration
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if let rem = self.remainingSeconds, rem > 1 {
                            self.remainingSeconds = rem - 1
                        } else {
                            self.stop()
                        }
                    }
                }
            } else {
                remainingSeconds = nil
            }
        } else {
            print("[KeepAwakeService] Failed to acquire power assertion: \(result)")
            isActive = false
        }
    }

    /// Stops preventing sleep and releases the system assertion.
    public func stop() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = nil

        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        isActive = false
        activeAssertionType = ""
    }
}
