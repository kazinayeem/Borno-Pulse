//
//  ClipboardPickerController.swift
//  Borno Pulse
//
//  Floating clipboard history picker opened by the global shortcut or the menu bar.
//  The panel is non-activating: it receives keyboard input without making Borno Pulse
//  the active app, so the app the user was working in stays frontmost for pasting.
//

import AppKit
import Combine
import SwiftUI

final class ClipboardPickerPanel: NSPanel {
    /// Returns true when the key event was handled by the picker.
    var keyDownHandler: ((NSEvent) -> Bool)?
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 540),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: true
        )
        title = "Clipboard History"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        minSize = NSSize(width: 380, height: 320)
        maxSize = NSSize(width: 760, height: 920)
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyDownHandler?(event) == true {
            return
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class ClipboardPickerModel: ObservableObject {
    @Published var query = "" {
        didSet { if query != oldValue { selectFirst() } }
    }
    @Published var typeFilter: ClipboardContentType? {
        didSet { if typeFilter != oldValue { selectFirst() } }
    }
    @Published var selectedID: UUID?
    @Published var accessibilityTrusted = true

    let service: ClipboardManagerService
    static let resultLimit = 300

    init(service: ClipboardManagerService) {
        self.service = service
    }

    var results: [ClipboardItem] {
        Array(ClipboardManagerService.filter(service.items, query: query, type: typeFilter).prefix(Self.resultLimit))
    }

    var selectedItem: ClipboardItem? {
        let list = results
        return list.first { $0.id == selectedID } ?? list.first
    }

    func reset() {
        query = ""
        typeFilter = nil
        selectFirst()
        accessibilityTrusted = ClipboardPasteService.shared.isAccessibilityTrusted
    }

    func selectFirst() {
        selectedID = results.first?.id
    }

    func moveSelection(by offset: Int) {
        let list = results
        guard !list.isEmpty else { selectedID = nil; return }
        let current = list.firstIndex { $0.id == selectedID } ?? 0
        let next = min(max(current + offset, 0), list.count - 1)
        selectedID = list[next].id
    }

    func item(atShortcutIndex index: Int) -> ClipboardItem? {
        let list = results
        return list.indices.contains(index) ? list[index] : nil
    }
}

@MainActor
final class ClipboardPickerController: NSObject, NSWindowDelegate {
    static let shared = ClipboardPickerController()

    private var panel: ClipboardPickerPanel?
    private(set) var targetApplication: NSRunningApplication?
    let model: ClipboardPickerModel
    private let service: ClipboardManagerService

    private init(service: ClipboardManagerService = .shared) {
        self.service = service
        self.model = ClipboardPickerModel(service: service)
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(target: NSRunningApplication? = nil) {
        if isVisible {
            close()
        } else {
            show(target: target)
        }
    }

    /// - Parameter target: App to paste into. Defaults to the current frontmost app.
    func show(target: NSRunningApplication? = nil) {
        targetApplication = target ?? NSWorkspace.shared.frontmostApplication
        model.reset()

        let panel = self.panel ?? makePanel()
        self.panel = panel
        // A fresh hosting view each time re-runs onAppear, which focuses the search field.
        let hosting = NSHostingView(rootView: ClipboardPickerView(
            model: model,
            service: service,
            onChoose: { [weak self] item in self?.choose(item) },
            onClose: { [weak self] in self?.close() },
            onOpenSettings: { [weak self] in
                self?.close()
                MainWindowRouter.shared.openSettings(tab: .clipboard)
            }
        ))
        // The panel owns its size; otherwise the list's content height resizes the window past the screen.
        hosting.sizingOptions = []
        panel.contentView = hosting
        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
    }

    private func makePanel() -> ClipboardPickerPanel {
        let panel = ClipboardPickerPanel()
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.close() }
        panel.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var size = panel.frame.size
        size.width = min(max(size.width, panel.minSize.width), min(panel.maxSize.width, visible.width))
        size.height = min(max(size.height, panel.minSize.height), min(panel.maxSize.height, visible.height))
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + (visible.height - size.height) * 0.62
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch Int(event.keyCode) {
        case 126: // up
            model.moveSelection(by: -1)
            return true
        case 125: // down
            model.moveSelection(by: 1)
            return true
        case 116: // page up
            model.moveSelection(by: -8)
            return true
        case 121: // page down
            model.moveSelection(by: 8)
            return true
        case 36, 76: // return, keypad enter
            if let item = model.selectedItem { choose(item) }
            return true
        case 53: // escape
            close()
            return true
        default:
            break
        }
        // ⌘1…⌘9 choose the nth visible item.
        if flags == .command, let chars = event.charactersIgnoringModifiers, let digit = Int(chars), (1...9).contains(digit) {
            if let item = model.item(atShortcutIndex: digit - 1) { choose(item) }
            return true
        }
        // ⌘W closes, matching other panels.
        if flags == .command, event.charactersIgnoringModifiers == "w" {
            close()
            return true
        }
        return false
    }

    func choose(_ item: ClipboardItem) {
        let target = targetApplication
        close()

        guard service.copyToPasteboard(item) else {
            let message = item.type == .file
                ? "The original file is no longer at its saved location."
                : "This item's stored content is unavailable."
            ClipboardHUD.shared.show(title: "Couldn't Restore Item", message: message, symbol: "exclamationmark.triangle")
            return
        }

        let ownPID = NSRunningApplication.current.processIdentifier
        let pasteTarget = target?.processIdentifier == ownPID ? nil : target
        let autoPaste = service.autoPasteEnabled
        Task { @MainActor in
            let outcome = await ClipboardPasteService.shared.pasteRestoredItem(into: pasteTarget, autoPasteEnabled: autoPaste)
            if case .copiedOnly(let reason) = outcome {
                ClipboardHUD.shared.show(title: "Copied to Clipboard", message: reason.message)
            }
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}
