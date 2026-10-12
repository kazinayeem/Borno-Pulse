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
            CommandGroup(replacing: .appInfo) {
                Button("About Borno Pulse") {
                    NotificationCenter.default.post(name: .showAboutDeveloper, object: nil)
                }
            }
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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    public static var isQuitting: Bool = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
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

        if CommandLine.arguments.contains("--capture-all-screenshots") {
            let outputDir: URL
            if let idx = CommandLine.arguments.firstIndex(of: "--output-dir"), idx + 1 < CommandLine.arguments.count {
                outputDir = URL(fileURLWithPath: CommandLine.arguments[idx + 1])
            } else if let idx = CommandLine.arguments.firstIndex(of: "--capture-all-screenshots"), idx + 1 < CommandLine.arguments.count, !CommandLine.arguments[idx + 1].hasPrefix("-") {
                outputDir = URL(fileURLWithPath: CommandLine.arguments[idx + 1])
            } else {
                outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("screenshots")
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                await ScreenshotAutomationService.run(outputDir: outputDir)
                exit(0)
            }
            return
        }

        if CommandLine.arguments.contains("--capture-settings-screenshots") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                MainWindowRouter.shared.showMainWindow(section: .settings)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("main-window") == true }) else {
                        print("Main window not found for screenshot")
                        exit(1)
                    }
                    
                    @MainActor
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
                    
                    @MainActor
                    func saveWindowScreenshot(named name: String) {
                        let path = "/Users/mohammadalinayeem/.gemini/antigravity-ide/brain/931ffc5a-fecb-4a17-856f-76f5eafd8b10/\(name).png"
                        if let rep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) {
                            contentView.cacheDisplay(in: contentView.bounds, to: rep)
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
                    guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("main-window") == true }),
                          let contentView = window.contentView else {
                        print("Main window not found for screenshot")
                        exit(1)
                    }
                    
                    let path = "/Users/mohammadalinayeem/.gemini/antigravity-ide/brain/931ffc5a-fecb-4a17-856f-76f5eafd8b10/port_manager.png"
                    if let rep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) {
                        contentView.cacheDisplay(in: contentView.bounds, to: rep)
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
                        if let rep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) {
                            contentView.cacheDisplay(in: contentView.bounds, to: rep)
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

        // Enforce normal macOS Dock application activation policy
        NSApp.setActivationPolicy(.regular)

        // A second copy would add duplicate menu bar items and a second clipboard monitor.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let bundleID = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != ownPID && !$0.isTerminated }) {
            existing.activate(options: [.activateIgnoringOtherApps])
            NSApp.terminate(nil)
            return
        }
        
        // Setup Menu Bar Status Item & Popover
        MenuBarCoordinator.shared.setup()
        
        // Start system monitoring engine
        SystemMonitor.shared.startMonitoring()

        // Clipboard history, global shortcut and clipboard status item live for the whole app session.
        ClipboardBackgroundController.shared.start()

        // Observe when windows become main to register them with the router and attach delegate
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow,
               !(window is NSPanel),
               window.canBecomeKey {
                MainWindowRouter.shared.register(window: window)
            }
        }

        // Connect any already created main window
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeKey }) {
                MainWindowRouter.shared.register(window: window)
            }
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppDelegate.isQuitting = true
        let proceed = PDFEditorService.shared.confirmProceedWithUnsavedChanges(before: "quitting")
        if !proceed {
            AppDelegate.isQuitting = false
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar and Dock even when main dashboard window is closed!
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        MainWindowRouter.shared.showMainWindow()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let hasVisibleMainWindow = NSApp.windows.contains { window in
            !(window is NSPanel) && window.canBecomeKey && window.isVisible
        }
        if !hasVisibleMainWindow {
            MainWindowRouter.shared.showMainWindow()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        AppDelegate.isQuitting = true
        // 1. Remove status bar items
        MenuBarCoordinator.shared.teardown()
        // 2. Stop clipboard monitoring and unregister hotkeys
        ClipboardBackgroundController.shared.stop()
        // 3. Stop system monitoring timers
        SystemMonitor.shared.stopMonitoring()
        // 4. Release power assertions and timers
        KeepAwakeService.shared.stop()
        ClamshellManager.shared.stop()
        // 5. Invalidate pomodoro timer
        FocusTimerService.shared.pause()
        // 6. Dismiss any full-screen cleaning overlays
        ScreenCleanOverlayService.shared.dismissActiveOverlay()
        // 7. Diagnostics log
        AppLog.lifecycle.info("Borno Pulse application cleanly terminated")
    }
}
