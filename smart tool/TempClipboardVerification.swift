// TEMPORARY live verification hook — delete after verification.

import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
enum TempClipboardVerification {
    static var log: [String] = []
    static var outDir: URL!

    static func note(_ s: String) {
        log.append(s)
        try? log.joined(separator: "\n").write(to: outDir.appendingPathComponent("log.txt"), atomically: true, encoding: .utf8)
    }

    static func snapshot(_ view: NSView, _ name: String) {
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { note("snapshot \(name) failed"); return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: outDir.appendingPathComponent("\(name).png"))
    }

    static func render<V: View>(_ view: V, size: NSSize, appearance: NSAppearance.Name, _ name: String) {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        snapshot(host, name)
    }

    static func after(_ seconds: Double, _ block: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { MainActor.assumeIsolated { block() } }
    }

    static func runIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["BORNO_VERIFY_CLIPBOARD"] else { return }
        outDir = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let service = ClipboardManagerService.shared
        let marker = "Borno live verification \(UUID().uuidString.prefix(8))"
        var savedItems: [NSPasteboardItem] = []

        after(2) {
            note("AX trusted: \(AXIsProcessTrusted())")
            note("enabled=\(service.isEnabled) paused=\(service.isPaused) polling=\(service.isPolling) state=\(service.monitoringState.label)")
            note("hotkey status: \(GlobalHotKeyService.shared.status)")
            note("clipboard status item installed: \(ClipboardMenuBarController.shared.isInstalled)")
            note("main window present: \(MainWindowRouter.shared.mainWindow != nil) visible: \(MainWindowRouter.shared.mainWindow?.isVisible ?? false)")
            MainWindowRouter.shared.showMainWindow(section: .clipboard)
        }
        after(3.5) {
            if let w = MainWindowRouter.shared.mainWindow, let v = w.contentView { snapshot(v, "1-page") }
            MainWindowRouter.shared.mainWindow?.performClose(nil)
        }
        after(4.5) {
            let w = MainWindowRouter.shared.mainWindow
            note("after close: window visible=\(w?.isVisible ?? false) app running=true polling=\(service.isPolling) statusItem=\(ClipboardMenuBarController.shared.isInstalled) hotkey=\(GlobalHotKeyService.shared.status)")
            // Save the user's clipboard so it can be restored exactly.
            let pb = NSPasteboard.general
            savedItems = (pb.pasteboardItems ?? []).map { item in
                let copy = NSPasteboardItem()
                for type in item.types { if let d = item.data(forType: type) { copy.setData(d, forType: type) } }
                return copy
            }
            note("saved \(savedItems.count) clipboard items")
            pb.clearContents()
            pb.setString(marker, forType: .string)
        }
        after(6) {
            let top = service.items.first
            note("live capture with window closed: \(top?.contentText == marker) source=\(top?.sourceAppName ?? "nil")")
            // Fire the real registered hot key path.
            var eventRef: EventRef?
            CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, EventAttributes(kEventAttributeNone), &eventRef)
            var hk = EventHotKeyID(signature: GlobalHotKeyService.signature, id: GlobalHotKeyService.clipboardHotKeyID)
            SetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &hk)
            SendEventToEventTarget(eventRef, GetApplicationEventTarget())
            ReleaseEvent(eventRef)
        }
        after(7) {
            let picker = ClipboardPickerController.shared
            let panel = NSApp.windows.first { $0 is ClipboardPickerPanel }
            let responder = panel?.firstResponder
            note("picker visible=\(picker.isVisible) key=\(panel?.isKeyWindow ?? false) appActive=\(NSApp.isActive) firstResponder=\(responder.map { String(describing: type(of: $0)) } ?? "nil")")
            note("picker results=\(picker.model.results.count) selected=\(picker.model.selectedItem?.contentText == marker)")
            if let v = panel?.contentView { snapshot(v, "2-picker") }
            picker.model.query = "zz-no-match-zz"
        }
        after(7.6) {
            let panel = NSApp.windows.first { $0 is ClipboardPickerPanel }
            if let v = panel?.contentView { snapshot(v, "3-picker-nomatch") }
            if let esc = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panel?.windowNumber ?? 0, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53) {
                panel?.sendEvent(esc)
            }
            note("picker after Escape visible=\(ClipboardPickerController.shared.isVisible)")
            try? "ready".write(to: outDir.appendingPathComponent("ready-for-keystroke"), atomically: true, encoding: .utf8)
        }
        // Window for a real ⌘B keystroke sent from outside the app.
        after(16) {
            note("picker visible after external ⌘B=\(ClipboardPickerController.shared.isVisible)")
            ClipboardPickerController.shared.close()
            render(ClipboardMenuBarPopoverView(service: service, hotKeys: .shared, actions: ClipboardMenuActions(openHistory: {}, restore: { _ in }, openManager: {}, openSettings: {}, quit: {})), size: NSSize(width: 340, height: 420), appearance: .aqua, "4-popover-light")
            render(ClipboardMenuBarPopoverView(service: service, hotKeys: .shared, actions: ClipboardMenuActions(openHistory: {}, restore: { _ in }, openManager: {}, openSettings: {}, quit: {})), size: NSSize(width: 340, height: 420), appearance: .darkAqua, "5-popover-dark")
            let model = ClipboardPickerModel(service: service)
            model.reset()
            render(ClipboardPickerView(model: model, service: service, onChoose: { _ in }, onClose: {}, onOpenSettings: {}), size: NSSize(width: 480, height: 540), appearance: .darkAqua, "6-picker-dark")
            render(ScrollView { ClipboardSettingsView().padding(20) }, size: NSSize(width: 760, height: 1900), appearance: .aqua, "7-settings-light")
            let menu = ClipboardMenuBarController.shared.buildMenu()
            note("menu: " + menu.items.map { $0.isSeparatorItem ? "—" : $0.title }.joined(separator: " | "))
            MainWindowRouter.shared.showMainWindow(section: .clipboard)
        }
        after(17.5) {
            let w = MainWindowRouter.shared.mainWindow
            note("reopened window visible=\(w?.isVisible ?? false) windows=\(NSApp.windows.filter { $0.identifier?.rawValue.hasPrefix("main-window") == true }.count)")
            MainWindowRouter.shared.openSettings(tab: .clipboard)
        }
        after(19) {
            if let w = MainWindowRouter.shared.mainWindow, let v = w.contentView { snapshot(v, "8-settings-tab") }
            // Clean up: remove the verification item and restore the user's clipboard.
            if let item = service.items.first(where: { $0.contentText == marker }) { service.deleteItem(item.id) }
            let pb = NSPasteboard.general
            pb.clearContents()
            if !savedItems.isEmpty { pb.writeObjects(savedItems) }
            note("restored clipboard; history count now \(service.items.count)")
            note("DONE")
            NSApp.terminate(nil)
        }
    }
}
