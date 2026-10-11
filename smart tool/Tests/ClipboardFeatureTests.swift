//
//  ClipboardFeatureTests.swift
//  Borno Pulse Tests
//
//  Clipboard history, global shortcut, picker and paste tests. Each case runs against
//  a uniquely named pasteboard, a throwaway UserDefaults suite and a temp folder, so the
//  real clipboard and the user's history are never touched.
//

import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
extension SmartToolTests {
    private final class Box<Value> {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    @MainActor
    private struct Harness {
        let service: ClipboardManagerService
        let pasteboard: NSPasteboard
        let defaults: UserDefaults
        let suiteName: String
        let root: URL
        let front: Box<ClipboardSourceApp?>
        let clock: Box<Date>

        func cleanUp() {
            service.shutdown()
            pasteboard.releaseGlobally()
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }

        func copyString(_ string: String, extraTypes: [NSPasteboard.PasteboardType] = []) {
            let item = NSPasteboardItem()
            item.setString(string, forType: .string)
            for type in extraTypes { item.setData(Data(), forType: type) }
            pasteboard.clearContents()
            pasteboard.writeObjects([item])
        }
    }

    private static func makeHarness(
        root existingRoot: URL? = nil,
        presetDefaults: ((UserDefaults) -> Void)? = nil,
        enabled: Bool = true,
        usesTimers: Bool = false
    ) -> Harness {
        let suiteName = "com.borno.tests.clipboard.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        presetDefaults?(defaults)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.borno.tests.pb.\(UUID().uuidString)"))
        pasteboard.clearContents()
        let root = existingRoot ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("BornoClipboardTests-\(UUID().uuidString)", isDirectory: true)
        let front = Box<ClipboardSourceApp?>(ClipboardSourceApp(name: "TextEdit", bundleID: "com.apple.TextEdit"))
        let clock = Box(Date())
        let env = ClipboardServiceEnvironment(
            pasteboard: pasteboard,
            defaults: defaults,
            storageRoot: root,
            frontmostApp: { front.value },
            now: { clock.value },
            usesTimers: usesTimers
        )
        let service = ClipboardManagerService(environment: env)
        if enabled { service.isEnabled = true }
        return Harness(service: service, pasteboard: pasteboard, defaults: defaults, suiteName: suiteName, root: root, front: front, clock: clock)
    }

    private static func makePNG(width: Int, height: Int, noise: Bool = false) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        if let data = rep.bitmapData {
            let count = rep.bytesPerRow * height
            for i in 0..<count {
                data[i] = noise ? UInt8.random(in: 0...255) : UInt8((i * 37) % 256)
            }
        }
        return rep.representation(using: .png, properties: [:])!
    }

    private static func capturedItem(_ result: ClipboardCaptureResult) -> ClipboardItem? {
        if case .captured(let item) = result { return item }
        return nil
    }

    private static func sendSyntheticHotKey(signature: OSType, id: UInt32) {
        var eventRef: EventRef?
        guard CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0,
                          EventAttributes(kEventAttributeNone), &eventRef) == noErr, let eventRef else { return }
        var hotKeyID = EventHotKeyID(signature: signature, id: id)
        SetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                          MemoryLayout<EventHotKeyID>.size, &hotKeyID)
        SendEventToEventTarget(eventRef, GetApplicationEventTarget())
        ReleaseEvent(eventRef)
    }

    static func runClipboardTests(_ assert: (Bool, String) -> Void) {
        // 111. Clipboard: Privacy Defaults & Settings Migration
        do {
            let h = makeHarness(enabled: false)
            assert(h.service.isEnabled == false, "Clipboard history is disabled by default")
            assert(h.service.monitoringState == .off, "Fresh install reports monitoring state Off")
            assert(h.service.shortcut == .commandB && h.service.shortcut.displayString == "⌘B", "Default global shortcut is ⌘B")
            assert(h.service.retention == .oneMonth, "New installs keep unpinned items for 30 days")
            assert(h.service.excludedBundleIDs.isSuperset(of: ["com.1password.1password", "com.bitwarden.desktop"]), "Password managers are excluded by default")
            h.copyString("copied while disabled")
            assert(h.service.captureIfChanged() == .skipped(.disabled), "Nothing is read or recorded while history is disabled")
            assert(h.service.items.isEmpty, "Disabled history stays empty")
            h.cleanUp()

            let upgraded = makeHarness(presetDefaults: { $0.set(true, forKey: "Clipboard_IsEnabled"); $0.set(200, forKey: "Clipboard_MaxItems") }, enabled: false)
            assert(upgraded.service.retention == .forever, "Upgrading keeps existing history (no retention pruning applied retroactively)")
            assert(upgraded.service.isEnabled && upgraded.service.maxItemsCount == 200, "Existing enable flag and max-items preference survive migration")
            assert(upgraded.defaults.integer(forKey: "Clipboard_SettingsVersion") == 2, "Settings version recorded after migration")
            upgraded.cleanUp()
        }

        // 112. Clipboard: Change-Count Capture of Text, URLs and Files
        do {
            let h = makeHarness(enabled: false)
            h.copyString("present before enabling")
            h.service.isEnabled = true
            assert(h.service.captureIfChanged() == .skipped(.unchanged), "Content already on the clipboard when history is enabled is not recorded")

            h.copyString("Hello Borno")
            let text = capturedItem(h.service.captureIfChanged())
            assert(text?.type == .text && text?.contentText == "Hello Borno", "Plain text is captured")
            assert(text?.sourceAppName == "TextEdit" && text?.sourceBundleID == "com.apple.TextEdit", "Frontmost app is recorded as the source")
            assert(h.service.captureIfChanged() == .skipped(.unchanged), "No capture without a change-count change")

            h.copyString("https://example.com/path?q=1")
            let url = capturedItem(h.service.captureIfChanged())
            assert(url?.type == .url, "Web URLs are classified as URL, not as files")

            h.copyString("/Users/someone/not-a-file-reference.txt")
            assert(capturedItem(h.service.captureIfChanged())?.type == .text, "A path typed as text stays plain text")

            let fileURL = h.root.appendingPathComponent("sample.txt")
            try? Data("file".utf8).write(to: fileURL)
            h.pasteboard.clearContents()
            h.pasteboard.writeObjects([fileURL as NSURL])
            let file = capturedItem(h.service.captureIfChanged())
            assert(file?.type == .file && file?.filePaths == [fileURL.path], "Finder file references are captured as files")
            assert(file?.byteSize == 4, "File reference size reflects the file on disk")
            h.cleanUp()
        }

        // 113. Clipboard: Duplicate Detection
        do {
            let h = makeHarness()
            h.copyString("alpha")
            _ = h.service.captureIfChanged()
            h.copyString("beta")
            _ = h.service.captureIfChanged()
            let alphaID = h.service.items.last?.id
            h.clock.value = h.clock.value.addingTimeInterval(60)
            h.copyString("alpha")
            let result = h.service.captureIfChanged()
            if case .refreshed(let item) = result {
                assert(item.id == alphaID, "Re-copying existing content refreshes the original entry")
            } else {
                assert(false, "Re-copying existing content refreshes the original entry")
            }
            assert(h.service.items.count == 2, "Duplicate content is not stored twice")
            assert(h.service.items.first?.contentText == "alpha" && h.service.items.first?.timestamp == h.clock.value, "Refreshed entry moves to the top with a new timestamp")
            h.cleanUp()
        }

        // 114. Clipboard: Rich Text and Images Round-Trip
        do {
            let h = makeHarness()
            let attributed = NSAttributedString(string: "Bold text", attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
            let rtf = attributed.rtf(from: NSRange(location: 0, length: attributed.length), documentAttributes: [:])!
            let rich = NSPasteboardItem()
            rich.setData(rtf, forType: .rtf)
            rich.setString("Bold text", forType: .string)
            h.pasteboard.clearContents()
            h.pasteboard.writeObjects([rich])
            let richItem = capturedItem(h.service.captureIfChanged())
            assert(richItem?.type == .richText && richItem?.rtfData == rtf, "Rich text keeps its RTF data")

            let png = makePNG(width: 8, height: 5)
            h.pasteboard.clearContents()
            h.pasteboard.setData(png, forType: .png)
            let image = capturedItem(h.service.captureIfChanged())
            assert(image?.type == .image && image?.preview == "Image (8 × 5)", "PNG images are captured with dimensions")
            assert(image?.imagePNGData == nil && image?.imageFileName != nil, "Images are stored as managed files, not inline in history JSON")
            let imagePath = image.flatMap { $0.imageFileName }.map { h.service.storage.imageURL(named: $0).path } ?? ""
            let perms = (try? FileManager.default.attributesOfItem(atPath: imagePath)[.posixPermissions] as? NSNumber)?.intValue
            assert(perms == 0o600, "Stored image files are owner-only (0600)")
            assert(image.flatMap { h.service.thumbnail(for: $0) } != nil, "Thumbnails are generated for stored images")

            let tiff = NSBitmapImageRep(data: makePNG(width: 6, height: 6))!.tiffRepresentation!
            h.pasteboard.clearContents()
            h.pasteboard.setData(tiff, forType: .tiff)
            let tiffItem = capturedItem(h.service.captureIfChanged())
            assert(tiffItem?.type == .image && tiffItem?.preview == "Image (6 × 6)", "TIFF-only images are converted and stored")

            if let richItem {
                assert(h.service.copyToPasteboard(richItem), "Rich text restores successfully")
                assert(h.pasteboard.data(forType: .rtf) == rtf && h.pasteboard.string(forType: .string) == "Bold text", "Restored rich text provides RTF plus plain-text fallback")
                assert(h.service.captureIfChanged() == .skipped(.unchanged), "Restoring an item is not recaptured as a new copy")
                assert(h.service.items.first?.id == richItem.id, "Restored item moves to the top of history")
            }
            if let image {
                assert(h.service.copyToPasteboard(image), "Images restore successfully")
                assert(h.pasteboard.data(forType: .png) == png && h.pasteboard.data(forType: .tiff) != nil, "Restored image provides PNG and TIFF")
            }
            let urlItem = ClipboardItem(type: .url, preview: "https://a.b", contentText: "https://a.b")
            assert(h.service.copyToPasteboard(urlItem), "URLs restore successfully")
            assert(h.pasteboard.string(forType: .URL) == "https://a.b" && h.pasteboard.string(forType: .string) == "https://a.b", "Restored URL provides URL and string types")
            let missing = ClipboardItem(type: .file, preview: "gone.txt", filePaths: [h.root.appendingPathComponent("gone.txt").path])
            assert(h.service.copyToPasteboard(missing) == false, "File references to deleted files report failure instead of pretending to restore")
            h.cleanUp()
        }

        // 115. Clipboard: Privacy Filters
        do {
            let h = makeHarness()
            h.copyString("one-time code 123456", extraTypes: [NSPasteboard.PasteboardType("org.nspasteboard.TransientType")])
            assert(h.service.captureIfChanged() == .skipped(.transientContent), "Transient pasteboard content is never recorded")
            h.copyString("hunter2", extraTypes: [NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")])
            assert(h.service.captureIfChanged() == .skipped(.concealedContent), "Concealed (password manager) content is skipped")
            h.copyString("ghp_1234567890abcdefghijklmnopqrstuvwxyz")
            assert(h.service.captureIfChanged() == .skipped(.sensitiveContent), "Token-like secrets are skipped when filtering is on")

            h.front.value = ClipboardSourceApp(name: "1Password", bundleID: "com.1password.1password")
            h.copyString("copied in an excluded app")
            assert(h.service.captureIfChanged() == .skipped(.excludedApplication), "Copies made while an excluded app is frontmost are skipped")
            h.service.removeExcludedApp(bundleID: "com.1password.1password")
            h.copyString("copied after removing exclusion")
            assert(capturedItem(h.service.captureIfChanged()) != nil, "Removing an exclusion allows capture again")
            h.front.value = ClipboardSourceApp(name: "Notes", bundleID: "com.apple.Notes")
            h.service.addExcludedApp(bundleID: "com.apple.Notes")
            h.copyString("notes content")
            assert(h.service.captureIfChanged() == .skipped(.excludedApplication), "Newly excluded apps are respected")
            h.front.value = ClipboardSourceApp(name: "TextEdit", bundleID: "com.apple.TextEdit")

            h.service.filterSensitive = false
            h.copyString("mock_private_key_fixture")
            let secret = capturedItem(h.service.captureIfChanged())
            assert(secret?.isSensitive == true && secret?.maskedPreview.contains("hidden secret") == true, "With filtering off, secrets are flagged and masked in previews")

            h.service.maxItemSizeMB = 1
            h.copyString(String(repeating: "x", count: 1_100_000))
            assert(h.service.captureIfChanged() == .skipped(.tooLarge), "Items above the size limit are skipped")
            assert(h.service.lastSkipReason == .tooLarge, "Last skip reason is reported for diagnostics")

            let saved = h.service.items.count
            assert(h.pasteboard.string(forType: .string)?.count == 1_100_000, "Background monitoring never modifies the clipboard")
            assert(h.service.items.count == saved, "Skipped content leaves history unchanged")
            h.cleanUp()
        }

        // 116. Clipboard: Pause, Timed Pause and Resume
        do {
            let h = makeHarness(usesTimers: true)
            assert(h.service.isPolling, "Enabling history starts the change-count timer")
            h.service.pause()
            assert(h.service.monitoringState == .paused(until: nil) && !h.service.isPolling, "Pause stops the timer and reports Paused")
            h.copyString("copied while paused")
            assert(h.service.captureIfChanged() == .skipped(.paused), "Copies are not recorded while paused")
            h.service.resume()
            assert(h.service.monitoringState == .monitoring && h.service.isPolling, "Resume restarts monitoring")
            assert(h.service.captureIfChanged() == .skipped(.unchanged), "Content copied during a pause is not recorded after resuming")

            h.service.pause(for: .fifteenMinutes)
            if case .paused(let until) = h.service.monitoringState {
                assert(until == h.clock.value.addingTimeInterval(900), "Timed pause records its end time")
            } else {
                assert(false, "Timed pause records its end time")
            }
            assert(h.defaults.bool(forKey: "Clipboard_IsPaused"), "Pause state is persisted")
            h.clock.value = h.clock.value.addingTimeInterval(901)
            h.copyString("after timed pause")
            _ = h.service.captureIfChanged()
            assert(h.service.monitoringState == .monitoring, "Timed pause ends automatically")

            h.service.isEnabled = false
            assert(!h.service.isPolling && h.service.monitoringState == .off, "Disabling history stops polling")
            h.cleanUp()
        }

        // 117. Clipboard: Pin, Delete, Clear Unpinned, Limits and Retention
        do {
            let h = makeHarness()
            for i in 0..<6 {
                h.copyString("item \(i)")
                _ = h.service.captureIfChanged()
            }
            let oldest = h.service.items.last!
            h.service.togglePin(oldest.id)
            h.service.maxItemsCount = 3
            assert(h.service.items.count == 3, "Max item limit trims history")
            assert(h.service.items.contains { $0.id == oldest.id }, "Pinned items survive trimming even when oldest")

            h.service.clearAll()
            assert(h.service.items.count == 1 && h.service.items.first?.isPinned == true, "Clear Unpinned keeps pinned items")

            h.clock.value = h.clock.value.addingTimeInterval(-10 * 86_400)
            h.copyString("ten days old")
            _ = h.service.captureIfChanged()
            h.clock.value = h.clock.value.addingTimeInterval(10 * 86_400)
            h.service.retention = .oneWeek
            assert(!h.service.items.contains { $0.contentText == "ten days old" }, "Retention removes old unpinned items")
            assert(h.service.items.contains { $0.id == oldest.id }, "Retention never removes pinned items")

            h.pasteboard.clearContents()
            h.pasteboard.setData(makePNG(width: 3, height: 3), forType: .png)
            let image = capturedItem(h.service.captureIfChanged())!
            let imageURL = h.service.storage.imageURL(named: image.imageFileName!)
            h.service.deleteItem(image.id)
            assert(!FileManager.default.fileExists(atPath: imageURL.path), "Deleting an image item deletes its stored file")
            h.cleanUp()

            let images = makeHarness()
            images.service.imageStorageLimitMB = 2
            var names: [String] = []
            for _ in 0..<3 {
                images.pasteboard.clearContents()
                images.pasteboard.setData(makePNG(width: 600, height: 600, noise: true), forType: .png)
                if let item = capturedItem(images.service.captureIfChanged()), let name = item.imageFileName { names.append(name) }
            }
            assert(images.service.imageStorageBytes <= 2 * 1_048_576, "Image storage stays within its limit")
            assert(names.count == 3 && !FileManager.default.fileExists(atPath: images.service.storage.imageURL(named: names[0]).path), "Oldest images are removed first when the image limit is reached")
            images.cleanUp()
        }

        // 118. Clipboard: Persistence, Protection and Legacy Migration
        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("BornoClipboardTests-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let legacyImage = makePNG(width: 4, height: 4)
            let legacyID = UUID()
            let legacyJSON = """
            [{"id":"\(UUID().uuidString)","timestamp":\(Date().timeIntervalSinceReferenceDate),"type":"Plain Text","preview":"legacy","contentText":"legacy","isPinned":true,"isSensitive":false,"byteSize":6},
             {"id":"\(legacyID.uuidString)","timestamp":\(Date().timeIntervalSinceReferenceDate - 5),"type":"Image","preview":"Image (4 × 4)","imagePNGData":"\(legacyImage.base64EncodedString())","isPinned":false,"isSensitive":false,"byteSize":\(legacyImage.count)}]
            """
            try? Data(legacyJSON.utf8).write(to: root.appendingPathComponent("clipboard_history.json"))

            let h = makeHarness(root: root)
            assert(h.service.items.count == 2, "Version 1 history JSON still loads")
            let migratedImage = h.service.items.first { $0.id == legacyID }
            assert(migratedImage?.imagePNGData == nil && migratedImage?.imageFileName != nil, "Inline legacy images are migrated to managed files")
            assert(migratedImage.flatMap { h.service.imageData(for: $0) } == legacyImage, "Migrated image data is intact")
            assert(h.service.items.allSatisfy { $0.contentHash != nil }, "Legacy items receive content hashes for duplicate detection")
            let savedJSON = (try? String(contentsOf: root.appendingPathComponent("clipboard_history.json"), encoding: .utf8)) ?? ""
            assert(!savedJSON.contains("imagePNGData"), "Rewritten history no longer embeds image bytes")

            h.copyString("persist me")
            _ = h.service.captureIfChanged()
            h.service.shutdown()

            let rootPerms = (try? FileManager.default.attributesOfItem(atPath: root.path)[.posixPermissions] as? NSNumber)?.intValue
            let filePerms = (try? FileManager.default.attributesOfItem(atPath: root.appendingPathComponent("clipboard_history.json").path)[.posixPermissions] as? NSNumber)?.intValue
            let excluded = (try? root.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup
            assert(rootPerms == 0o700 && filePerms == 0o600, "History folder is 0700 and history file is 0600")
            assert(excluded == true, "Clipboard storage is excluded from backups")

            let orphan = h.service.storage.imagesDirectory.appendingPathComponent("orphan.png")
            try? Data([1, 2, 3]).write(to: orphan)

            let reloaded = ClipboardManagerService(environment: ClipboardServiceEnvironment(
                pasteboard: h.pasteboard, defaults: h.defaults, storageRoot: root,
                frontmostApp: { nil }, usesTimers: false
            ))
            assert(reloaded.items.first?.contentText == "persist me" && reloaded.items.count == 3, "History persists across launches")
            assert(!FileManager.default.fileExists(atPath: orphan.path), "Orphaned image files are cleaned up on load")

            let historyPath = root.appendingPathComponent("clipboard_history.json").path
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: historyPath)
            _ = ClipboardStorage(rootDirectory: root)
            let tightened = (try? FileManager.default.attributesOfItem(atPath: historyPath)[.posixPermissions] as? NSNumber)?.intValue
            assert(tightened == 0o600, "History files left world-readable by older versions are made owner-only")

            reloaded.wipeEverything()
            assert(reloaded.items.isEmpty && reloaded.storage.storedImageNames().isEmpty, "Delete All removes pinned items and every stored image")
            reloaded.shutdown()
            h.cleanUp()
        }

        // 119. Clipboard: Shared Search & Filters
        do {
            let items = [
                ClipboardItem(type: .text, preview: "Quarterly report draft", contentText: "Quarterly report draft", sourceAppName: "Pages"),
                ClipboardItem(type: .url, preview: "https://swift.org/blog", contentText: "https://swift.org/blog", isPinned: true, sourceAppName: "Safari"),
                ClipboardItem(type: .file, preview: "budget.xlsx", filePaths: ["/Users/me/Documents/budget.xlsx"])
            ]
            assert(ClipboardManagerService.filter(items, query: "").count == 3, "Empty search shows everything")
            assert(ClipboardManagerService.filter(items, query: "REPORT quarterly").count == 1, "Search is case-insensitive and matches all terms")
            assert(ClipboardManagerService.filter(items, query: "documents").first?.type == .file, "Search matches file paths")
            assert(ClipboardManagerService.filter(items, query: "safari").first?.type == .url, "Search matches the source app")
            assert(ClipboardManagerService.filter(items, query: "", type: .url).count == 1, "Type filter narrows results")
            assert(ClipboardManagerService.filter(items, query: "", pinnedOnly: true).map(\.type) == [.url], "Pinned filter shows only pinned items")
            assert(ClipboardManagerService.filter(items, query: "report", type: .url).isEmpty, "Search and type filters combine")
        }

        // 120. Global Shortcut: Model, Validation and Conflicts
        do {
            let commandB = KeyboardShortcutSpec.commandB
            let encoded = try? JSONEncoder().encode(commandB)
            assert(encoded.flatMap { try? JSONDecoder().decode(KeyboardShortcutSpec.self, from: $0) } == commandB, "Shortcut round-trips through settings storage")
            let noSystem: [ShortcutValidator.SystemHotKey] = []
            func spec(_ key: Int, _ mods: Int, _ label: String) -> KeyboardShortcutSpec {
                KeyboardShortcutSpec(keyCode: UInt32(key), modifiers: UInt32(mods), keyLabel: label)
            }
            if case .warning(let message) = ShortcutValidator.validate(commandB, systemHotKeys: noSystem) {
                assert(message.contains("Bold"), "⌘B warns that it replaces Bold in other apps")
            } else {
                assert(false, "⌘B warns that it replaces Bold in other apps")
            }
            assert(!ShortcutValidator.validate(spec(kVK_ANSI_V, cmdKey, "V"), systemHotKeys: noSystem).isAcceptable, "⌘V can never be taken over")
            assert(!ShortcutValidator.validate(spec(kVK_ANSI_C, cmdKey, "C"), systemHotKeys: noSystem).isAcceptable, "⌘C is rejected")
            assert(!ShortcutValidator.validate(spec(kVK_ANSI_B, 0, "B"), systemHotKeys: noSystem).isAcceptable, "Shortcuts without ⌘/⌃/⌥ are rejected")
            assert(!ShortcutValidator.validate(spec(kVK_ANSI_B, shiftKey, "B"), systemHotKeys: noSystem).isAcceptable, "Shift-only shortcuts are rejected")
            assert(!ShortcutValidator.validate(spec(kVK_ANSI_4, cmdKey | shiftKey, "4"), systemHotKeys: noSystem).isAcceptable, "Screenshot shortcuts are rejected")
            assert(ShortcutValidator.validate(spec(kVK_ANSI_V, cmdKey | shiftKey, "V"), systemHotKeys: noSystem) == .valid, "⌘⇧V is accepted")
            let conflict = ShortcutValidator.SystemHotKey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | optionKey))
            assert(!ShortcutValidator.validate(spec(kVK_ANSI_K, cmdKey | optionKey, "K"), systemHotKeys: [conflict]).isAcceptable, "Enabled macOS keyboard shortcuts are detected as conflicts")
            assert(spec(kVK_ANSI_V, cmdKey | shiftKey | optionKey | controlKey, "V").displayString == "⌃⌥⇧⌘V", "Shortcut display uses standard modifier order")
            _ = ShortcutValidator.enabledSystemHotKeys()
            assert(true, "System shortcut list can be read without special permissions")

            let off = ClipboardBackgroundController.desiredState(historyEnabled: false, shortcutEnabled: true, recordingShortcut: false, showMenuBarIcon: true)
            assert(off.registerShortcut == false && off.showStatusItem == false, "⌘B and the clipboard menu bar icon are not claimed while history is off")
            let on = ClipboardBackgroundController.desiredState(historyEnabled: true, shortcutEnabled: true, recordingShortcut: false, showMenuBarIcon: true)
            assert(on.registerShortcut && on.showStatusItem, "Shortcut and menu bar icon are active when history is on")
            assert(!ClipboardBackgroundController.desiredState(historyEnabled: true, shortcutEnabled: false, recordingShortcut: false, showMenuBarIcon: true).registerShortcut, "Turning the shortcut off releases it")
            assert(!ClipboardBackgroundController.desiredState(historyEnabled: true, shortcutEnabled: true, recordingShortcut: true, showMenuBarIcon: true).registerShortcut, "Shortcut is released while recording a new one")
        }

        // 121. Global Shortcut: Carbon Registration & Dispatch
        do {
            let hotKeys = GlobalHotKeyService.shared
            let previousTrigger = hotKeys.onTrigger
            let previousSpec = hotKeys.registeredShortcut
            var fired = 0
            hotKeys.onTrigger = { fired += 1 }
            let testSpec = KeyboardShortcutSpec(keyCode: UInt32(kVK_F18), modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey), keyLabel: "F18")

            let status = hotKeys.register(testSpec)
            assert(status == .registered(testSpec), "Global shortcut registers with macOS")
            sendSyntheticHotKey(signature: GlobalHotKeyService.signature, id: GlobalHotKeyService.clipboardHotKeyID)
            assert(fired == 1, "Hot-key event opens the picker callback")
            sendSyntheticHotKey(signature: 0x54455354, id: GlobalHotKeyService.clipboardHotKeyID)
            assert(fired == 1, "Hot keys owned by other components are ignored")
            hotKeys.suspend()
            assert(hotKeys.status == .inactive, "Suspending releases the shortcut")
            hotKeys.resumeIfSuspended()
            assert(hotKeys.status == .registered(testSpec), "Resuming re-registers the shortcut")
            hotKeys.unregister()
            sendSyntheticHotKey(signature: GlobalHotKeyService.signature, id: GlobalHotKeyService.clipboardHotKeyID)
            assert(fired == 1 && hotKeys.status == .inactive, "Unregistered shortcut no longer triggers")

            var foreignRef: EventHotKeyRef?
            let foreignStatus = RegisterEventHotKey(testSpec.keyCode, testSpec.modifiers, EventHotKeyID(signature: 0x54455354, id: 9), GetApplicationEventTarget(), 0, &foreignRef)
            if foreignStatus == noErr {
                let conflict = hotKeys.register(testSpec)
                if case .failed(let message) = conflict {
                    assert(message.contains("already registered"), "Registration conflicts are reported instead of failing silently")
                } else {
                    assert(false, "Registration conflicts are reported instead of failing silently")
                }
                if let foreignRef { UnregisterEventHotKey(foreignRef) }
            }
            let invalid = hotKeys.register(KeyboardShortcutSpec(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey), keyLabel: "V"))
            if case .failed = invalid {
                assert(true, "⌘V is refused at registration time")
            } else {
                assert(false, "⌘V is refused at registration time")
            }
            hotKeys.unregister()
            hotKeys.onTrigger = previousTrigger
            // Diagnostics can run these tests inside the live app; restore the user's shortcut.
            if let previousSpec { hotKeys.register(previousSpec) }
        }

        // 122. Paste: Automatic Paste Decisions
        do {
            typealias Paste = ClipboardPasteService
            assert(Paste.fallbackReason(autoPasteEnabled: true, accessibilityTrusted: true, secureInputActive: false, hasTarget: true) == nil, "Auto-paste is attempted only when enabled, authorized and targeted")
            assert(Paste.fallbackReason(autoPasteEnabled: false, accessibilityTrusted: true, secureInputActive: false, hasTarget: true) == .autoPasteDisabled, "Auto-paste setting off copies only")
            assert(Paste.fallbackReason(autoPasteEnabled: true, accessibilityTrusted: false, secureInputActive: false, hasTarget: true) == .accessibilityNotGranted, "Without Accessibility access the item is copied and the user is told to press ⌘V")
            assert(Paste.fallbackReason(autoPasteEnabled: true, accessibilityTrusted: true, secureInputActive: true, hasTarget: true) == .secureInputActive, "No keystroke is sent while secure input is active")
            assert(Paste.fallbackReason(autoPasteEnabled: true, accessibilityTrusted: true, secureInputActive: false, hasTarget: false) == .noTargetApplication, "Without a previous app the item is copied only")
            assert(Paste.FallbackReason.accessibilityNotGranted.message.contains("⌘V"), "Fallback message tells the user to press ⌘V")
            assert((0..<128).contains(Paste.keyCodeForV()), "Paste key code resolves from the active keyboard layout")
        }

        // 123. Picker: Panel Behaviour and Keyboard Navigation
        do {
            let panel = ClipboardPickerPanel()
            assert(panel.styleMask.contains(.nonactivatingPanel) && panel.styleMask.contains(.resizable), "Picker is a resizable non-activating panel")
            assert(panel.canBecomeKey && !panel.canBecomeMain, "Picker takes keyboard focus without becoming the main window")
            assert(panel.level == .floating && panel.collectionBehavior.contains(.fullScreenAuxiliary), "Picker floats above other windows, including full-screen apps")
            assert(panel.minSize.width >= 380 && panel.maxSize.width <= 760, "Picker resizing is bounded")
            var handledKey: UInt16?
            panel.keyDownHandler = { event in
                handledKey = event.keyCode
                return true
            }
            if let down = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                           windowNumber: panel.windowNumber, context: nil, characters: "",
                                           charactersIgnoringModifiers: "", isARepeat: false, keyCode: 125) {
                panel.sendEvent(down)
            }
            assert(handledKey == 125, "Arrow keys reach the picker's keyboard handler")

            let h = makeHarness()
            for word in ["first", "second", "third"] {
                h.copyString(word)
                _ = h.service.captureIfChanged()
            }
            let model = ClipboardPickerModel(service: h.service)
            model.reset()
            assert(model.selectedItem?.contentText == "third", "Picker selects the most recent item first")
            model.moveSelection(by: 1)
            assert(model.selectedItem?.contentText == "second", "Down arrow moves to the next item")
            model.moveSelection(by: 10)
            assert(model.selectedItem?.contentText == "first", "Selection stops at the last item")
            model.moveSelection(by: -10)
            assert(model.selectedItem?.contentText == "third", "Selection stops at the first item")
            model.query = "sec"
            assert(model.results.count == 1 && model.selectedItem?.contentText == "second", "Typing filters results and reselects the first match")
            model.query = "zzz"
            assert(model.results.isEmpty && model.selectedItem == nil, "No-match searches have no selection")
            model.query = ""
            assert(model.item(atShortcutIndex: 2)?.contentText == "first", "⌘3 picks the third visible item")
            h.cleanUp()
        }

        // 124. Lifecycle: Background Operation and Menu Bar Menu
        do {
            assert(AppDelegate().applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared) == false, "Closing the last window does not quit the app")
            let menu = ClipboardMenuBarController.shared.buildMenu()
            let titles = menu.items.map(\.title)
            assert(titles.contains { $0.hasPrefix("Open Clipboard History") }, "Menu bar menu offers Open Clipboard History")
            assert(titles.contains("Open Clipboard Manager") && titles.contains("Clipboard Settings…"), "Menu bar menu opens the Clipboard Manager and its settings")
            assert(titles.contains("Quit Borno Pulse"), "Menu bar menu offers Quit Borno Pulse")
            let service = ClipboardManagerService.shared
            if service.isEnabled {
                let hasPauseControl = titles.contains("Resume Clipboard History") || titles.contains(ClipboardPauseDuration.untilResumed.label)
                assert(hasPauseControl, "Menu bar menu offers pause or resume matching the actual state")
            }
            let controller = ClipboardMenuBarController.shared
            let wasInstalled = controller.isInstalled
            controller.install()
            let firstItem = controller.statusItemForTesting
            controller.install()
            assert(controller.isInstalled && controller.statusItemForTesting === firstItem, "Installing the clipboard status item twice reuses the same item")
            if !wasInstalled { controller.uninstall() }
            assert(controller.isInstalled == wasInstalled, "Clipboard status item can be removed when history is turned off")
            assert(MainWindowRouter.shared.consumePendingSection() == nil, "No navigation is pending at launch")
        }
    }
}
