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
                    .focused($isSearchFocused)
                
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
            .background(AppTheme.cardBackgroundSecondary)
            
            Divider()
                .background(AppTheme.cardBorder)
            
            // Search Results List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { idx, item in
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
                                    .background(AppTheme.cardBackgroundSecondary)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 0.5))
                                
                                Image(systemName: "return")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(idx == selectedIndex ? AppTheme.electricBlue.opacity(0.18) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 380)
        }
        .frame(width: 580)
        .background(AppTheme.graphiteCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorderHover, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
        .onAppear {
            isSearchFocused = true
        }
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
