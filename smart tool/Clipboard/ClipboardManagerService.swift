//
//  ClipboardManagerService.swift
//  Borno Pulse
//

import AppKit
import Combine
import Foundation

@MainActor
public final class ClipboardManagerService: ObservableObject {
    public static let shared = ClipboardManagerService()
    
    // Published State
    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "Clipboard_IsEnabled")
            if isEnabled { startMonitoring() } else { stopMonitoring() }
        }
    }
    
    @Published public var isPaused: Bool {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: "Clipboard_IsPaused")
        }
    }
    
    @Published public var items: [ClipboardItem] = []
    @Published public var excludedBundleIDs: Set<String> {
        didSet {
            if let d = try? JSONEncoder().encode(Array(excludedBundleIDs)) {
                UserDefaults.standard.set(d, forKey: "Clipboard_ExcludedBundles")
            }
        }
    }
    
    @Published public var filterSensitive: Bool {
        didSet {
            UserDefaults.standard.set(filterSensitive, forKey: "Clipboard_FilterSensitive")
        }
    }
    
    @Published public var maxItemsCount: Int {
        didSet {
            UserDefaults.standard.set(maxItemsCount, forKey: "Clipboard_MaxItems")
            trimItems()
        }
    }
    
    // Internal Engine
    private var pollTimer: AnyCancellable?
    private var lastChangeCount: Int = 0
    
    private var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NaemSmartTool/Clipboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipboard_history.json")
    }
    
    private init() {
        let savedEnabled = UserDefaults.standard.bool(forKey: "Clipboard_IsEnabled")
        let savedPaused = UserDefaults.standard.bool(forKey: "Clipboard_IsPaused")
        let savedSensitive = UserDefaults.standard.object(forKey: "Clipboard_FilterSensitive") as? Bool ?? true
        let savedMax = UserDefaults.standard.integer(forKey: "Clipboard_MaxItems")
        
        self.isEnabled = savedEnabled
        self.isPaused = savedPaused
        self.filterSensitive = savedSensitive
        self.maxItemsCount = savedMax > 0 ? savedMax : 100
        
        if let data = UserDefaults.standard.data(forKey: "Clipboard_ExcludedBundles"),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            self.excludedBundleIDs = Set(arr)
        } else {
            // Default excluded password managers
            self.excludedBundleIDs = [
                "com.agilebits.onepassword7",
                "com.1password.1password",
                "com.bitwarden.desktop",
                "com.apple.keychainaccess"
            ]
        }
        
        loadHistory()
        lastChangeCount = NSPasteboard.general.changeCount
        
        if isEnabled {
            startMonitoring()
        }
    }
    
    // MARK: - Monitoring Controls
    public func startMonitoring() {
        guard pollTimer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        pollTimer = Timer.publish(every: 0.8, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollPasteboard()
            }
    }
    
    public func stopMonitoring() {
        pollTimer?.cancel()
        pollTimer = nil
        saveHistory()
    }
    
    public func pause() {
        isPaused = true
    }
    
    public func resume() {
        isPaused = false
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    // MARK: - Poll Pasteboard
    private func pollPasteboard() {
        guard isEnabled, !isPaused else { return }
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        // Check active app exclusion
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontApp.bundleIdentifier,
           excludedBundleIDs.contains(bundleID) {
            return
        }
        
        let sourceName = NSWorkspace.shared.frontmostApplication?.localizedName
        let pb = NSPasteboard.general
        
        // 1. Check for file URLs
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            let paths = urls.map { $0.path }
            let preview = urls.map { $0.lastPathComponent }.joined(separator: ", ")
            addItem(ClipboardItem(
                type: .file,
                preview: preview,
                filePaths: paths,
                byteSize: Int64(paths.count * 100),
                sourceAppName: sourceName
            ))
            return
        }
        
        // 2. Check for plain or rich text / URL
        if let string = pb.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check sensitive heuristics
            let isSensitive = checkSensitive(text: trimmed)
            if isSensitive && filterSensitive {
                return // Skip capturing sensitive secrets
            }
            
            let isURL = (URL(string: trimmed)?.scheme != nil) && (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"))
            let type: ClipboardContentType = isURL ? .url : .text
            let preview = trimmed.prefix(120).replacingOccurrences(of: "\n", with: " ")
            
            addItem(ClipboardItem(
                type: type,
                preview: String(preview),
                contentText: trimmed,
                isSensitive: isSensitive,
                byteSize: Int64(string.utf8.count),
                sourceAppName: sourceName
            ))
            return
        }
        
        // 3. Check for images (PNG / TIFF)
        if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            addItem(ClipboardItem(
                type: .image,
                preview: "Image (\(Int(image.size.width)) × \(Int(image.size.height)))",
                imagePNGData: png,
                byteSize: Int64(png.count),
                sourceAppName: sourceName
            ))
            return
        }
    }
    
    private func addItem(_ item: ClipboardItem) {
        // Prevent duplicate consecutive entries
        if let first = items.first, first.type == item.type {
            if let t1 = first.contentText, let t2 = item.contentText, t1 == t2 { return }
        }
        
        items.insert(item, at: 0)
        trimItems()
        saveHistory()
    }
    
    private func trimItems() {
        if items.count > maxItemsCount {
            // Keep pinned items
            let unpinned = items.filter { !$0.isPinned }
            let pinned = items.filter { $0.isPinned }
            let excess = items.count - maxItemsCount
            let trimmedUnpinned = unpinned.dropLast(excess)
            items = (pinned + trimmedUnpinned).sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    // MARK: - Actions
    public func copyToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        
        switch item.type {
        case .text, .url, .richText:
            if let text = item.contentText {
                pb.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imagePNGData, let img = NSImage(data: data) {
                pb.writeObjects([img])
            }
        case .file:
            if let paths = item.filePaths {
                let urls = paths.map { URL(fileURLWithPath: $0) as NSURL }
                pb.writeObjects(urls)
            }
        }
        
        lastChangeCount = pb.changeCount
    }
    
    public func togglePin(_ itemID: UUID) {
        if let idx = items.firstIndex(where: { $0.id == itemID }) {
            items[idx].isPinned.toggle()
            saveHistory()
        }
    }
    
    public func deleteItem(_ itemID: UUID) {
        items.removeAll { $0.id == itemID }
        saveHistory()
    }
    
    public func clearAll() {
        items.removeAll { !$0.isPinned } // preserves pinned items
        saveHistory()
    }
    
    public func wipeEverything() {
        items.removeAll()
        saveHistory()
    }
    
    // MARK: - Sensitive Content Heuristics
    public func checkSensitive(text: String) -> Bool {
        let lower = text.lowercased()
        
        // Common secret tokens prefixes
        if text.hasPrefix("ghp_") || text.hasPrefix("sk_live_") || text.hasPrefix("Bearer ") ||
           text.hasPrefix("AKIA") || lower.contains("private_key") || lower.contains("password=") {
            return true
        }
        
        // 16-digit credit card pattern
        let digitsOnly = text.filter { $0.isNumber }
        if (13...19).contains(digitsOnly.count) && (text.contains("-") || text.contains(" ")) && text.allSatisfy({ $0.isNumber || $0 == "-" || $0 == " " }) {
            return true
        }
        
        return false
    }
    
    // MARK: - Persistence
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed saving clipboard history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyFileURL)
            let loaded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            self.items = loaded
        } catch {
            print("Failed loading clipboard history: \(error)")
        }
    }
}
