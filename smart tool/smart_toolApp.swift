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
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.settings)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
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

        if CommandLine.arguments.contains("--capture-settings-screenshots") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                MainWindowRouter.shared.showMainWindow(section: .settings)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("main-window") == true }) else {
                        print("Main window not found for screenshot")
                        exit(1)
                    }
                    
                    func findScrollViews(in view: NSView) -> [NSScrollView] {
                        var res: [NSScrollView] = []
                        if let sv = view as? NSScrollView { res.append(sv) }
                        for sub in view.subviews {
                            res.append(contentsOf: findScrollViews(in: sub))
                        }
                        return res
                    }
                    
                    guard let contentView = window.contentView else { exit(1) }
                    let s = findScrollViews(in: contentView)
                    let detailSV = s.max(by: { ($0.bounds.width * $0.bounds.height) < ($1.bounds.width * $1.bounds.height) })
                    
                    func saveWindowScreenshot(named name: String) {
                        let path = "/Users/mohammadalinayeem/.gemini/antigravity-ide/brain/931ffc5a-fecb-4a17-856f-76f5eafd8b10/\(name).png"
                        if let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
                            let rep = NSBitmapImageRep(cgImage: cgImage)
                            if let data = rep.representation(using: .png, properties: [:]) {
                                try? data.write(to: URL(fileURLWithPath: path))
                                print("Captured \(name).png")
                            }
                        }
                    }
                    
                    // 1. Top
                    saveWindowScreenshot(named: "settings_top")
                    
                    // 2. Middle
                    if let sv = detailSV {
                        let mid = (sv.documentView?.bounds.height ?? 1000) * 0.4
                        sv.contentView.scroll(to: NSPoint(x: 0, y: mid))
                        sv.reflectScrolledClipView(sv.contentView)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        saveWindowScreenshot(named: "settings_middle")
                        
                        // 3. Bottom
                        if let sv = detailSV {
                            let bottom = max(0, (sv.documentView?.bounds.height ?? 1000) - sv.bounds.height)
                            sv.contentView.scroll(to: NSPoint(x: 0, y: bottom))
                            sv.reflectScrolledClipView(sv.contentView)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            saveWindowScreenshot(named: "settings_bottom")
                            exit(0)
                        }
                    }
                }
            }
        }

        if CommandLine.arguments.contains("--capture-portmanager-screenshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                MainWindowRouter.shared.showMainWindow(section: .portManager)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("main-window") == true }) else {
                        print("Main window not found for screenshot")
                        exit(1)
                    }
                    
                    let path = "/Users/mohammadalinayeem/.gemini/antigravity-ide/brain/931ffc5a-fecb-4a17-856f-76f5eafd8b10/port_manager.png"
                    if let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
                        let rep = NSBitmapImageRep(cgImage: cgImage)
                        if let data = rep.representation(using: .png, properties: [:]) {
                            try? data.write(to: URL(fileURLWithPath: path))
                            print("Captured port_manager.png")
                        }
                    }
                    
                    if let first = PortScannerService.shared.ports.first {
                        PortScannerService.shared.selectedPortItem = first
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        let pathInspector = "/Users/mohammadalinayeem/.gemini/antigravity-ide/brain/931ffc5a-fecb-4a17-856f-76f5eafd8b10/port_manager_inspector.png"
                        if let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
                            let rep = NSBitmapImageRep(cgImage: cgImage)
                            if let data = rep.representation(using: .png, properties: [:]) {
                                try? data.write(to: URL(fileURLWithPath: pathInspector))
                                print("Captured port_manager_inspector.png")
                            }
                        }
                        exit(0)
                    }
                }
            }
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
