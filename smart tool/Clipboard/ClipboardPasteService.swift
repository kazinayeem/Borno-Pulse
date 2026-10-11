//
//  ClipboardPasteService.swift
//  Borno Pulse
//
//  macOS has no API for inserting content into another app's focused field.
//  Automatic paste therefore restores the item to the pasteboard, re-activates the
//  app that was frontmost, and posts a synthetic ⌘V. Posting keyboard events requires
//  Accessibility permission, is skipped while Secure Event Input is active (password
//  fields), and can still be ignored by the receiving app — so a sent paste is never
//  reported as a confirmed paste.
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

@MainActor
public final class ClipboardPasteService {
    public static let shared = ClipboardPasteService()

    public enum FallbackReason: Equatable, Sendable {
        case autoPasteDisabled
        case accessibilityNotGranted
        case secureInputActive
        case noTargetApplication
        case eventUnavailable

        public var message: String {
            switch self {
            case .autoPasteDisabled:
                return "Press ⌘V to paste."
            case .accessibilityNotGranted:
                return "Press ⌘V to paste. Automatic paste needs Accessibility access (Settings › Clipboard)."
            case .secureInputActive:
                return "A secure text field is active, so no paste keystroke was sent. Press ⌘V if appropriate."
            case .noTargetApplication:
                return "No previous app to paste into. Press ⌘V where you want it."
            case .eventUnavailable:
                return "Automatic paste is unavailable right now. Press ⌘V to paste."
            }
        }
    }

    public enum Outcome: Equatable, Sendable {
        /// ⌘V was posted to the target app. Delivery cannot be confirmed.
        case pasteKeystrokeSent(appName: String?)
        case copiedOnly(FallbackReason)
        case restoreFailed(String)
    }

    private init() {}

    public var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt for Accessibility access. Only called from an explicit user action.
    public func requestAccessibilityAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public var isSecureInputActive: Bool { IsSecureEventInputEnabled() }

    /// Pure decision used by `paste` and covered by tests.
    nonisolated public static func fallbackReason(
        autoPasteEnabled: Bool,
        accessibilityTrusted: Bool,
        secureInputActive: Bool,
        hasTarget: Bool
    ) -> FallbackReason? {
        if !autoPasteEnabled { return .autoPasteDisabled }
        if !hasTarget { return .noTargetApplication }
        if !accessibilityTrusted { return .accessibilityNotGranted }
        if secureInputActive { return .secureInputActive }
        return nil
    }

    /// Call after the selected item has been restored to the general pasteboard.
    public func pasteRestoredItem(into target: NSRunningApplication?, autoPasteEnabled: Bool) async -> Outcome {
        let validTarget = target.flatMap { $0.isTerminated ? nil : $0 }
        if let reason = Self.fallbackReason(
            autoPasteEnabled: autoPasteEnabled,
            accessibilityTrusted: isAccessibilityTrusted,
            secureInputActive: false,
            hasTarget: validTarget != nil
        ) {
            return .copiedOnly(reason)
        }
        guard let app = validTarget else { return .copiedOnly(.noTargetApplication) }

        if !app.isActive {
            app.activate()
        }
        // Give the target app time to become key again before the keystroke arrives.
        try? await Task.sleep(for: .milliseconds(180))

        // Re-checked after activation: the destination may be a password field.
        if isSecureInputActive {
            return .copiedOnly(.secureInputActive)
        }
        guard postCommandV() else { return .copiedOnly(.eventUnavailable) }
        return .pasteKeystrokeSent(appName: app.localizedName)
    }

    private func postCommandV() -> Bool {
        let keyCode = CGKeyCode(Self.keyCodeForV())
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }

    /// Key code that produces "v" in the current keyboard layout (e.g. differs on Dvorak).
    nonisolated public static func keyCodeForV() -> Int {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawLayout = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return kVK_ANSI_V
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(rawLayout).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { buffer -> Int in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return kVK_ANSI_V }
            for code in 0..<128 {
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars
                )
                if status == noErr, length == 1, chars[0] == UniChar(("v" as Unicode.Scalar).value) {
                    return code
                }
            }
            return kVK_ANSI_V
        }
    }
}

// MARK: - Feedback HUD

/// Small non-activating message panel used after the picker closes. It never takes focus.
@MainActor
public final class ClipboardHUD {
    public static let shared = ClipboardHUD()

    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    public func show(title: String, message: String?, symbol: String = "doc.on.clipboard") {
        let hosting = NSHostingView(rootView: ClipboardHUDView(title: title, message: message, symbol: symbol))
        hosting.frame.size = hosting.fittingSize

        let panel = self.panel ?? makePanel()
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.minY + frame.height * 0.18
            ))
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        self.panel = panel

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.panel?.orderOut(nil) }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        return panel
    }
}

private struct ClipboardHUDView: View {
    let title: String
    let message: String?
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.electricBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let message {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 340, alignment: .leading)
        .background(AppTheme.elevatedCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.borderStrong, lineWidth: 1))
        .padding(8)
        .accessibilityElement(children: .combine)
    }
}
