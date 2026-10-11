//
//  MenuBarCoordinator.swift
//  Borno Pulse
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
            let symbol = AppSettings.shared.menuBarIconSymbol.symbolName
            let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Borno Pulse")
            img?.isTemplate = true
            button.image = img
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }
        self.statusItem = item
        
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = NSHostingController(
            rootView: MenuBarPopoverWrapper(
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
        
        // Subscribe to SystemMonitor snapshots to update status item button text and evaluate threshold alerts
        SystemMonitor.shared.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.updateStatusItemTitle(snapshot: snapshot)
                WidgetAlertService.shared.evaluate(snapshot: snapshot)
            }
            .store(in: &cancellables)
            
        // Subscribe to AppSettings changes to immediately update menu bar icon or format
        AppSettings.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemTitle(snapshot: SystemMonitor.shared.snapshot)
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
        
        let customSymbol = AppSettings.shared.menuBarIconSymbol.symbolName
        
        switch mode {
        case .iconOnly:
            button.title = ""
            let img = NSImage(systemSymbolName: customSymbol, accessibilityDescription: "Borno Pulse")
            img?.isTemplate = true
            button.image = img
        case .cpuPercentage:
            button.title = String(format: " %.0f%%", snapshot.cpu.totalUsage)
            let img = NSImage(systemSymbolName: customSymbol == "gauge.with.dots.needle.bottom.100percent" ? "cpu" : customSymbol, accessibilityDescription: "CPU")
            img?.isTemplate = true
            button.image = img
        case .memoryPercentage:
            button.title = String(format: " %.0f%%", snapshot.memory.usagePercentage)
            let img = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory")
            img?.isTemplate = true
            button.image = img
        case .networkSpeed:
            button.title = " " + Formatters.speed(snapshot.network.downloadSpeedBytesPerSec)
            let img = NSImage(systemSymbolName: "arrow.down", accessibilityDescription: "Download")
            img?.isTemplate = true
            button.image = img
        case .cpuAndMemory:
            button.title = String(format: " CPU: %.0f%% | RAM: %.0f%%", snapshot.cpu.totalUsage, snapshot.memory.usagePercentage)
            let img = NSImage(systemSymbolName: customSymbol, accessibilityDescription: "Metrics")
            img?.isTemplate = true
            button.image = img
        case .cpuAndNetwork:
            button.title = String(format: " %.0f%% | %@", snapshot.cpu.totalUsage, Formatters.speed(snapshot.network.downloadSpeedBytesPerSec))
            let img = NSImage(systemSymbolName: customSymbol, accessibilityDescription: "Metrics")
            img?.isTemplate = true
            button.image = img
        case .batteryPercentage:
            if snapshot.battery.hasBattery {
                button.title = " \(snapshot.battery.percentage)%"
                button.image = NSImage(systemSymbolName: snapshot.battery.isCharging ? "bolt.batteryblock.fill" : "battery.100", accessibilityDescription: "Battery")
            } else {
                button.title = " AC"
                button.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: "AC Power")
            }
        case .batteryTimeRemaining:
            if snapshot.battery.hasBattery {
                button.title = " \(snapshot.battery.formattedTimeRemaining)"
                button.image = NSImage(systemSymbolName: snapshot.battery.isCharging ? "bolt.fill" : "clock", accessibilityDescription: "Time Remaining")
            } else {
                button.title = " AC Power"
                button.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: "AC Power")
            }
        case .batteryWatts:
            if snapshot.battery.hasBattery {
                if let chargeWatts = snapshot.battery.chargingWatts, chargeWatts > 0.05 {
                    button.title = String(format: " +%.1fW", chargeWatts)
                    button.image = NSImage(systemSymbolName: "bolt.batteryblock.fill", accessibilityDescription: "Charging Watts")
                } else if let dischargeWatts = snapshot.battery.dischargingWatts, dischargeWatts > 0.05 {
                    button.title = String(format: " -%.1fW", dischargeWatts)
                    button.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "Discharging Watts")
                } else if snapshot.battery.isPluggedIn {
                    button.title = " 0.0W"
                    button.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: "AC Power")
                } else if let watts = snapshot.battery.wattage {
                    button.title = String(format: " %.1fW", abs(watts))
                    button.image = NSImage(systemSymbolName: snapshot.battery.isCharging ? "bolt.batteryblock.fill" : "battery.100", accessibilityDescription: "Battery Watts")
                } else {
                    button.title = " N/A"
                    button.image = NSImage(systemSymbolName: "bolt.slash", accessibilityDescription: "Wattage Unavailable")
                }
            } else {
                button.title = " AC"
                button.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: "AC Power")
            }
        case .batteryStatus:
            button.title = ""
            if snapshot.battery.hasBattery {
                let symbol = snapshot.battery.isCharging ? "bolt.batteryblock.fill" : (snapshot.battery.isPluggedIn ? "powerplug" : "battery.75")
                button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Battery Status")
            } else {
                button.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: "AC Power")
            }
        case .batteryPercentAndTime:
            if snapshot.battery.hasBattery {
                button.title = " \(snapshot.battery.percentage)% (\(snapshot.battery.formattedTimeRemaining))"
                button.image = NSImage(systemSymbolName: snapshot.battery.isCharging ? "bolt.batteryblock.fill" : "battery.100", accessibilityDescription: "Battery")
            } else {
                button.title = " 100% (AC)"
                button.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: "AC Power")
            }
        }
    }
    
    public func openMainWindow(navigatingTo section: NavigationSection? = nil) {
        popover?.performClose(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Find or create window
        if let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }

        if let target = section {
            NotificationCenter.default.post(name: .navigateToSection, object: target)
        }
    }
}

extension Notification.Name {
    public static let navigateToSection = Notification.Name("BornoNavigateToSection")
}

private struct MenuBarPopoverWrapper: View {
    @ObservedObject var settings = AppSettings.shared
    let onOpenDashboard: () -> Void
    let onOpenSettings: () -> Void
    let onQuickCleanup: () -> Void
    let onQuit: () -> Void

    var body: some View {
        MenuBarPopoverView(
            onOpenDashboard: onOpenDashboard,
            onOpenSettings: onOpenSettings,
            onQuickCleanup: onQuickCleanup,
            onQuit: onQuit
        )
        .preferredColorScheme(settings.appearanceMode.colorScheme)
    }
}
