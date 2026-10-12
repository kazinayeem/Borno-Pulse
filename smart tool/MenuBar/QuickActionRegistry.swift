//
//  QuickActionRegistry.swift
//  Borno Pulse
//
//  Comprehensive Quick Action registry, metadata definitions, permissions audit,
//  and execution coordinator for macOS menu bar utility actions.
//

import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - Action Category
public enum QuickActionCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case display = "Display & Desktop"
    case system = "System & Security"
    case cleanup = "Cleanup & Maintenance"
    case tools = "Tools & Navigation"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .display: return "display"
        case .system: return "lock.shield"
        case .cleanup: return "sparkles"
        case .tools: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Action Stable Identifiers
public enum QuickActionId: String, CaseIterable, Identifiable, Codable, Sendable {
    // Display & Desktop
    case toggleDarkMode = "toggle_dark_mode"
    case keepAwake = "keep_awake"
    case startScreenSaver = "start_screen_saver"
    case cleanScreen = "clean_screen"
    case hideAllWindows = "hide_all_windows"
    case toggleDockAutohide = "toggle_dock_autohide"
    case hideDesktopIcons = "hide_desktop_icons"
    case hideNotch = "hide_notch"

    // System & Security
    case lockScreen = "lock_screen"
    case keyboardCleaningMode = "keyboard_cleaning_mode"
    case openActivityMonitor = "open_activity_monitor"
    case openSystemSettings = "open_system_settings"

    // Cleanup & Maintenance
    case scanCache = "scan_cache"
    case emptyTrash = "empty_trash"
    case refreshMetrics = "refresh_metrics"

    // Tools & Navigation
    case toggleFocus = "toggle_focus"
    case openDownloads = "open_downloads"
    case openPortManager = "open_port_manager"
    case openNetworkToolkit = "open_network_toolkit"
    case openTerminal = "open_terminal"
    case clamshellMode = "clamshell_mode"

    public var id: String { rawValue }
}

// MARK: - Action Result Feedback
public struct QuickActionResult: Sendable {
    public let success: Bool
    public let message: String
    public let isWarning: Bool

    public init(success: Bool, message: String, isWarning: Bool = false) {
        self.success = success
        self.message = message
        self.isWarning = isWarning
    }
}

// MARK: - Action Definition Item
public struct QuickActionItem: Identifiable, Sendable {
    public let id: QuickActionId
    public let title: String
    public let icon: String
    public let category: QuickActionCategory
    public let description: String
    public let isSupported: Bool
    public let unsupportedReason: String?
    public let requiresConfirmation: Bool
    public let confirmationTitle: String?
    public let confirmationMessage: String?
    public let requiredPermission: String?

    public init(
        id: QuickActionId,
        title: String,
        icon: String,
        category: QuickActionCategory,
        description: String,
        isSupported: Bool = true,
        unsupportedReason: String? = nil,
        requiresConfirmation: Bool = false,
        confirmationTitle: String? = nil,
        confirmationMessage: String? = nil,
        requiredPermission: String? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.category = category
        self.description = description
        self.isSupported = isSupported
        self.unsupportedReason = unsupportedReason
        self.requiresConfirmation = requiresConfirmation
        self.confirmationTitle = confirmationTitle
        self.confirmationMessage = confirmationMessage
        self.requiredPermission = requiredPermission
    }
}

// MARK: - Quick Action Registry
@MainActor
public final class QuickActionRegistry: ObservableObject {
    public static let shared = QuickActionRegistry()

    private let kEnabledActionsKey = "borno_quick_actions_enabled_ids"
    private let kActionOrderKey = "borno_quick_actions_order_ids"

    @Published public var enabledActionIds: [QuickActionId] {
        didSet { savePreferences() }
    }

    @Published public var actionOrder: [QuickActionId] {
        didSet { savePreferences() }
    }

    public static let defaultActions: [QuickActionId] = [
        .keepAwake,
        .toggleDarkMode,
        .lockScreen,
        .scanCache,
        .cleanScreen,
        .keyboardCleaningMode,
        .hideAllWindows,
        .emptyTrash,
        .startScreenSaver,
        .toggleDockAutohide,
        .openActivityMonitor,
        .openSystemSettings
    ]

    private init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.stringArray(forKey: kEnabledActionsKey) {
            let loaded = raw.compactMap { QuickActionId(rawValue: $0) }
            self.enabledActionIds = loaded.isEmpty ? Self.defaultActions : loaded
        } else {
            self.enabledActionIds = Self.defaultActions
        }

        if let rawOrder = defaults.stringArray(forKey: kActionOrderKey) {
            var loaded = rawOrder.compactMap { QuickActionId(rawValue: $0) }
            for a in QuickActionId.allCases where !loaded.contains(a) {
                loaded.append(a)
            }
            self.actionOrder = loaded
        } else {
            self.actionOrder = QuickActionId.allCases
        }
    }

    public func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(enabledActionIds.map { $0.rawValue }, forKey: kEnabledActionsKey)
        defaults.set(actionOrder.map { $0.rawValue }, forKey: kActionOrderKey)
    }

    public func resetToDefaults() {
        self.enabledActionIds = Self.defaultActions
        self.actionOrder = QuickActionId.allCases
        savePreferences()
    }

    public var activeOrderedActions: [QuickActionItem] {
        actionOrder
            .filter { enabledActionIds.contains($0) }
            .compactMap { action(for: $0) }
    }

    public func action(for id: QuickActionId) -> QuickActionItem? {
        definitions[id]
    }

    public func isActionActive(_ id: QuickActionId) -> Bool {
        switch id {
        case .keepAwake:
            return KeepAwakeService.shared.isActive
        case .toggleDarkMode:
            return AppearanceController.shared.isDarkMode
        case .clamshellMode:
            return ClamshellManager.shared.isActive
        default:
            return false
        }
    }

    // MARK: - Comprehensive Catalog & Audit
    public let definitions: [QuickActionId: QuickActionItem] = [
        .keepAwake: QuickActionItem(
            id: .keepAwake,
            title: "Keep Awake",
            icon: "cup.and.saucer.fill",
            category: .display,
            description: "Temporarily prevents your display and system from going to sleep using native IOKit power assertions."
        ),
        .toggleDarkMode: QuickActionItem(
            id: .toggleDarkMode,
            title: "Dark Mode",
            icon: "moon.fill",
            category: .display,
            description: "Toggles macOS appearance between Light and Dark mode using system events automation."
        ),
        .lockScreen: QuickActionItem(
            id: .lockScreen,
            title: "Lock Screen",
            icon: "lock.fill",
            category: .system,
            description: "Locks the current macOS user session immediately."
        ),
        .scanCache: QuickActionItem(
            id: .scanCache,
            title: "Clean Cache",
            icon: "sparkles",
            category: .cleanup,
            description: "Scans and cleans safe user application cache to reclaim disk space."
        ),
        .cleanScreen: QuickActionItem(
            id: .cleanScreen,
            title: "Clean Screen",
            icon: "sparkles.tv",
            category: .display,
            description: "Displays a full-screen, dim overlay so you can safely wipe dust off your screen without accidental clicks."
        ),
        .keyboardCleaningMode: QuickActionItem(
            id: .keyboardCleaningMode,
            title: "Clean Keyboard",
            icon: "keyboard.fill",
            category: .system,
            description: "Locks keyboard input so you can safely wipe keys. Exit anytime by clicking the on-screen exit button or holding Escape."
        ),
        .hideAllWindows: QuickActionItem(
            id: .hideAllWindows,
            title: "Clean Desktop",
            icon: "macwindow.on.rectangle",
            category: .display,
            description: "Hides other running application windows to give you an uncluttered desktop view."
        ),
        .emptyTrash: QuickActionItem(
            id: .emptyTrash,
            title: "Empty Trash",
            icon: "trash.fill",
            category: .cleanup,
            description: "Permanently erases files in the macOS Trash. Requires explicit user confirmation.",
            requiresConfirmation: true,
            confirmationTitle: "Empty macOS Trash?",
            confirmationMessage: "Are you sure you want to permanently erase all items in the Trash? You can also choose to open Trash to inspect files first."
        ),
        .startScreenSaver: QuickActionItem(
            id: .startScreenSaver,
            title: "Screen Saver",
            icon: "sparkles.rectangle.stack.fill",
            category: .display,
            description: "Starts the native macOS screen saver immediately."
        ),
        .toggleDockAutohide: QuickActionItem(
            id: .toggleDockAutohide,
            title: "Toggle Dock",
            icon: "dock.rectangle",
            category: .display,
            description: "Toggles the automatic hiding and showing of the macOS Dock.",
            requiredPermission: "Automation (System Events)"
        ),
        .openActivityMonitor: QuickActionItem(
            id: .openActivityMonitor,
            title: "Activity Monitor",
            icon: "chart.bar.xaxis",
            category: .tools,
            description: "Opens macOS Activity Monitor to inspect system processes."
        ),
        .openSystemSettings: QuickActionItem(
            id: .openSystemSettings,
            title: "System Settings",
            icon: "gearshape.2.fill",
            category: .tools,
            description: "Opens macOS System Settings."
        ),
        .toggleFocus: QuickActionItem(
            id: .toggleFocus,
            title: "Focus Mode",
            icon: "timer",
            category: .tools,
            description: "Opens Borno Pulse Focus & Pomodoro session."
        ),
        .refreshMetrics: QuickActionItem(
            id: .refreshMetrics,
            title: "Refresh",
            icon: "arrow.clockwise",
            category: .tools,
            description: "Immediately updates all live system hardware and network metrics."
        ),
        .openDownloads: QuickActionItem(
            id: .openDownloads,
            title: "Downloads",
            icon: "arrow.down.circle.fill",
            category: .tools,
            description: "Opens your macOS Downloads folder in Finder."
        ),
        .openPortManager: QuickActionItem(
            id: .openPortManager,
            title: "Port Manager",
            icon: "network.badge.shield.half.filled",
            category: .tools,
            description: "Opens Borno Pulse Port Manager to inspect listening network ports."
        ),
        .openNetworkToolkit: QuickActionItem(
            id: .openNetworkToolkit,
            title: "Network Tools",
            icon: "network",
            category: .tools,
            description: "Opens Borno Pulse Network Toolkit for ping, traceroute, and DNS lookups."
        ),
        .openTerminal: QuickActionItem(
            id: .openTerminal,
            title: "Terminal",
            icon: "terminal.fill",
            category: .tools,
            description: "Launches macOS Terminal."
        ),
        .clamshellMode: QuickActionItem(
            id: .clamshellMode,
            title: "Clamshell",
            icon: "laptopcomputer.and.arrow.down",
            category: .tools,
            description: "Keep workloads running when lid is closed: audit hardware, configure duration, and verify background workloads."
        ),
        // Documented & Honestly Handled Restrictions
        .hideDesktopIcons: QuickActionItem(
            id: .hideDesktopIcons,
            title: "Desktop Icons",
            icon: "menubar.dock.rectangle",
            category: .display,
            description: "Desktop icons are managed in System Settings > Desktop & Dock on modern macOS without restarting Finder.",
            isSupported: false,
            unsupportedReason: "Modern macOS manages desktop icon visibility via System Settings > Desktop & Dock. Forcing Finder restart hacks is omitted for stability."
        ),
        .hideNotch: QuickActionItem(
            id: .hideNotch,
            title: "Hardware Notch",
            icon: "camera.badge.ellipsis",
            category: .display,
            description: "The physical MacBook camera cutout is hardware and cannot be removed by software.",
            isSupported: false,
            unsupportedReason: "The MacBook display notch is a physical hardware cutout and cannot be modified via software."
        )
    ]

    // MARK: - Action Execution Engine
    public func execute(
        _ id: QuickActionId,
        onOpenDashboard: (() -> Void)? = nil,
        onQuickCleanup: (() -> Void)? = nil
    ) async -> QuickActionResult {
        switch id {
        case .keepAwake:
            KeepAwakeService.shared.toggle()
            if KeepAwakeService.shared.isActive {
                return QuickActionResult(success: true, message: "Display sleep prevented")
            } else {
                return QuickActionResult(success: true, message: "Sleep prevention stopped")
            }

        case .toggleDarkMode:
            // Toggle Borno Pulse appearance controller
            AppearanceController.shared.toggleAppearance()
            // Also attempt system-wide toggle via safe AppleScript if permitted
            let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
            let isDark = AppearanceController.shared.isDarkMode
            return QuickActionResult(success: true, message: isDark ? "Dark appearance enabled" : "Light appearance enabled")

        case .lockScreen:
            lockMacSession()
            return QuickActionResult(success: true, message: "Screen locked")

        case .startScreenSaver:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
            return QuickActionResult(success: true, message: "Screen saver started")

        case .cleanScreen:
            ScreenCleanOverlayService.shared.presentScreenCleaningOverlay()
            return QuickActionResult(success: true, message: "Screen cleaning active (Press Esc to exit)")

        case .keyboardCleaningMode:
            ScreenCleanOverlayService.shared.presentKeyboardCleaningOverlay()
            return QuickActionResult(success: true, message: "Keyboard cleaning active (Hold Esc or click Exit)")

        case .hideAllWindows:
            NSWorkspace.shared.hideOtherApplications()
            return QuickActionResult(success: true, message: "Clean desktop revealed")

        case .toggleDockAutohide:
            let script = "tell application \"System Events\" to set autohide of dock preferences to not (autohide of dock preferences)"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if error == nil {
                    return QuickActionResult(success: true, message: "Dock autohide toggled")
                }
            }
            // Fallback instruction if permission needed
            return QuickActionResult(
                success: false,
                message: "Requires Automation permission for System Events",
                isWarning: true
            )

        case .emptyTrash:
            // Confirmed empty trash execution
            let script = "tell application \"Finder\" to empty trash"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
            return QuickActionResult(success: true, message: "Trash emptied")

        case .scanCache:
            onQuickCleanup?()
            return QuickActionResult(success: true, message: "Cache cleanup initiated")

        case .refreshMetrics:
            SystemMonitor.shared.refreshNow()
            return QuickActionResult(success: true, message: "System metrics updated")

        case .toggleFocus:
            onOpenDashboard?()
            MainWindowRouter.shared.showMainWindow(section: .focusPomodoro)
            return QuickActionResult(success: true, message: "Focus timer opened")

        case .openActivityMonitor:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
            return QuickActionResult(success: true, message: "Activity Monitor opened")

        case .openSystemSettings:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
            return QuickActionResult(success: true, message: "System Settings opened")

        case .openDownloads:
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            if let url = downloads {
                NSWorkspace.shared.open(url)
                return QuickActionResult(success: true, message: "Downloads folder opened")
            }
            return QuickActionResult(success: false, message: "Could not find Downloads folder", isWarning: true)

        case .openPortManager:
            onOpenDashboard?()
            MainWindowRouter.shared.showMainWindow(section: .portManager)
            return QuickActionResult(success: true, message: "Port Manager opened")

        case .openNetworkToolkit:
            onOpenDashboard?()
            MainWindowRouter.shared.showMainWindow(section: .networkToolkit)
            return QuickActionResult(success: true, message: "Network Toolkit opened")

        case .openTerminal:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
            return QuickActionResult(success: true, message: "Terminal opened")

        case .clamshellMode:
            if ClamshellManager.shared.isActive {
                ClamshellManager.shared.stop()
                return QuickActionResult(success: true, message: "Lid-closed operation stopped")
            } else {
                onOpenDashboard?()
                MainWindowRouter.shared.showMainWindow(section: .clamshellMode)
                return QuickActionResult(success: true, message: "Opened Clamshell Mode settings")
            }

        case .hideDesktopIcons:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
            return QuickActionResult(
                success: false,
                message: "Managed in System Settings > Desktop & Dock",
                isWarning: true
            )

        case .hideNotch:
            return QuickActionResult(
                success: false,
                message: "Camera notch is a physical hardware cutout",
                isWarning: true
            )
        }
    }

    private func lockMacSession() {
        // Attempt native login session lock
        let lib = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
        if let sym = dlsym(lib, "SACLockScreenImmediate") {
            typealias LockFunc = @convention(c) () -> Void
            let lock = unsafeBitCast(sym, to: LockFunc.self)
            lock()
            return
        }

        // Fallback: Launch ScreenSaverEngine which locks if password on wake is set
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
    }
}
