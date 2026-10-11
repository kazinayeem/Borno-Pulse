//
//  smart_toolApp.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

@main
struct smart_toolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Window("Borno Pulse", id: "main-window") {
            MainDashboardView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Monitoring") {
                Button("Refresh Telemetry Now") {
                    SystemMonitor.shared.refreshNow()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button(SystemMonitor.shared.isPaused ? "Resume Live Monitoring" : "Pause Live Monitoring") {
                    if SystemMonitor.shared.isPaused {
                        SystemMonitor.shared.resumeMonitoring()
                    } else {
                        SystemMonitor.shared.pauseMonitoring()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            CommandMenu("Cleaner") {
                Button("Scan Caches Now") {
                    CacheCleanupService.shared.scanAll()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppearanceController.shared.start()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--run-tests") {
            let results = SmartToolTests.runAllTests()
            print("--- INVARIANT TESTS COMPLETED ---")
            print("Passed: \(results.passed), Failed: \(results.failed)")
            for log in results.logs {
                print(log)
            }
            exit(results.failed == 0 ? 0 : 1)
        }

        // A second copy would add duplicate menu bar items and a second clipboard monitor.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let bundleID = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != ownPID && !$0.isTerminated }) {
            existing.activate()
            NSApp.terminate(nil)
            return
        }
        
        // Setup Menu Bar Status Item & Popover
        MenuBarCoordinator.shared.setup()
        
        // Start system monitoring engine
        SystemMonitor.shared.startMonitoring()

        // Clipboard history, global shortcut and clipboard status item live for the whole app session.
        ClipboardBackgroundController.shared.start()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let proceed = MainActor.assumeIsolated {
            PDFEditorService.shared.confirmProceedWithUnsavedChanges(before: "quitting")
        }
        return proceed ? .terminateNow : .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar even when main dashboard window is closed!
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindowRouter.shared.showMainWindow()
            return false
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ClipboardBackgroundController.shared.stop()
        SystemMonitor.shared.stopMonitoring()
    }
}
