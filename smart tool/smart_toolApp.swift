//
//  smart_toolApp.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

@main
struct smart_toolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var settings = AppSettings.shared
    
    var body: some Scene {
        Window("Borno Pulse", id: "main-window") {
            MainDashboardView()
                .frame(minWidth: 960, minHeight: 640)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
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
        
        // Setup Menu Bar Status Item & Popover
        MenuBarCoordinator.shared.setup()
        
        // Start system monitoring engine
        SystemMonitor.shared.startMonitoring()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar even when main dashboard window is closed!
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        SystemMonitor.shared.stopMonitoring()
    }
}
