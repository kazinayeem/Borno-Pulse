//
//  ClipboardBackgroundController.swift
//  Borno Pulse
//
//  Owns the clipboard feature's app-lifetime pieces: monitoring, the global shortcut
//  and the clipboard status item. Started once at launch and stopped only on Quit,
//  so closing the main window never interrupts clipboard history.
//

import AppKit
import Combine

@MainActor
final class ClipboardBackgroundController {
    static let shared = ClipboardBackgroundController()

    private(set) var isRunning = false
    private var cancellables = Set<AnyCancellable>()
    private var isRecordingShortcut = false

    private init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let service = ClipboardManagerService.shared
        GlobalHotKeyService.shared.onTrigger = {
            ClipboardPickerController.shared.toggle()
        }

        Publishers.CombineLatest4(service.$isEnabled, service.$shortcutEnabled, service.$shortcut, service.$showMenuBarIcon)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &cancellables)
        sync()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        cancellables.removeAll()
        GlobalHotKeyService.shared.onTrigger = nil
        GlobalHotKeyService.shared.unregister()
        ClipboardPickerController.shared.close()
        ClipboardMenuBarController.shared.uninstall()
        ClipboardManagerService.shared.shutdown()
    }

    /// Releases the global shortcut while the user records a new one, so the keystroke reaches the recorder.
    func setRecordingShortcut(_ recording: Bool) {
        isRecordingShortcut = recording
        sync()
    }

    struct DesiredState: Equatable {
        let registerShortcut: Bool
        let showStatusItem: Bool
    }

    /// The shortcut is only owned while history is on, so a fresh install never captures ⌘B.
    nonisolated static func desiredState(
        historyEnabled: Bool,
        shortcutEnabled: Bool,
        recordingShortcut: Bool,
        showMenuBarIcon: Bool
    ) -> DesiredState {
        DesiredState(
            registerShortcut: historyEnabled && shortcutEnabled && !recordingShortcut,
            showStatusItem: historyEnabled && showMenuBarIcon
        )
    }

    private func sync() {
        guard isRunning else { return }
        let service = ClipboardManagerService.shared
        let desired = Self.desiredState(
            historyEnabled: service.isEnabled,
            shortcutEnabled: service.shortcutEnabled,
            recordingShortcut: isRecordingShortcut,
            showMenuBarIcon: service.showMenuBarIcon
        )

        if desired.registerShortcut {
            GlobalHotKeyService.shared.register(service.shortcut)
        } else {
            GlobalHotKeyService.shared.unregister()
        }

        if desired.showStatusItem {
            ClipboardMenuBarController.shared.install()
        } else {
            ClipboardMenuBarController.shared.uninstall()
        }

        if !service.isEnabled {
            ClipboardPickerController.shared.close()
        }
    }
}
