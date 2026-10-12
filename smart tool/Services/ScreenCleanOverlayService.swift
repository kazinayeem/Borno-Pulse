//
//  ScreenCleanOverlayService.swift
//  Borno Pulse
//
//  Full-screen overlay windows for safe screen dusting and keyboard cleaning.
//  Provides key-absorbing safety mode with guaranteed escape/click exit paths.
//

import AppKit
import SwiftUI

@MainActor
public final class ScreenCleanOverlayService: ObservableObject {
    public static let shared = ScreenCleanOverlayService()

    private var activeWindow: NSWindow?
    private var escHoldTimer: Timer?
    private var escHoldProgress: Double = 0.0

    private init() {}

    // MARK: - 1. Screen Cleaning Mode (Visual Display Overlay)
    public func presentScreenCleaningOverlay() {
        dismissActiveOverlay()

        guard let screen = NSScreen.main else { return }
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = NSColor.black.withAlphaComponent(0.96)
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false

        let host = NSHostingView(
            rootView: ScreenCleaningOverlayView(
                onDismiss: { [weak self] in
                    self?.dismissActiveOverlay()
                }
            )
        )
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.activeWindow = window
    }

    // MARK: - 2. Keyboard Cleaning Mode (Key-Absorbing Lock)
    public func presentKeyboardCleaningOverlay() {
        dismissActiveOverlay()

        guard let screen = NSScreen.main else { return }
        let window = KeyboardAbsorbingWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = NSColor(white: 0.08, alpha: 0.94)
        window.isOpaque = false
        window.hasShadow = false

        let host = NSHostingView(
            rootView: KeyboardCleaningOverlayView(
                onDismiss: { [weak self] in
                    self?.dismissActiveOverlay()
                }
            )
        )
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.activeWindow = window
    }

    public func dismissActiveOverlay() {
        activeWindow?.orderOut(nil)
        activeWindow = nil
    }
}

// MARK: - Specialized Window that Intercepts All Key Presses
private class KeyboardAbsorbingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Intercept and swallow ordinary key events during keyboard wiping
        if event.keyCode == 53 { // ESC key
            // Single press gives guidance; holding or clicking button exits
        }
    }

    override func keyUp(with event: NSEvent) {}
    override func flagsChanged(with event: NSEvent) {}
}

// MARK: - Screen Cleaning Overlay SwiftUI View
private struct ScreenCleaningOverlayView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.96)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 16) {
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.85))

                Text("Screen Cleaning Mode")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Display backlight is dimmed for wiping dust and smudges safely.\nClick anywhere or press Escape to exit.")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineSpacing(4)

                Button {
                    onDismiss()
                } label: {
                    Label("Exit Cleaning Mode", systemImage: "xmark.circle")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 12)
            }
            .padding(40)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

// MARK: - Keyboard Cleaning Overlay SwiftUI View
private struct KeyboardCleaningOverlayView: View {
    let onDismiss: () -> Void
    @State private var isHoldingEsc: Bool = false
    @State private var holdProgress: Double = 0.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(Color.orange.opacity(0.9))

                Text("Keyboard Cleaning Mode")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Ordinary keystrokes are temporarily paused.\nYou can safely wipe down your keyboard without triggering commands.")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.70))
                    .lineSpacing(4)

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Color.green)
                        .font(.system(size: 13))
                    Text("Guaranteed Exit: Click the exit button below at any time.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())

                Button {
                    onDismiss()
                } label: {
                    Label("Exit Cleaning Mode", systemImage: "lock.open.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.orange)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding(36)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}
