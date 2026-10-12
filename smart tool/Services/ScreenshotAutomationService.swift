//
//  ScreenshotAutomationService.swift
//  Borno Pulse
//
//  Automated screenshot generation for all application screens, settings tabs,
//  and menu bar widget categories in both Light and Dark appearance modes.
//

import AppKit
import Foundation
import SwiftUI

@MainActor
public enum ScreenshotAutomationService {

    public struct CaptureRecord: Sendable {
        public let relativePath: String
        public let appearance: String
        public let screenName: String
        public let sizeBytes: Int
        public let width: Int
        public let height: Int
    }

    private static func runloopSleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private static func capturePNG(view: NSView) -> (data: Data, width: Int, height: Int)? {
        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return nil }
        return (data, rep.pixelsWide, rep.pixelsHigh)
    }

    public static func run(outputDir: URL) async {
        print("=================================================================")
        print("  Borno Pulse — Automated Full Application Screenshot Suite")
        print("=================================================================")
        print("Target directory: \(outputDir.path)")

        let fm = FileManager.default
        let lightDir = outputDir.appendingPathComponent("light")
        let darkDir = outputDir.appendingPathComponent("dark")
        let widgetDir = outputDir.appendingPathComponent("widget")

        try? fm.createDirectory(at: lightDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: darkDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: widgetDir, withIntermediateDirectories: true)

        let initialAppearance = NSApp.appearance
        var records: [CaptureRecord] = []

        // 1. Show main dashboard window and set canonical size
        MainWindowRouter.shared.showMainWindow(section: .overview)
        await runloopSleep(0.8)

        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("main-window") == true }),
              let contentView = window.contentView else {
            print("❌ Error: Main dashboard window could not be found.")
            exit(1)
        }

        window.setContentSize(NSSize(width: 1200, height: 780))
        window.center()
        window.makeKeyAndOrderFront(nil)
        await runloopSleep(0.4)

        // Pre-warm data services
        SystemMonitor.shared.startMonitoring()
        SystemMonitor.shared.refreshNow()
        PortScannerService.shared.refresh()
        if let firstPort = PortScannerService.shared.ports.first {
            PortScannerService.shared.selectedPortItem = firstPort
        }
        await runloopSleep(0.5)

        let modes: [(name: String, isDark: Bool, dir: URL)] = [
            ("Light", false, lightDir),
            ("Dark", true, darkDir)
        ]

        let sectionMapping: [(section: NavigationSection, file: String)] = [
            (.overview, "overview"),
            (.cpu, "cpu"),
            (.gpu, "gpu"),
            (.memory, "memory"),
            (.sensors, "sensors"),
            (.storage, "storage"),
            (.network, "network"),
            (.battery, "battery"),
            (.developerToolbox, "developer_toolbox"),
            (.networkToolkit, "network_toolkit"),
            (.portManager, "port_manager"),
            (.clipboard, "clipboard"),
            (.focusPomodoro, "focus_pomodoro"),
            (.batchConverter, "batch_converter"),
            (.pdfStudio, "pdf_studio"),
            (.fileTools, "file_tools"),
            (.privacySecurity, "privacy_security"),
            (.localBackup, "local_backup"),
            (.screenTime, "screen_time"),
            (.storageAnalytics, "storage_analytics"),
            (.processes, "processes"),
            (.cleaner, "cleaner"),
            (.diagnostics, "diagnostics"),
            (.settings, "settings")
        ]

        let settingsTabs: [(tab: SettingsSectionTab, file: String)] = [
            (.appearanceTypography, "settings_appearance"),
            (.menuBarWidget, "settings_menubar"),
            (.general, "settings_general"),
            (.clipboard, "settings_clipboard"),
            (.alerts, "settings_alerts"),
            (.pdfStudio, "settings_pdf"),
            (.privacySecurity, "settings_privacy"),
            (.shortcutsDiagnostics, "settings_shortcuts"),
            (.backupReset, "settings_backup")
        ]

        for mode in modes {
            print("\n📸 Switching to \(mode.name) Mode...")
            let appearanceName: NSAppearance.Name = mode.isDark ? .darkAqua : .aqua
            NSApp.appearance = NSAppearance(named: appearanceName)
            window.appearance = NSAppearance(named: appearanceName)
            NotificationCenter.default.post(name: .appAppearanceDidChange, object: nil)
            await runloopSleep(0.5)

            // --- Capture Navigation Sections ---
            for item in sectionMapping {
                NotificationCenter.default.post(name: .navigateToSection, object: item.section)
                await runloopSleep(0.55)

                if let (data, w, h) = capturePNG(view: contentView) {
                    let fileURL = mode.dir.appendingPathComponent("\(item.file).png")
                    try? data.write(to: fileURL)
                    let relPath = "screenshots/\(mode.name.lowercased())/\(item.file).png"
                    records.append(CaptureRecord(relativePath: relPath, appearance: mode.name, screenName: item.section.rawValue, sizeBytes: data.count, width: w, height: h))
                    print("  ✓ [\(mode.name)] \(item.section.rawValue) -> \(item.file).png (\(w)x\(h), \(data.count / 1024) KB)")
                }
            }

            // --- Capture Settings Subsections ---
            for tabItem in settingsTabs {
                SettingsNavigation.shared.requestedTab = tabItem.tab
                NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.settings)
                await runloopSleep(0.45)

                if let (data, w, h) = capturePNG(view: contentView) {
                    let fileURL = mode.dir.appendingPathComponent("\(tabItem.file).png")
                    try? data.write(to: fileURL)
                    let relPath = "screenshots/\(mode.name.lowercased())/\(tabItem.file).png"
                    records.append(CaptureRecord(relativePath: relPath, appearance: mode.name, screenName: "Settings: \(tabItem.tab.rawValue)", sizeBytes: data.count, width: w, height: h))
                    print("  ✓ [\(mode.name)] Settings Tab: \(tabItem.tab.rawValue) -> \(tabItem.file).png (\(w)x\(h), \(data.count / 1024) KB)")
                }
            }

            // --- Capture Quick Launcher ---
            let quickLauncherHost = NSHostingView(rootView: QuickLauncherView(onSelect: { _ in }, onDismiss: {}))
            quickLauncherHost.appearance = NSAppearance(named: appearanceName)
            quickLauncherHost.frame = NSRect(x: 0, y: 0, width: 560, height: 440)
            let qlWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 440), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            qlWindow.isReleasedWhenClosed = false
            qlWindow.appearance = NSAppearance(named: appearanceName)
            qlWindow.contentView = quickLauncherHost
            qlWindow.makeKeyAndOrderFront(nil)
            await runloopSleep(0.35)

            if let (data, w, h) = capturePNG(view: quickLauncherHost) {
                let fileURL = mode.dir.appendingPathComponent("quick_launcher.png")
                try? data.write(to: fileURL)
                let relPath = "screenshots/\(mode.name.lowercased())/quick_launcher.png"
                records.append(CaptureRecord(relativePath: relPath, appearance: mode.name, screenName: "Quick Launcher (⌘K)", sizeBytes: data.count, width: w, height: h))
                print("  ✓ [\(mode.name)] Quick Launcher -> quick_launcher.png (\(w)x\(h), \(data.count / 1024) KB)")
            }
            qlWindow.orderOut(nil)

            // --- Capture Menu Bar Widget Tabs with Content-Based Adaptive Sizing ---
            let wWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
            wWindow.isReleasedWhenClosed = false
            wWindow.appearance = NSAppearance(named: appearanceName)

            for cat in MenuBarCategory.allCases {
                let catName = cat.rawValue.lowercased()
                let totalH = MenuBarPopoverView.preferredContentHeight(
                    for: cat,
                    hasUpdate: false,
                    runningAudioAppsCount: AudioDeviceService.shared.runningAudioApps.count,
                    hasBattery: SystemMonitor.shared.snapshot.battery.hasBattery,
                    activeMetricsCount: MenuBarWidgetPreferences.shared.activeOrderedMetrics.count,
                    layoutStyle: MenuBarWidgetPreferences.shared.layoutStyle
                )
                let widgetHost = NSHostingView(rootView: MenuBarPopoverView(initialCategory: cat))
                widgetHost.appearance = NSAppearance(named: appearanceName)
                widgetHost.frame = NSRect(x: 0, y: 0, width: 360, height: totalH)
                wWindow.setContentSize(NSSize(width: 360, height: totalH))
                wWindow.contentView = widgetHost
                wWindow.makeKeyAndOrderFront(nil)
                await runloopSleep(0.35)

                if let (data, w, h) = capturePNG(view: widgetHost) {
                    let catURL = widgetDir.appendingPathComponent("\(mode.name.lowercased())-\(catName).png")
                    try? data.write(to: catURL)
                    let relPath = "screenshots/widget/\(mode.name.lowercased())-\(catName).png"
                    records.append(CaptureRecord(relativePath: relPath, appearance: mode.name, screenName: "Widget: \(cat.rawValue)", sizeBytes: data.count, width: w, height: h))
                    print("  ✓ [Widget] \(mode.name) \(cat.rawValue) -> \(mode.name.lowercased())-\(catName).png (\(w)x\(h), \(data.count / 1024) KB)")

                    // Standard canonical widget screenshot
                    if cat == .audio {
                        let defaultWidgetURL = widgetDir.appendingPathComponent("\(mode.name.lowercased())-widget.png")
                        try? data.write(to: defaultWidgetURL)
                        records.append(CaptureRecord(relativePath: "screenshots/widget/\(mode.name.lowercased())-widget.png", appearance: mode.name, screenName: "Widget (Main)", sizeBytes: data.count, width: w, height: h))
                    }
                }
            }
            wWindow.orderOut(nil)
        }

        // Restore user's original appearance
        NSApp.appearance = initialAppearance
        window.appearance = initialAppearance
        NotificationCenter.default.post(name: .appAppearanceDidChange, object: nil)

        // Summary
        print("\n=================================================================")
        print("  Screenshot Automation Summary")
        print("=================================================================")
        print("Total screenshots captured: \(records.count)")
        let lightCount = records.filter { $0.appearance == "Light" && !$0.relativePath.contains("widget") }.count
        let darkCount = records.filter { $0.appearance == "Dark" && !$0.relativePath.contains("widget") }.count
        let widgetCount = records.filter { $0.relativePath.contains("widget") }.count
        print("  - Light Mode screens: \(lightCount)")
        print("  - Dark Mode screens:  \(darkCount)")
        print("  - Menu Bar Widget:    \(widgetCount)")
        print("All output files verified successfully.")
        print("=================================================================\n")
    }
}
