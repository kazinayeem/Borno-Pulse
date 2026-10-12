//
//  MainWindowRouter.swift
//  Borno Pulse
//
//  Reopens and focuses the main window from background surfaces (menu bar, picker,
//  Dock). Closing the window only hides the UI; services keep running until Quit.
//

import AppKit
import Combine
import SwiftUI

@MainActor
public final class SettingsNavigation: ObservableObject {
    public static let shared = SettingsNavigation()
    /// Consumed by `SettingsView` when it appears or while it is visible.
    @Published public var requestedTab: SettingsSectionTab?

    private init() {}
}

@MainActor
public final class MainWindowDelegate: NSObject, NSWindowDelegate {
    public static let shared = MainWindowDelegate()

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        if AppDelegate.isQuitting {
            return true
        }
        // Red close button behavior: hide/orderOut the window only without terminating Borno Pulse.
        // Borno Pulse remains running in the background and visible in the Dock.
        sender.orderOut(nil)
        return false
    }
}

@MainActor
public final class MainWindowRouter {
    public static let shared = MainWindowRouter()

    public static let windowID = "main-window"

    private var openWindowAction: OpenWindowAction?
    private var pendingSection: NavigationSection?
    private weak var registeredWindow: NSWindow?

    private init() {}

    /// Registers the underlying NSWindow to attach the custom delegate and keep a reference.
    public func register(window: NSWindow) {
        self.registeredWindow = window
        window.identifier = NSUserInterfaceItemIdentifier(Self.windowID)
        window.delegate = MainWindowDelegate.shared
    }

    /// Called by the main window's root view so the window can be recreated after it closes.
    public func register(openWindow: OpenWindowAction) {
        openWindowAction = openWindow
    }

    public var mainWindow: NSWindow? {
        if let window = registeredWindow {
            return window
        }
        return NSApp.windows.first { window in
            (window.identifier?.rawValue.contains(Self.windowID) == true ||
             window.title == "Borno Pulse" ||
             (!window.isKind(of: NSPanel.self) && window.canBecomeKey && window.styleMask.contains(.titled)))
        }
    }

    public func showMainWindow(section: NavigationSection? = nil) {
        // Guarantee normal Dock application policy
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window = mainWindow {
            register(window: window)
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            if let section {
                NotificationCenter.default.post(name: .navigateToSection, object: section)
            }
            return
        }

        pendingSection = section
        if let openWindowAction {
            openWindowAction(id: Self.windowID)
        } else if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeKey }) {
            register(window: window)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    public func openSettings(tab: SettingsSectionTab) {
        SettingsNavigation.shared.requestedTab = tab
        showMainWindow(section: .settings)
    }

    /// Section requested before the window existed; read once by the new window.
    public func consumePendingSection() -> NavigationSection? {
        defer { pendingSection = nil }
        return pendingSection
    }
}
