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

        let settings    = AppSettings.shared
        let metrics     = settings.menuBarStatusMetrics
        let maxVisible  = settings.menuBarMaxVisible
        let customSym   = settings.menuBarIconSymbol.symbolName

        // --- Multi-metric rendering ---
        // Collect up to maxVisible non-nil text tokens from the ordered metric list.
        var tokens: [String] = []
        var overrideSymbol: String? = nil

        let visible = Array(metrics.prefix(max(1, maxVisible)))

        for metric in visible {
            // Icon-only and battery-status produce only an image; record symbol override.
            if let sym = metric.menuBarSymbol(from: snapshot) {
                overrideSymbol = sym
                // Don't add a text token for icon-only metrics.
                continue
            }
            if let text = metric.menuBarText(from: snapshot) {
                tokens.append(text)
            }
        }

        // Build the composite title string.
        // Use a thin vertical bar (U+2006 narrow no-break space + | + space) as separator.
        let separator = "  |  "
        let compositeText = tokens.joined(separator: separator)

        // Update button title with a leading space for visual padding.
        button.title = compositeText.isEmpty ? "" : " " + compositeText

        // Update icon: use overrideSymbol when set (e.g. for battery-status), otherwise the user's chosen symbol.
        let symbolName = overrideSymbol ?? customSym
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Borno Pulse")
        img?.isTemplate = true
        button.image = img
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
