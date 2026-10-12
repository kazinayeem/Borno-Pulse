//
//  AppearanceController.swift
//  Borno Pulse
//
//  Applies the user's Light / Dark / System preference to the whole application.
//  Setting `NSApp.appearance` (rather than `.preferredColorScheme` on individual
//  SwiftUI roots) keeps AppKit chrome, sidebars, sheets, alerts, open/save panels,
//  popovers and SwiftUI content on the same appearance, and lets `.system` revert
//  cleanly to the macOS setting.
//

import AppKit
import Combine
import SwiftUI

public extension AppAppearanceMode {
    /// `nil` follows the macOS appearance.
    var nsAppearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }
}

@MainActor
public final class AppearanceController {
    public static let shared = AppearanceController()

    private var cancellable: AnyCancellable?
    private var appliedMode: AppAppearanceMode?

    private init() {}

    /// Applies the stored preference and keeps it applied as the setting changes.
    public func start() {
        apply(AppSettings.shared.appearanceMode)
        cancellable = AppSettings.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.apply(AppSettings.shared.appearanceMode)
            }
    }

    public func apply(_ mode: AppAppearanceMode) {
        guard mode != appliedMode else { return }
        appliedMode = mode
        NSApp.appearance = mode.nsAppearance
        NotificationCenter.default.post(name: .appAppearanceDidChange, object: nil)
    }

    /// Appearance for windows that do not inherit from `NSApp` (e.g. popovers anchored to the
    /// menu bar, which otherwise follow the menu bar's own appearance).
    public var resolvedAppearance: NSAppearance? {
        let match = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua
        return NSAppearance(named: match)
    }

    public var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    public func toggleAppearance() {
        let newMode: AppAppearanceMode = isDarkMode ? .light : .dark
        AppSettings.shared.appearanceMode = newMode
        apply(newMode)
    }
}

public extension Notification.Name {
    static let appAppearanceDidChange = Notification.Name("BornoAppAppearanceDidChange")
}
