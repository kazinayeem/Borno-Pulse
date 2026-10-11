//
//  MenuBarCoordinator.swift
//  Naem Smart Tool
//

import AppKit
import Combine
import SwiftUI

@MainActor
public final class MenuBarCoordinator: NSObject {
    public static let shared = MenuBarCoordinator()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
    }
    
    public func setup() {
        guard statusItem == nil else { return }
        
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.100percent", accessibilityDescription: "Naem Smart Tool")
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }
        self.statusItem = item
        
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(
                onOpenDashboard: { [weak self] in
                    self?.openMainWindow()
                },
                onOpenSettings: { [weak self] in
                    self?.openMainWindow()
                },
                onQuickCleanup: { [weak self] in
                    self?.openMainWindow()
                    CacheCleanupService.shared.scanAll()
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                }
            )
        )
        self.popover = pop
        
        // Subscribe to SystemMonitor snapshots to update status item button text
        SystemMonitor.shared.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.updateStatusItemTitle(snapshot: snapshot)
            }
            .store(in: &cancellables)
    }
    
    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button, let pop = popover else { return }
        
        if pop.isShown {
            pop.performClose(nil)
        } else {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func updateStatusItemTitle(snapshot: SystemMetricsSnapshot) {
        guard let button = statusItem?.button else { return }
        let mode = AppSettings.shared.menuBarDisplay
        
        switch mode {
        case .iconOnly:
            button.title = ""
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.100percent", accessibilityDescription: "Naem Smart Tool")
        case .cpuPercentage:
            button.title = String(format: " %.0f%%", snapshot.cpu.totalUsage)
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "CPU")
        case .memoryPercentage:
            button.title = String(format: " %.0f%%", snapshot.memory.usagePercentage)
            button.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory")
        case .networkSpeed:
            button.title = " " + Formatters.speed(snapshot.network.downloadSpeedBytesPerSec)
            button.image = NSImage(systemSymbolName: "arrow.down", accessibilityDescription: "Download")
        case .cpuAndMemory:
            button.title = String(format: " CPU: %.0f%% | RAM: %.0f%%", snapshot.cpu.totalUsage, snapshot.memory.usagePercentage)
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.100percent", accessibilityDescription: "Metrics")
        case .cpuAndNetwork:
            button.title = String(format: " %.0f%% | %@", snapshot.cpu.totalUsage, Formatters.speed(snapshot.network.downloadSpeedBytesPerSec))
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.100percent", accessibilityDescription: "Metrics")
        }
    }
    
    public func openMainWindow() {
        popover?.performClose(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Find or create window
        if let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
