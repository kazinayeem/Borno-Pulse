//
//  ClipboardManagerView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct ClipboardManagerView: View {
    @ObservedObject var clipboard = ClipboardManagerService.shared
    @ObservedObject var hotKeys = GlobalHotKeyService.shared
    
    @State private var searchText: String = ""
    @State private var selectedType: ClipboardContentType? = nil
    @State private var showPinnedOnly: Bool = false
    @State private var showingSettingsSheet: Bool = false
    @State private var copiedItemID: UUID? = nil
    @State private var failedItemID: UUID? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 14) {
            // Master Opt-In Status Banner
            if !clipboard.isEnabled {
                optInBanner
            } else {
                statusBar
            }
            
            // Header Controls Bar
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    searchBar
                    typePicker
                    pinnedFilterButton
                    Spacer()
                    actionButtonsGroup
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        searchBar
                        typePicker
                        pinnedFilterButton
                    }
                    
                    HStack(spacing: 10) {
                        actionButtonsGroup
                        Spacer()
                    }
                }
            }
            
            // Clipboard List View
            let filtered = filteredItems
            if filtered.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { item in
                            clipboardRowView(item)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.graphiteCanvas)
        .sheet(isPresented: $showingSettingsSheet) {
            clipboardSettingsSheet
        }
    }
    
    // MARK: - Opt-In Banner
    private var optInBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.electricCyan)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Clipboard History is Disabled by Default")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("For maximum user privacy, clipboard tracking is 100% local and only runs when explicitly activated. Once on, it keeps running after you close this window, and \(clipboard.shortcut.displayString) opens your history from any app.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button("Enable Clipboard History") {
                clipboard.isEnabled = true
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.successFill)
        }
        .padding(12)
        .smartCard()
    }

    // MARK: - Status Bar
    private var statusBar: some View {
        HStack(spacing: 10) {
            MonitoringStatusBadge(state: clipboard.monitoringState)
            Text(statusDetail)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
            Spacer()
            Button {
                ClipboardPickerController.shared.show()
            } label: {
                Label("Open History", systemImage: "list.clipboard")
            }
            .buttonStyle(.bordered)
            .help("Open the quick clipboard picker")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .smartCard()
    }

    private var statusDetail: String {
        var parts: [String] = []
        switch clipboard.monitoringState {
        case .monitoring:
            parts.append("New copies are recorded locally, even when this window is closed.")
        case .paused(let until):
            if let until {
                parts.append("Paused until \(until.formatted(date: .omitted, time: .shortened)). Copies made now aren't recorded.")
            } else {
                parts.append("Paused. Copies made now aren't recorded.")
            }
        case .off:
            break
        }
        switch hotKeys.status {
        case .registered(let spec):
            parts.append("Press \(spec.displayString) in any app to paste from history.")
        case .failed(let message):
            parts.append(message)
        case .inactive:
            break
        }
        return parts.joined(separator: " ")
    }
    
    // MARK: - Clipboard Row
    private func clipboardRowView(_ item: ClipboardItem) -> some View {
        let missingFiles = item.type == .file && !item.missingFilePaths.isEmpty
        return HStack(spacing: 12) {
            // Type Icon or Thumbnail
            ClipboardItemThumbnail(item: item, service: clipboard, size: 32)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(item.isPinned ? AppTheme.warningAmber.opacity(0.6) : AppTheme.cardBorder, lineWidth: 0.5))
            
            // Content Preview & Meta
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.preview)
                        .font(.system(size: 12, weight: .medium, design: item.type == .text ? .monospaced : .default))
                        .foregroundStyle(missingFiles ? AppTheme.textTertiary : AppTheme.textPrimary)
                        .lineLimit(2)
                    
                    if item.isSensitive {
                        Text("SECRET DETECTED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AppTheme.dangerRed)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppTheme.dangerRed.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                
                HStack(spacing: 8) {
                    Text(item.type.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    if let app = item.sourceAppName {
                        Text("from \(app)")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    Text("• \(item.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    Text("• \(Formatters.bytes(UInt64(max(0, item.byteSize))))")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)

                    if missingFiles {
                        Text("• Original file missing")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.warningAmber)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 6) {
                // Pin Button
                Button {
                    clipboard.togglePin(item.id)
                } label: {
                    Image(systemName: item.isPinned ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(item.isPinned ? AppTheme.warningAmber : AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "Unpin" : "Pin to keep until removed")
                .accessibilityLabel(item.isPinned ? "Unpin item" : "Pin item")
                
                // Copy Back Button
                Button {
                    restore(item)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copyButtonSymbol(for: item))
                        Text(copyButtonTitle(for: item))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(copyButtonColor(for: item))
                }
                .buttonStyle(.bordered)
                
                // Delete
                Button {
                    clipboard.deleteItem(item.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.dangerRed)
                }
                .buttonStyle(.plain)
                .help("Delete item")
                .accessibilityLabel("Delete item")
            }
        }
        .padding(10)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(item.isPinned ? AppTheme.warningAmber.opacity(0.5) : AppTheme.cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { restore(item) }
        .help("Click to copy back to the clipboard")
        .accessibilityAction(named: "Copy to clipboard") { restore(item) }
    }

    private func restore(_ item: ClipboardItem) {
        let restored = clipboard.copyToPasteboard(item)
        copiedItemID = restored ? item.id : nil
        failedItemID = restored ? nil : item.id
        let id = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedItemID == id { copiedItemID = nil }
            if failedItemID == id { failedItemID = nil }
        }
    }

    private func copyButtonTitle(for item: ClipboardItem) -> String {
        if copiedItemID == item.id { return "Copied" }
        if failedItemID == item.id { return "Unavailable" }
        return "Copy"
    }

    private func copyButtonSymbol(for item: ClipboardItem) -> String {
        if copiedItemID == item.id { return "checkmark" }
        if failedItemID == item.id { return "exclamationmark.triangle" }
        return "doc.on.doc"
    }

    private func copyButtonColor(for item: ClipboardItem) -> Color {
        if copiedItemID == item.id { return AppTheme.successGreen }
        if failedItemID == item.id { return AppTheme.warningAmber }
        return AppTheme.electricCyan
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        Group {
            if !clipboard.isEnabled && clipboard.items.isEmpty {
                ThemedEmptyState(
                    icon: "doc.on.clipboard",
                    title: "Clipboard History Is Off",
                    message: "Nothing is being recorded. Enable clipboard history above to start keeping copies on this Mac."
                )
            } else if clipboard.items.isEmpty {
                ThemedEmptyState(
                    icon: "tray",
                    title: "No Clipboard History Yet",
                    message: clipboard.isPaused
                        ? "Recording is paused. Resume to capture new copies."
                        : "Copy text, a link, an image or a file in any app and it will appear here."
                )
            } else {
                VStack(spacing: 10) {
                    ThemedEmptyState(
                        icon: "line.3.horizontal.decrease.circle",
                        title: "No Matching Items",
                        message: "\(clipboard.items.count) item\(clipboard.items.count == 1 ? "" : "s") in history, but none match the current search or filters."
                    )
                    Button("Clear Filters") {
                        searchText = ""
                        selectedType = nil
                        showPinnedOnly = false
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .smartCard()
    }
    
    // MARK: - Settings Sheet
    private var clipboardSettingsSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Clipboard Privacy & Settings")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Done") {
                    showingSettingsSheet = false
                }
                .buttonStyle(.themedPrimary)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(AppTheme.toolbarBackground)
            
            Divider()
            
            ScrollView {
                ClipboardSettingsView()
                    .padding(18)
            }
        }
        .frame(width: 620, height: 640)
        .background(AppTheme.background)
    }
    
    // MARK: - Filtered Items
    private var filteredItems: [ClipboardItem] {
        ClipboardManagerService.filter(
            clipboard.items,
            query: searchText,
            type: selectedType,
            pinnedOnly: showPinnedOnly
        )
    }
    
    // MARK: - Header Controls Subviews
    private var searchBar: some View {
        ThemedSearchField("Search text, links, file names or apps…", text: $searchText)
            .frame(maxWidth: 280)
    }
    
    private var typePicker: some View {
        Picker("Type", selection: $selectedType) {
            Text("All Types").tag(ClipboardContentType?.none)
            ForEach(ClipboardContentType.allCases) { t in
                Text(t.rawValue).tag(ClipboardContentType?.some(t))
            }
        }
        .pickerStyle(.menu)
        .frame(width: 130)
    }
    
    private var pinnedFilterButton: some View {
        Button {
            showPinnedOnly.toggle()
        } label: {
            Label("Pinned", systemImage: showPinnedOnly ? "star.fill" : "star")
                .foregroundStyle(showPinnedOnly ? AppTheme.warningAmber : AppTheme.textSecondary)
        }
        .buttonStyle(.bordered)
        .accessibilityAddTraits(showPinnedOnly ? .isSelected : [])
    }
    
    private var actionButtonsGroup: some View {
        HStack(spacing: 8) {
            if clipboard.isEnabled {
                if clipboard.isPaused {
                    Button {
                        clipboard.resume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Menu {
                        ForEach(ClipboardPauseDuration.allCases) { duration in
                            Button(duration.label) { clipboard.pause(for: duration) }
                        }
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    } primaryAction: {
                        clipboard.pause()
                    }
                    .menuStyle(.button)
                    .fixedSize()
                    .help("Pause recording. Use the arrow for a timed pause.")
                }
            }
            
            Button("Clear Unpinned") {
                clipboard.clearAll()
            }
            .buttonStyle(.bordered)
            .disabled(!clipboard.items.contains { !$0.isPinned })
            
            Button {
                showingSettingsSheet = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
            .help("Clipboard settings")
            .accessibilityLabel("Clipboard settings")
        }
    }
}
