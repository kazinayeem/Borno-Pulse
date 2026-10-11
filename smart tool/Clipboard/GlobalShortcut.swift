//
//  GlobalShortcut.swift
//  Borno Pulse
//
//  System-wide shortcut registration via Carbon `RegisterEventHotKey`.
//  It is event-driven (no keyboard polling, no event tap) and does not require
//  Accessibility permission. While registered, macOS delivers the key combination
//  to Borno Pulse instead of the focused app, so the shortcut is only registered
//  when clipboard history and the shortcut are both enabled.
//
//  Conflict detection covers reserved editing shortcuts, enabled System Settings
//  shortcuts and common in-app shortcuts. macOS does not report hot keys registered
//  by other apps, so those conflicts cannot be detected in advance.
//

import AppKit
import Carbon.HIToolbox
import Combine

// MARK: - Shortcut Model

public struct KeyboardShortcutSpec: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    /// Carbon modifier mask (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`).
    public var modifiers: UInt32
    public var keyLabel: String

    public init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    public static let commandB = KeyboardShortcutSpec(
        keyCode: UInt32(kVK_ANSI_B),
        modifiers: UInt32(cmdKey),
        keyLabel: "B"
    )

    public var hasCommand: Bool { modifiers & UInt32(cmdKey) != 0 }
    public var hasShift: Bool { modifiers & UInt32(shiftKey) != 0 }
    public var hasOption: Bool { modifiers & UInt32(optionKey) != 0 }
    public var hasControl: Bool { modifiers & UInt32(controlKey) != 0 }

    public var displayString: String {
        var s = ""
        if hasControl { s += "⌃" }
        if hasOption { s += "⌥" }
        if hasShift { s += "⇧" }
        if hasCommand { s += "⌘" }
        return s + keyLabel
    }

    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }

    public init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        let code = UInt32(event.keyCode)
        let label = Self.label(forKeyCode: code) ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
        guard !label.isEmpty else { return nil }
        self.init(
            keyCode: code,
            modifiers: Self.carbonModifiers(from: event.modifierFlags.intersection(.deviceIndependentFlagsMask)),
            keyLabel: label
        )
    }

    static func label(forKeyCode code: UInt32) -> String? {
        switch Int(code) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        default: return nil
        }
    }
}

// MARK: - Validation

public enum ShortcutValidation: Equatable, Sendable {
    case valid
    case warning(String)
    case invalid(String)

    public var isAcceptable: Bool {
        if case .invalid = self { return false }
        return true
    }

    public var message: String? {
        switch self {
        case .valid: return nil
        case .warning(let m), .invalid(let m): return m
        }
    }
}

public enum ShortcutValidator {
    public struct SystemHotKey: Equatable, Sendable {
        public let keyCode: UInt32
        public let modifiers: UInt32
    }

    private static let functionKeyCodes: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19
    ]

    /// Command-only shortcuts that would break core editing or window management everywhere.
    private static let reservedCommandShortcuts: [Int: String] = [
        kVK_ANSI_C: "Copy", kVK_ANSI_V: "Paste", kVK_ANSI_X: "Cut", kVK_ANSI_Z: "Undo",
        kVK_ANSI_A: "Select All", kVK_ANSI_Q: "Quit", kVK_ANSI_W: "Close Window",
        kVK_ANSI_H: "Hide", kVK_ANSI_M: "Minimize", kVK_Tab: "App Switcher",
        kVK_Space: "Spotlight", kVK_ANSI_Grave: "Window Cycling", kVK_ANSI_Comma: "App Settings"
    ]

    /// Command-only shortcuts commonly used inside apps. Registering one takes it over globally.
    private static let commonAppShortcuts: [Int: String] = [
        kVK_ANSI_B: "Bold in TextEdit, Pages, Mail, Notes and rich-text editors in browsers",
        kVK_ANSI_I: "Italic in text editors",
        kVK_ANSI_U: "Underline in text editors",
        kVK_ANSI_F: "Find in most apps",
        kVK_ANSI_S: "Save in most apps",
        kVK_ANSI_N: "New Document/Window in most apps",
        kVK_ANSI_T: "New Tab in browsers and Finder",
        kVK_ANSI_P: "Print in most apps",
        kVK_ANSI_O: "Open in most apps",
        kVK_ANSI_R: "Reload in browsers",
        kVK_ANSI_L: "the address bar in browsers",
        kVK_ANSI_K: "Insert Link in many editors",
        kVK_ANSI_E: "Use Selection for Find",
        kVK_ANSI_G: "Find Next",
        kVK_ANSI_D: "Duplicate or Bookmark in many apps",
        kVK_ANSI_Y: "History or Quick Look in many apps"
    ]

    public static func validate(_ spec: KeyboardShortcutSpec, systemHotKeys: [SystemHotKey] = enabledSystemHotKeys()) -> ShortcutValidation {
        let code = Int(spec.keyCode)
        let isFunctionKey = functionKeyCodes.contains(code)

        if !(spec.hasCommand || spec.hasControl || spec.hasOption) && !isFunctionKey {
            return .invalid("Include ⌘, ⌃ or ⌥ so normal typing is not intercepted.")
        }
        if code == kVK_Escape || code == kVK_Return {
            return .invalid("\(spec.displayString) is needed to confirm and dismiss dialogs.")
        }

        let commandOnly = spec.hasCommand && !spec.hasShift && !spec.hasOption && !spec.hasControl
        if commandOnly, let name = reservedCommandShortcuts[code] {
            return .invalid("\(spec.displayString) is reserved for \(name) and cannot be used.")
        }
        if spec.hasCommand && spec.hasShift && !spec.hasOption && !spec.hasControl,
           [kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5].contains(code) {
            return .invalid("\(spec.displayString) is reserved for screenshots.")
        }
        if code == kVK_ANSI_Q && spec.hasCommand && spec.hasControl {
            return .invalid("\(spec.displayString) is reserved for Lock Screen.")
        }
        if systemHotKeys.contains(where: { $0.keyCode == spec.keyCode && $0.modifiers == spec.modifiers }) {
            return .invalid("\(spec.displayString) is already assigned in System Settings › Keyboard › Keyboard Shortcuts.")
        }
        if commandOnly, let usage = commonAppShortcuts[code] {
            return .warning("While active, \(spec.displayString) opens Clipboard History in every app instead of \(usage).")
        }
        return .valid
    }

    /// Enabled shortcuts from System Settings › Keyboard › Keyboard Shortcuts.
    public static func enabledSystemHotKeys() -> [SystemHotKey] {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr,
              let entries = unmanaged?.takeRetainedValue() as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            guard (entry["kHISymbolicHotKeyEnabled"] as? Bool) == true,
                  let code = (entry["kHISymbolicHotKeyCode"] as? NSNumber)?.uint32Value,
                  let mods = (entry["kHISymbolicHotKeyModifiers"] as? NSNumber)?.uint32Value else { return nil }
            let relevant = mods & UInt32(cmdKey | shiftKey | optionKey | controlKey)
            return SystemHotKey(keyCode: code, modifiers: relevant)
        }
    }
}

// MARK: - Registration

@MainActor
public final class GlobalHotKeyService: ObservableObject {
    public static let shared = GlobalHotKeyService()

    public enum Status: Equatable, Sendable {
        case inactive
        case registered(KeyboardShortcutSpec)
        case failed(String)
    }

    @Published public private(set) var status: Status = .inactive
    public var onTrigger: (() -> Void)?

    nonisolated static let signature: OSType = 0x424F_524E // "BORN"
    nonisolated static let clipboardHotKeyID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var suspendedSpec: KeyboardShortcutSpec?

    private init() {}

    public var registeredShortcut: KeyboardShortcutSpec? {
        if case .registered(let spec) = status { return spec }
        return nil
    }

    @discardableResult
    public func register(_ spec: KeyboardShortcutSpec) -> Status {
        if registeredShortcut == spec, hotKeyRef != nil { return status }
        unregister()
        guard ShortcutValidator.validate(spec).isAcceptable else {
            status = .failed("\(spec.displayString) cannot be used as a global shortcut.")
            return status
        }
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: Self.clipboardHotKeyID)
        let result = RegisterEventHotKey(spec.keyCode, spec.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if result == noErr, let ref {
            hotKeyRef = ref
            status = .registered(spec)
        } else if result == OSStatus(eventHotKeyExistsErr) {
            status = .failed("\(spec.displayString) is already registered as a hot key. Choose a different shortcut.")
        } else {
            status = .failed("macOS could not register \(spec.displayString) (error \(result)).")
        }
        return status
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        suspendedSpec = nil
        status = .inactive
    }

    /// Temporarily releases the shortcut, e.g. while the user records a new one.
    public func suspend() {
        guard let spec = registeredShortcut else { return }
        unregister()
        suspendedSpec = spec
    }

    public func resumeIfSuspended() {
        guard let spec = suspendedSpec else { return }
        suspendedSpec = nil
        register(spec)
    }

    fileprivate func handleHotKey(id: UInt32) {
        guard id == Self.clipboardHotKeyID, hotKeyRef != nil else { return }
        onTrigger?()
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard err == noErr, hotKeyID.signature == GlobalHotKeyService.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let id = hotKeyID.id
            DispatchQueue.main.async {
                GlobalHotKeyService.shared.handleHotKey(id: id)
            }
            return noErr
        }, 1, &eventSpec, nil, &handlerRef)
        if status != noErr {
            handlerRef = nil
        }
    }
}
