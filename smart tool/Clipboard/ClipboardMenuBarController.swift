//
//  ClipboardMenuBarController.swift
//  Borno Pulse
//
//  Dedicated clipboard status item. Left click opens a compact popover; right click
//  (or Control-click) opens a menu. It exists independently of the main window.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class ClipboardMenuBarController: NSObject {
    static let shared = ClipboardMenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    /// App that was frontmost when the status item was clicked (status item clicks don't activate us).
    private var lastFrontmostApp: NSRunningApplication?
    private let service = ClipboardManagerService.shared

    private override init() {
        super.init()
    }

    var isInstalled: Bool { statusItem != nil }
    var statusItemForTesting: NSStatusItem? { statusItem }

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "BornoPulseClipboard"
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        updateIcon()

        service.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .appAppearanceDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.popover?.appearance = AppearanceController.shared.resolvedAppearance
            }
            .store(in: &cancellables)
    }

    func uninstall() {
        popover?.performClose(nil)
        popover = nil
        cancellables.removeAll()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let state = service.monitoringState
        let image = NSImage(systemSymbolName: state.symbol, accessibilityDescription: "Clipboard History — \(state.label)")
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = state != .monitoring
        button.toolTip = "Borno Pulse Clipboard — \(statusDescription(state))"
    }

    private func statusDescription(_ state: ClipboardMonitoringState) -> String {
        switch state {
        case .monitoring: return "Recording copies"
        case .off: return "History off"
        case .paused(let until):
            if let until {
                return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
            }
            return "Paused"
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let ownPID = NSRunningApplication.current.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownPID {
            lastFrontmostApp = front
        }
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu(from: sender)
        } else {
            togglePopover(from: sender)
        }
    }

    // MARK: Popover

    private func togglePopover(from button: NSStatusBarButton) {
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }
        let popover = self.popover ?? makePopover()
        self.popover = popover
        popover.appearance = AppearanceController.shared.resolvedAppearance
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func makePopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: ClipboardMenuBarPopoverView(
            service: service,
            hotKeys: GlobalHotKeyService.shared,
            actions: ClipboardMenuActions(
                openHistory: { [weak self] in self?.openHistory() },
                restore: { [weak self] item in self?.restore(item) },
                openManager: { [weak self] in self?.openManager() },
                openSettings: { [weak self] in self?.openSettings() },
                quit: { NSApp.terminate(nil) }
            )
        ))
        return popover
    }

    // MARK: Menu

    private func showMenu(from button: NSStatusBarButton) {
        popover?.performClose(nil)
        let menu = buildMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Clipboard")
        menu.autoenablesItems = false

        let history = NSMenuItem(title: "Open Clipboard History", action: #selector(menuOpenHistory), keyEquivalent: "")
        if let spec = GlobalHotKeyService.shared.registeredShortcut {
            history.title = "Open Clipboard History (\(spec.displayString))"
        }
        history.image = NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: nil)
        history.target = self
        history.isEnabled = service.isEnabled
        menu.addItem(history)

        menu.addItem(.separator())
        let status = NSMenuItem(title: statusDescription(service.monitoringState), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if service.isEnabled {
            if service.isPaused {
                let resume = NSMenuItem(title: "Resume Clipboard History", action: #selector(menuResume), keyEquivalent: "")
                resume.target = self
                resume.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: nil)
                menu.addItem(resume)
            } else {
                for (index, duration) in ClipboardPauseDuration.allCases.enumerated() {
                    let item = NSMenuItem(title: duration.label, action: #selector(menuPause(_:)), keyEquivalent: "")
                    item.target = self
                    item.tag = index
                    if index == 0 { item.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: nil) }
                    menu.addItem(item)
                }
            }
        }

        let recent = Array(service.items.prefix(8))
        if service.isEnabled, !recent.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem(title: "Recent — click to copy", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for item in recent {
                let title = item.maskedPreview.count > 48 ? String(item.maskedPreview.prefix(47)) + "…" : item.maskedPreview
                let menuItem = NSMenuItem(title: title, action: #selector(menuRestore(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = item.id
                menuItem.image = NSImage(systemSymbolName: item.isPinned ? "pin.fill" : item.type.icon, accessibilityDescription: item.type.shortLabel)
                menuItem.toolTip = "\(item.type.shortLabel) · \(item.timestamp.formatted(.relative(presentation: .named)))"
                menu.addItem(menuItem)
            }
        }

        menu.addItem(.separator())
        let manager = NSMenuItem(title: "Open Clipboard Manager", action: #selector(menuOpenManager), keyEquivalent: "")
        manager.target = self
        menu.addItem(manager)
        let settings = NSMenuItem(title: "Clipboard Settings…", action: #selector(menuOpenSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Borno Pulse", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func menuOpenHistory() { openHistory() }
    @objc private func menuResume() { service.resume() }
    @objc private func menuPause(_ sender: NSMenuItem) {
        let durations = ClipboardPauseDuration.allCases
        guard durations.indices.contains(sender.tag) else { return }
        service.pause(for: durations[sender.tag])
    }
    @objc private func menuRestore(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = service.items.first(where: { $0.id == id }) else { return }
        restore(item)
    }
    @objc private func menuOpenManager() { openManager() }
    @objc private func menuOpenSettings() { openSettings() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    // MARK: Actions

    private func openHistory() {
        popover?.performClose(nil)
        ClipboardPickerController.shared.show(target: lastFrontmostApp)
    }

    private func restore(_ item: ClipboardItem) {
        popover?.performClose(nil)
        if service.copyToPasteboard(item) {
            ClipboardHUD.shared.show(title: "Copied to Clipboard", message: ClipboardPasteService.FallbackReason.autoPasteDisabled.message)
        } else {
            ClipboardHUD.shared.show(
                title: "Couldn't Restore Item",
                message: item.type == .file ? "The original file is no longer at its saved location." : "This item's stored content is unavailable.",
                symbol: "exclamationmark.triangle"
            )
        }
    }

    private func openManager() {
        popover?.performClose(nil)
        MainWindowRouter.shared.showMainWindow(section: .clipboard)
    }

    private func openSettings() {
        popover?.performClose(nil)
        MainWindowRouter.shared.openSettings(tab: .clipboard)
    }
}

struct ClipboardMenuActions {
    let openHistory: () -> Void
    let restore: (ClipboardItem) -> Void
    let openManager: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void
}

struct ClipboardMenuBarPopoverView: View {
    @ObservedObject var service: ClipboardManagerService
    @ObservedObject var hotKeys: GlobalHotKeyService
    let actions: ClipboardMenuActions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Clipboard", systemImage: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                MonitoringStatusBadge(state: service.monitoringState)
            }

            Button(action: actions.openHistory) {
                HStack {
                    Label("Open Clipboard History", systemImage: "list.clipboard")
                    Spacer()
                    if let spec = hotKeys.registeredShortcut {
                        Text(spec.displayString)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textOnAccent.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.themedPrimary(fill: AppTheme.accentFill, horizontalPadding: 10, verticalPadding: 6))
            .disabled(!service.isEnabled)

            if service.isEnabled {
                pauseControls
            }

            Divider().overlay(AppTheme.cardBorder)

            Text("Recent")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            let recent = Array(service.items.prefix(5))
            if !service.isEnabled {
                Text("Clipboard history is off.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textTertiary)
            } else if recent.isEmpty {
                Text("Nothing copied yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                VStack(spacing: 2) {
                    ForEach(recent) { item in
                        Button {
                            actions.restore(item)
                        } label: {
                            ClipboardItemRow(item: item, service: service, compact: true)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")
                    }
                }
            }

            Divider().overlay(AppTheme.cardBorder)

            HStack(spacing: 6) {
                Button("Open Manager", action: actions.openManager)
                    .help("Open Clipboard Manager")
                Button("Settings…", action: actions.openSettings)
                Spacer(minLength: 4)
                Button("Quit Borno Pulse", action: actions.quit)
            }
            .controlSize(.small)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 340)
        .background(AppTheme.cardBackground)
    }

    @ViewBuilder
    private var pauseControls: some View {
        if service.isPaused {
            Button {
                service.resume()
            } label: {
                Label("Resume Recording", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
        } else {
            Menu {
                ForEach(ClipboardPauseDuration.allCases) { duration in
                    Button(duration.label) { service.pause(for: duration) }
                }
            } label: {
                Label("Pause Recording", systemImage: "pause.circle")
            }
            .menuStyle(.button)
            .frame(maxWidth: .infinity)
        }
    }
}
