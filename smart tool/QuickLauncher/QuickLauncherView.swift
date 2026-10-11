//
//  QuickLauncherView.swift
//  Borno Pulse
//

import SwiftUI

public struct QuickLauncherView: View {
    @State private var searchQuery: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    
    public let onSelect: (NavigationSection) -> Void
    public let onDismiss: () -> Void
    
    public init(
        onSelect: @escaping (NavigationSection) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        let results = QuickLauncherService.shared.search(query: searchQuery)
        
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.electricCyan)
                
                TextField("Search tools, screens, diagnostics (e.g. 'json', 'ping', 'cpu')...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .focused($isSearchFocused)
                    .onSubmit {
                        if results.indices.contains(selectedIndex) {
                            onSelect(results[selectedIndex].section)
                        }
                    }
                    .onKeyPress(.downArrow) {
                        guard !results.isEmpty else { return .ignored }
                        selectedIndex = min(selectedIndex + 1, results.count - 1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        guard !results.isEmpty else { return .ignored }
                        selectedIndex = max(selectedIndex - 1, 0)
                        return .handled
                    }
                    .accessibilityLabel("Quick Launcher search")
                    .accessibilityHint("Use the up and down arrow keys to choose a result, then press Return to open it.")
                
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                
                Button("Esc") {
                    onDismiss()
                }
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.cardBorder, lineWidth: 0.5))
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(AppTheme.insetBackground)
            
            Divider()
            
            // Search Results List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { idx, item in
                            resultRow(item, isSelected: idx == selectedIndex)
                                .id(item.id)
                                .onHover { hovering in
                                    if hovering { selectedIndex = idx }
                                }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 380)
                .onChange(of: selectedIndex) { _, newIndex in
                    if results.indices.contains(newIndex) {
                        proxy.scrollTo(results[newIndex].id)
                    }
                }
            }
        }
        .frame(width: 580)
        .background(AppTheme.elevatedCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorderHover, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
        .onChange(of: searchQuery) { _, _ in
            selectedIndex = 0
        }
        .onExitCommand {
            onDismiss()
        }
        .onAppear {
            isSearchFocused = true
        }
    }
    
    private func resultRow(_ item: QuickLauncherItem, isSelected: Bool) -> some View {
        Button {
            onSelect(item.section)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(categoryColor(for: item.category))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(item.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(item.category)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.subtleFill)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 0.5))
                
                Image(systemName: "return")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.selectionBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? AppTheme.electricBlue.opacity(0.45) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private func categoryColor(for cat: String) -> Color {
        switch cat {
        case "Hardware": return AppTheme.electricBlue
        case "Utilities": return AppTheme.matrixGreen
        case "Developer": return AppTheme.purpleAccent
        case "Network": return AppTheme.electricCyan
        case "Productivity": return AppTheme.warningAmber
        case "Security": return AppTheme.dangerRed
        default: return AppTheme.textSecondary
        }
    }
}
