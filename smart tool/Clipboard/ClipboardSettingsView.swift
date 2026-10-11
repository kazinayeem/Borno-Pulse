//
//  ClipboardSettingsView.swift
//  Borno Pulse
//
//  Clipboard preferences shown in Settings › Clipboard and in the Clipboard Manager sheet.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardSettingsView: View {
    @ObservedObject var service = ClipboardManagerService.shared
    @ObservedObject var hotKeys = GlobalHotKeyService.shared

    @State private var isRecording = false
    @State private var recorderMessage: String?
    @State private var keyMonitor: Any?
    @State private var accessibilityTrusted = ClipboardPasteService.shared.isAccessibilityTrusted
    @State private var confirmingDeleteAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            historySection
            shortcutSection
            pasteSection
            storageSection
            privacySection
            startupSection
            dataSection
        }
        .onAppear { refreshPermissionState() }
        .onDisappear { stopRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionState()
        }
        .confirmationDialog(
            "Delete all clipboard data?",
            isPresented: $confirmingDeleteAll
        ) {
            Button("Delete Everything", role: .destructive) { service.wipeEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every history item, including pinned items and stored images. It can't be undone.")
        }
    }

    // MARK: - History

    private var historySection: some View {
        section("Clipboard History", icon: "doc.on.clipboard") {
            HStack(alignment: .firstTextBaseline) {
                Toggle("Record clipboard history", isOn: $service.isEnabled)
                    .toggleStyle(.switch)
                Spacer()
                MonitoringStatusBadge(state: service.monitoringState)
            }
            note("Off by default. When on, Borno Pulse checks the clipboard's change counter twice a second and keeps new copies on this Mac only. Nothing is sent over the network. History keeps recording after you close the window, until you quit Borno Pulse.")

            if service.isEnabled {
                HStack(spacing: 8) {
                    if service.isPaused {
                        Button {
                            service.resume()
                        } label: {
                            Label("Resume Recording", systemImage: "play.fill")
                        }
                        if let until = service.pausedUntil {
                            Text("Paused until \(until.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    } else {
                        ForEach(ClipboardPauseDuration.allCases) { duration in
                            Button(duration.label) { service.pause(for: duration) }
                        }
                    }
                }
                .controlSize(.small)
            }

            Toggle("Show clipboard icon in the menu bar", isOn: $service.showMenuBarIcon)
            note("Gives quick access to history, pause/resume, recent items and Quit. Shown only while history is on.")
        }
    }

    // MARK: - Shortcut

    private var shortcutSection: some View {
        section("Global Shortcut", icon: "keyboard") {
            Toggle("Open Clipboard History with a keyboard shortcut", isOn: $service.shortcutEnabled)

            HStack(spacing: 10) {
                Text(isRecording ? "Type a shortcut…" : service.shortcut.displayString)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isRecording ? AppTheme.electricBlue : AppTheme.textPrimary)
                    .frame(minWidth: 120)
                    .padding(.vertical, 5)
                    .themedInputField(isFocused: isRecording)
                    .accessibilityLabel(isRecording ? "Recording shortcut" : "Shortcut \(service.shortcut.displayString)")

                Button(isRecording ? "Cancel" : "Record Shortcut") {
                    isRecording ? stopRecording() : startRecording()
                }
                Button("Reset to ⌘B") {
                    stopRecording()
                    recorderMessage = nil
                    service.shortcut = .commandB
                }
                .disabled(service.shortcut == .commandB)
            }
            .controlSize(.small)
            .disabled(!service.shortcutEnabled)

            if let recorderMessage {
                statusLine(recorderMessage, symbol: "xmark.octagon.fill", color: AppTheme.dangerRed)
            }
            if case .warning(let message) = ShortcutValidator.validate(service.shortcut) {
                statusLine(message, symbol: "exclamationmark.triangle.fill", color: AppTheme.warningAmber)
            }
            hotKeyStatus

            note("Registered with the standard macOS hot-key service: no Accessibility or Input Monitoring permission and no keyboard monitoring. While active, macOS sends this key combination to Borno Pulse in every app, so apps won't receive it. ⌘V is never intercepted. The shortcut is released when history or the shortcut is turned off.")
        }
    }

    @ViewBuilder
    private var hotKeyStatus: some View {
        switch hotKeys.status {
        case .registered(let spec):
            statusLine("\(spec.displayString) is active.", symbol: "checkmark.circle.fill", color: AppTheme.successGreen)
        case .failed(let message):
            statusLine(message, symbol: "xmark.octagon.fill", color: AppTheme.dangerRed)
        case .inactive:
            if !service.isEnabled {
                statusLine("Inactive while clipboard history is off.", symbol: "minus.circle", color: AppTheme.textTertiary)
            } else if !service.shortcutEnabled {
                statusLine("Shortcut turned off.", symbol: "minus.circle", color: AppTheme.textTertiary)
            } else if isRecording {
                statusLine("Released while recording.", symbol: "record.circle", color: AppTheme.textTertiary)
            }
        }
    }

    private func startRecording() {
        guard keyMonitor == nil else { return }
        recorderMessage = nil
        isRecording = true
        ClipboardBackgroundController.shared.setRecordingShortcut(true)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 53 && flags.isEmpty {
                stopRecording()
                return nil
            }
            guard let spec = KeyboardShortcutSpec(event: event) else { return nil }
            let validation = ShortcutValidator.validate(spec)
            if validation.isAcceptable {
                recorderMessage = nil
                service.shortcut = spec
                stopRecording()
            } else {
                recorderMessage = validation.message
            }
            return nil
        }
    }

    private func stopRecording() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        if isRecording {
            isRecording = false
            ClipboardBackgroundController.shared.setRecordingShortcut(false)
        }
    }

    // MARK: - Paste

    private var pasteSection: some View {
        section("Automatic Paste", icon: "arrow.down.doc") {
            Toggle("Paste into the previous app after choosing an item", isOn: $service.autoPasteEnabled)

            if accessibilityTrusted {
                statusLine("Accessibility access granted.", symbol: "checkmark.circle.fill", color: AppTheme.successGreen)
            } else {
                statusLine("Accessibility access not granted — chosen items are copied and you press ⌘V.", symbol: "hand.raised.fill", color: AppTheme.warningAmber)
                HStack(spacing: 8) {
                    Button("Request Access…") {
                        ClipboardPasteService.shared.requestAccessibilityAccess()
                    }
                    Button("Open Accessibility Settings") {
                        ClipboardPasteService.shared.openAccessibilitySettings()
                    }
                }
                .controlSize(.small)
                .disabled(!service.autoPasteEnabled)
            }

            note("macOS only lets an app type into another app by sending a ⌘V keystroke, which requires Accessibility access. The item is always placed on the clipboard first. No keystroke is sent while a secure field such as a password box is active, and Borno Pulse can't confirm that the receiving app accepted the paste. Without access, press ⌘V yourself.")
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        section("Retention & Storage", icon: "externaldrive") {
            Picker("Keep unpinned items for", selection: $service.retention) {
                ForEach(ClipboardRetention.allCases) { Text($0.label).tag($0) }
            }
            .frame(maxWidth: 360)
            Picker("Maximum items", selection: $service.maxItemsCount) {
                ForEach(Self.options([50, 100, 200, 500, 1000], including: service.maxItemsCount), id: \.self) { Text("\($0) items").tag($0) }
            }
            .frame(maxWidth: 360)
            Picker("Largest item to record", selection: $service.maxItemSizeMB) {
                ForEach(Self.options([1, 5, 10, 25, 50], including: service.maxItemSizeMB), id: \.self) { Text("\($0) MB").tag($0) }
            }
            .frame(maxWidth: 360)
            Picker("Image storage limit", selection: $service.imageStorageLimitMB) {
                ForEach(Self.options([50, 100, 250, 500, 1000], including: service.imageStorageLimitMB), id: \.self) { Text("\($0) MB").tag($0) }
            }
            .frame(maxWidth: 360)

            HStack(spacing: 6) {
                Text("\(service.items.count) items · images use \(Formatters.bytes(UInt64(max(0, service.imageStorageBytes)))) of \(service.imageStorageLimitMB) MB")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([service.storage.rootDirectory])
                }
                .controlSize(.small)
            }
            note("Pinned items are never removed automatically. Oldest unpinned items are removed first when a limit is reached. Images are stored as files in an owner-only folder excluded from Time Machine. History is protected by macOS file permissions and FileVault, not by separate encryption.")
        }
    }

    private static func options(_ base: [Int], including current: Int) -> [Int] {
        base.contains(current) ? base : (base + [current]).sorted()
    }

    // MARK: - Privacy

    private var privacySection: some View {
        section("Privacy & Exclusions", icon: "hand.raised") {
            Toggle("Skip passwords, secrets and card numbers when detectable", isOn: $service.filterSensitive)
            note("Skipped: content password managers mark as concealed or transient, copies made while an excluded app is in front, and text matching common key/token/card patterns. macOS doesn't reveal which field content came from, so other sensitive text can't be detected reliably — pause history or exclude the app when handling secrets.")

            Text("Excluded apps")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 4)

            VStack(spacing: 4) {
                ForEach(service.excludedBundleIDs.sorted(), id: \.self) { bundleID in
                    HStack(spacing: 8) {
                        if let icon = Self.appIcon(for: bundleID) {
                            Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "app.dashed").frame(width: 16, height: 16)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Text(Self.appName(for: bundleID))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(bundleID)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AppTheme.textTertiary)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            service.removeExcludedApp(bundleID: bundleID)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Stop excluding \(Self.appName(for: bundleID))")
                        .accessibilityLabel("Remove \(Self.appName(for: bundleID)) from exclusions")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppTheme.insetBackground))
                }
            }

            HStack(spacing: 8) {
                Menu("Add Running App") {
                    let candidates = runningAppCandidates
                    if candidates.isEmpty {
                        Text("No other apps running")
                    }
                    ForEach(candidates, id: \.bundleID) { app in
                        Button(app.name) { service.addExcludedApp(bundleID: app.bundleID) }
                    }
                }
                .frame(maxWidth: 200)
                Button("Choose App…") { chooseAppToExclude() }
                Button("Restore Defaults") {
                    service.excludedBundleIDs.formUnion(ClipboardManagerService.defaultExcludedBundleIDs)
                }
            }
            .controlSize(.small)
        }
    }

    private var runningAppCandidates: [(name: String, bundleID: String)] {
        let ownID = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (String, String)? in
                guard let id = app.bundleIdentifier, id != ownID, !service.excludedBundleIDs.contains(id) else { return nil }
                return (app.localizedName ?? id, id)
            }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
            .map { (name: $0.0, bundleID: $0.1) }
    }

    private func chooseAppToExclude() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Exclude"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier {
                service.addExcludedApp(bundleID: id)
            }
        }
    }

    private static func appURL(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    private static func appName(for bundleID: String) -> String {
        guard let url = appURL(for: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private static func appIcon(for bundleID: String) -> NSImage? {
        appURL(for: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    // MARK: - Startup & Data

    private var startupSection: some View {
        section("Startup", icon: "power") {
            LaunchAtLoginToggle()
            note("Starts Borno Pulse in the background when you log in so clipboard history and the shortcut are ready. Only added when you turn this on.")
        }
    }

    private var dataSection: some View {
        section("Clipboard Data", icon: "trash") {
            HStack(spacing: 8) {
                Button("Clear Unpinned Items") { service.clearAll() }
                    .disabled(!service.items.contains { !$0.isPinned })
                Button("Delete All Clipboard Data…", role: .destructive) {
                    confirmingDeleteAll = true
                }
                .buttonStyle(.themedPrimary(fill: AppTheme.dangerFill, horizontalPadding: 12, verticalPadding: 5))
            }
            .controlSize(.small)
        }
    }

    // MARK: - Helpers

    private func refreshPermissionState() {
        accessibilityTrusted = ClipboardPasteService.shared.isAccessibilityTrusted
    }

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(AppTypography.font(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            content()
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .smartCard()
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func statusLine(_ text: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11))
    }
}

/// Login-item toggle that reflects the real ServiceManagement state.
struct LaunchAtLoginToggle: View {
    var title = "Launch at Login"
    @ObservedObject private var settings = AppSettings.shared
    @State private var status: LaunchAtLoginStatus = LaunchAtLoginService.shared.status

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: Binding(
                get: { status.isOn },
                set: { newValue in
                    status = LaunchAtLoginService.shared.setEnabled(newValue)
                    settings.launchAtLogin = status.isOn
                }
            ))
            if let message = status.message {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.warningAmber)
                    Text(message)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Login Items") {
                        LaunchAtLoginService.shared.openLoginItemsSettings()
                    }
                    .controlSize(.small)
                }
                .font(.system(size: 11))
            }
        }
        .onAppear {
            status = LaunchAtLoginService.shared.status
            if settings.launchAtLogin != status.isOn {
                settings.launchAtLogin = status.isOn
            }
        }
    }
}
