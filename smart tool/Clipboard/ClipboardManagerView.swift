//
//  ClipboardManagerView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct ClipboardManagerView: View {
    @ObservedObject var clipboard = ClipboardManagerService.shared
    
    @State private var searchText: String = ""
    @State private var selectedType: ClipboardContentType? = nil
    @State private var showPinnedOnly: Bool = false
    @State private var showingSettingsSheet: Bool = false
    @State private var copiedItemID: UUID? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 14) {
            // Master Opt-In Status Banner
            if !clipboard.isEnabled {
                optInBanner
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
        .background(AppTheme.graphiteCanvas)
        .sheet(isPresented: $showingSettingsSheet) {
            clipboardSettingsSheet
        }
    }
    
    // MARK: - Opt-In Banner
    private var optInBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.electricCyan)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Clipboard History is Disabled by Default")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("For maximum user privacy, clipboard tracking is 100% local and only runs when explicitly activated.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
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
    
    // MARK: - Clipboard Row
    private func clipboardRowView(_ item: ClipboardItem) -> some View {
        HStack(spacing: 12) {
            // Type Icon
            Image(systemName: item.type.icon)
                .font(.system(size: 14))
                .foregroundStyle(item.isPinned ? AppTheme.warningAmber : AppTheme.electricBlue)
                .frame(width: 28, height: 28)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            
            // Content Preview & Meta
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.preview)
                        .font(.system(size: 12, weight: .medium, design: item.type == .text ? .monospaced : .default))
                        .foregroundStyle(AppTheme.textPrimary)
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
                    
                    Text("• \(item.timestamp.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                    
                    Text("• \(Formatters.bytes(UInt64(item.byteSize)))")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
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
                .help("Pin to keep forever")
                .accessibilityLabel(item.isPinned ? "Unpin item" : "Pin item")
                
                // Copy Back Button
                Button {
                    clipboard.copyToPasteboard(item)
                    copiedItemID = item.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedItemID == item.id { copiedItemID = nil }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copiedItemID == item.id ? "checkmark" : "doc.on.doc")
                        Text(copiedItemID == item.id ? "Copied" : "Copy")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(copiedItemID == item.id ? AppTheme.successGreen : AppTheme.electricCyan)
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
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.textTertiary)
            Text(clipboard.isEnabled ? "No clipboard entries match your filter." : "Clipboard monitoring is currently inactive.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
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
                Spacer()
                Button("Done") {
                    showingSettingsSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        .padding(16)
        .background(AppTheme.toolbarBackground)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Filter Sensitive Secrets & Credit Cards", isOn: $clipboard.filterSensitive)
                        .font(.system(size: 12, weight: .medium))
                    
                    Picker("Maximum Stored Entries", selection: $clipboard.maxItemsCount) {
                        Text("50 Items").tag(50)
                        Text("100 Items").tag(100)
                        Text("200 Items").tag(200)
                        Text("500 Items").tag(500)
                    }
                    .pickerStyle(.menu)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Excluded Applications (Password Managers & Vaults)")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Items copied from these apps will be completely ignored:")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        ForEach(Array(clipboard.excludedBundleIDs).sorted(), id: \.self) { b in
                            Text("• \(b)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    
                    Divider()
                    
                    Button("Erase All History Permanently", role: .destructive) {
                        clipboard.wipeEverything()
                        showingSettingsSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.dangerFill)
                }
                .padding(18)
            }
        }
        .frame(width: 480, height: 420)
    }
    
    // MARK: - Filtered Items
    private var filteredItems: [ClipboardItem] {
        var list = clipboard.items
        
        if showPinnedOnly {
            list = list.filter { $0.isPinned }
        }
        
        if let type = selectedType {
            list = list.filter { $0.type == type }
        }
        
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.preview.lowercased().contains(q) ||
                ($0.contentText?.lowercased().contains(q) ?? false)
            }
        }
        
        return list
    }
    
    // MARK: - Header Controls Subviews
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
            
            TextField("Search clipboard text or filename...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .themedInputField()
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
    }
    
    private var actionButtonsGroup: some View {
        HStack(spacing: 8) {
            if clipboard.isEnabled {
                Button {
                    if clipboard.isPaused {
                        clipboard.resume()
                    } else {
                        clipboard.pause()
                    }
                } label: {
                    Label(clipboard.isPaused ? "Resume" : "Pause", systemImage: clipboard.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)
            }
            
            Button("Clear Unpinned") {
                clipboard.clearAll()
            }
            .buttonStyle(.bordered)
            
            Button {
                showingSettingsSheet = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
        }
    }
}
