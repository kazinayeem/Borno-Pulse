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
public final class MainWindowRouter {
    public static let shared = MainWindowRouter()

    static let windowID = "main-window"

    private var openWindowAction: OpenWindowAction?
    private var pendingSection: NavigationSection?

    private init() {}

    /// Called by the main window's root view so the window can be recreated after it closes.
    func register(openWindow: OpenWindowAction) {
        openWindowAction = openWindow
    }

    var mainWindow: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue.hasPrefix(Self.windowID) == true }
    }

    public func showMainWindow(section: NavigationSection? = nil) {
        NSApp.activate()
        if let window = mainWindow, window.isVisible || window.isMiniaturized {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            if let section {
                NotificationCenter.default.post(name: .navigateToSection, object: section)
            }
            return
        }

        pendingSection = section
        if let openWindowAction {
            openWindowAction(id: Self.windowID)
        } else if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        }
    }

    public func openSettings(tab: SettingsSectionTab) {
        SettingsNavigation.shared.requestedTab = tab
        showMainWindow(section: .settings)
    }

    /// Section requested before the window existed; read once by the new window.
    func consumePendingSection() -> NavigationSection? {
        defer { pendingSection = nil }
        return pendingSection
    }
}
