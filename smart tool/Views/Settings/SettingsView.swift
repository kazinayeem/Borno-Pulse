//
//  SettingsView.swift
//  Borno Pulse
//
//  Complete native macOS Settings and Preferences experience:
//  - Fully scrollable from top to bottom without clipping behind the window header
//  - Comprehensive search field to discover and jump to any setting
//  - Full coverage of Appearance, Typography, Menu Bar, Widget Studio,
//    Monitoring, Alerts, Startup, Clipboard, PDF Studio, Privacy, Shortcuts,
//    Diagnostics, and Data Management & Resets.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Category Tabs
public enum SettingsSectionTab: String, CaseIterable, Identifiable {
    case appearanceTypography = "Appearance & Typography"
    case menuBarWidget = "Menu Bar & Widget"
    case general = "General & System"
    case clipboard = "Clipboard"
    case alerts = "Alerts & Exclusions"
    case pdfStudio = "PDF Studio & Files"
    case privacySecurity = "Privacy & Security"
    case shortcutsDiagnostics = "Shortcuts & Diagnostics"
    case backupReset = "Backup & Data Management"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .appearanceTypography: return "textformat.size"
        case .menuBarWidget: return "gauge.with.dots.needle.bottom.100percent"
        case .general: return "gearshape.fill"
        case .clipboard: return "doc.on.clipboard"
        case .alerts: return "bell.badge.fill"
        case .pdfStudio: return "doc.richtext.fill"
        case .privacySecurity: return "shield.lefthalf.filled"
        case .shortcutsDiagnostics: return "keyboard"
        case .backupReset: return "externaldrive.badge.timemachine"
        }
    }
}

// MARK: - Main Settings View
public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var alertService = WidgetAlertService.shared
    @ObservedObject var pdfService = PDFEditorService.shared
    @ObservedObject private var navigation = SettingsNavigation.shared

    @State private var selectedTab: SettingsSectionTab = .appearanceTypography
    @State private var searchQuery: String = ""
    @State private var newExclusionPath: String = ""
    @State private var testResults: (passed: Int, failed: Int, logs: [String])? = nil
    @State private var isRunningTests: Bool = false
    @State private var showResetAllConfirmation: Bool = false
    @State private var showWipeClipboardConfirmation: Bool = false
    @State private var showClearStorageHistoryConfirmation: Bool = false
    @State private var statusFeedbackMessage: String? = nil

    private let topAnchorID = "settings_scroll_top_anchor"

    public init() {}

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hidden anchor for programmatic scroll to top
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchorID)

                    // 1. Header with quick actions
                    headerBanner(proxy: proxy)

                    // 2. Search & Filter Bar
                    searchAndNavigationSection(proxy: proxy)

                    Divider().opacity(0.2)

                    // 3. Tab or Search Results Content
                    if isSearching {
                        searchResultsView(proxy: proxy)
                    } else {
                        activeTabContent(proxy: proxy)
                    }

                    // 4. Footer navigation
                    footerBar(proxy: proxy)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .background(AppTheme.background)
        .onAppear {
            applyRequestedTab()
            syncPDFDefaults()
        }
        .onChange(of: navigation.requestedTab) { _, _ in
            applyRequestedTab()
        }
        .confirmationDialog("Reset All Settings?", isPresented: $showResetAllConfirmation) {
            Button("Reset Everything to Defaults", role: .destructive) {
                settings.resetAllSettingsToDefaults()
                MenuBarWidgetPreferences.shared.resetToDefaults()
                statusFeedbackMessage = "All preferences have been restored to factory defaults."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore default appearance, typography, menu bar metrics, alert thresholds, and PDF defaults. System monitoring logs and clipboard history will remain safe.")
        }
        .confirmationDialog("Clear Storage Analytics History?", isPresented: $showClearStorageHistoryConfirmation) {
            Button("Clear Storage History", role: .destructive) {
                HistoricalStorageService.shared.clearHistory()
                statusFeedbackMessage = "Storage analytics historical log has been cleared."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes all recorded disk space history snapshots. Current live disk telemetry is unaffected.")
        }
    }

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func applyRequestedTab() {
        guard let tab = navigation.requestedTab else { return }
        selectedTab = tab
        searchQuery = ""
        navigation.requestedTab = nil
    }

    private func syncPDFDefaults() {
        pdfService.textFontSize = settings.pdfDefaultFontSize
        pdfService.textFontName = settings.pdfDefaultFontName
        pdfService.strokeWidth = settings.pdfDefaultStrokeWidth
        pdfService.annotationOpacity = settings.pdfDefaultAnnotationOpacity
        pdfService.lockImageAspectRatio = settings.pdfLockImageAspectRatio
    }

    // MARK: - 1. Header Banner
    private func headerBanner(proxy: ScrollViewProxy) -> some View {
        AdaptivePageHeader(
            title: "Settings & Preferences",
            subtitle: "System appearance, custom typography, widget metrics, alerts, clipboard, and privacy",
            icon: "gearshape.fill",
            iconColor: AppTheme.electricBlue
        ) {
            HStack(spacing: 8) {
                if let msg = statusFeedbackMessage {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.successGreen)
                        Text(msg)
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.successGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .transition(.opacity)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(topAnchorID, anchor: .top)
                    }
                } label: {
                    Label("Scroll to Top", systemImage: "arrow.up")
                        .font(AppTypography.font(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Return to the top of Settings")

                Button {
                    showResetAllConfirmation = true
                } label: {
                    Label("Reset All…", systemImage: "arrow.counterclockwise")
                        .font(AppTypography.font(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Restore all settings to factory defaults")
            }
        }
    }

    // MARK: - 2. Search & Navigation Section
    private func searchAndNavigationSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search Input Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textTertiary)
                    .font(.system(size: 13))

                TextField("Search all settings (e.g. font, theme, cpu, temp, battery, menu bar, clipboard, pdf, shortcut)…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(AppTypography.font(size: 13))

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textTertiary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.cardBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(!searchQuery.isEmpty ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: !searchQuery.isEmpty ? 1.5 : 0.5)
            )

            // Category Tab Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SettingsSectionTab.allCases) { tab in
                        let isSelected = (selectedTab == tab && !isSearching)
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = tab
                                searchQuery = ""
                                proxy.scrollTo(topAnchorID, anchor: .top)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.rawValue)
                                    .font(AppTypography.font(size: 12, weight: isSelected ? .semibold : .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.selectableFill(isSelected))
                            .foregroundStyle(AppTheme.selectableForeground(isSelected))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(isSelected ? AppTheme.electricBlue : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 3. Active Tab Content
    @ViewBuilder
    private func activeTabContent(proxy: ScrollViewProxy) -> some View {
        switch selectedTab {
        case .appearanceTypography:
            appearanceTypographyContent
        case .menuBarWidget:
            MenuBarWidgetSettingsView()
        case .general:
            generalSettingsContent
        case .clipboard:
            ClipboardSettingsView()
        case .alerts:
            alertsSettingsContent
        case .pdfStudio:
            pdfStudioSettingsContent
        case .privacySecurity:
            privacySecuritySettingsContent
        case .shortcutsDiagnostics:
            shortcutsDiagnosticsContent
        case .backupReset:
            backupResetSettingsContent
        }
    }

    // MARK: - 4. Search Results Content
    private func searchResultsView(proxy: ScrollViewProxy) -> some View {
        let q = searchQuery.lowercased().trimmingCharacters(in: .whitespaces)
        
        let matchesAppearance = "appearance theme light dark system typography font font scale weight monospaced icon".contains(q)
        let matchesMenuBar = "menu bar widget status indicator metric category order volume refresh".contains(q)
        let matchesGeneral = "general system login launch interval temperature celsius fahrenheit sensors polling buffer".contains(q)
        let matchesClipboard = "clipboard history copy paste shortcut hotkey pause retention limit wipe images".contains(q)
        let matchesAlerts = "alert notification threshold cpu load memory pressure battery discharge disconnect cleaner exclusion".contains(q)
        let matchesPDF = "pdf studio annotation font stroke width opacity aspect ratio unsaved safe writer export".contains(q)
        let matchesPrivacy = "privacy security telemetry network local permission accessibility screen time disk tracking".contains(q)
        let matchesShortcuts = "shortcut keyboard command key hotkey diagnostics test suite unit tests verify".contains(q)
        let matchesBackup = "backup data management reset factory defaults storage history wipe clear".contains(q)

        let hasAnyMatch = matchesAppearance || matchesMenuBar || matchesGeneral || matchesClipboard || matchesAlerts || matchesPDF || matchesPrivacy || matchesShortcuts || matchesBackup

        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Search Results for “\(searchQuery)”")
                    .font(AppTypography.font(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Clear Search") {
                    searchQuery = ""
                }
                .font(AppTypography.font(size: 11))
                .buttonStyle(.borderless)
            }

            if !hasAnyMatch {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No settings found matching “\(searchQuery)”")
                        .font(AppTypography.font(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Try searching for: appearance, font, widget, cpu, temp, battery, clipboard, pdf, alerts, or shortcuts.")
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                    Button("View All Settings") {
                        searchQuery = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentFill)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .smartCard()
            } else {
                if matchesAppearance {
                    searchResultCard(tab: .appearanceTypography, title: "Appearance & Custom Typography", proxy: proxy) {
                        appearanceTypographyContent
                    }
                }
                if matchesMenuBar {
                    searchResultCard(tab: .menuBarWidget, title: "Menu Bar & Widget Studio", proxy: proxy) {
                        MenuBarWidgetSettingsView()
                    }
                }
                if matchesGeneral {
                    searchResultCard(tab: .general, title: "General, System & Monitoring Telemetry", proxy: proxy) {
                        generalSettingsContent
                    }
                }
                if matchesClipboard {
                    searchResultCard(tab: .clipboard, title: "Clipboard Manager & Global HotKey", proxy: proxy) {
                        ClipboardSettingsView()
                    }
                }
                if matchesAlerts {
                    searchResultCard(tab: .alerts, title: "Alerts, Thresholds & Cache Exclusions", proxy: proxy) {
                        alertsSettingsContent
                    }
                }
                if matchesPDF {
                    searchResultCard(tab: .pdfStudio, title: "PDF Studio & Document Tools", proxy: proxy) {
                        pdfStudioSettingsContent
                    }
                }
                if matchesPrivacy {
                    searchResultCard(tab: .privacySecurity, title: "Privacy, Local Permissions & Telemetry", proxy: proxy) {
                        privacySecuritySettingsContent
                    }
                }
                if matchesShortcuts {
                    searchResultCard(tab: .shortcutsDiagnostics, title: "Keyboard Shortcuts & System Diagnostics", proxy: proxy) {
                        shortcutsDiagnosticsContent
                    }
                }
                if matchesBackup {
                    searchResultCard(tab: .backupReset, title: "Backup, Data Management & Resets", proxy: proxy) {
                        backupResetSettingsContent
                    }
                }
            }
        }
    }

    private func searchResultCard<Content: View>(tab: SettingsSectionTab, title: String, proxy: ScrollViewProxy, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(title, systemImage: tab.icon)
                    .font(AppTypography.font(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.electricBlue)
                Spacer()
                Button {
                    withAnimation {
                        selectedTab = tab
                        searchQuery = ""
                        proxy.scrollTo(topAnchorID, anchor: .top)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Open \(tab.rawValue)")
                        Image(systemName: "arrow.right")
                    }
                    .font(AppTypography.font(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            content()
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Footer Bar
    private func footerBar(proxy: ScrollViewProxy) -> some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(topAnchorID, anchor: .top)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Back to Top")
                }
                .font(AppTypography.font(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, 12)
    }

    // MARK: - Tab Content: 1. Appearance & Typography
    private var appearanceTypographyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Appearance Mode Tile Selector
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Appearance Mode")
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Light Mode is default for new installations. Instant live switching between Light, Dark, and System macOS appearances.")
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                AdaptiveCardGrid(minColumnWidth: 160, spacing: 12) {
                    appearanceOptionTile(
                        title: "Light",
                        subtitle: "Crisp neutral white (Default)",
                        icon: "sun.max.fill",
                        mode: .light
                    )
                    appearanceOptionTile(
                        title: "Dark",
                        subtitle: "Deep graphite surfaces",
                        icon: "moon.fill",
                        mode: .dark
                    )
                    appearanceOptionTile(
                        title: "System",
                        subtitle: "Matches macOS appearance",
                        icon: "macbook.and.iphone",
                        mode: .system
                    )
                }
            }
            .smartCard()

            // 2. Primary Typography System
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Primary Font Family")
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Select application typography. If a font is unavailable on your system, Borno Pulse gracefully falls back to Apple SF Pro.")
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(spacing: 8) {
                    ForEach(AppFontFamily.allCases) { family in
                        let isSelected = settings.appFontFamily == family
                        let isAvailable = family.isAvailableOnSystem

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                settings.appFontFamily = family
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textTertiary)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(family.displayName)
                                            .font(AppTypography.font(size: 13, weight: isSelected ? .semibold : .medium))
                                            .foregroundStyle(AppTheme.textPrimary)

                                        if !isAvailable {
                                            Text("Fallback to SF Pro")
                                                .font(AppTypography.font(size: 10, weight: .medium))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(AppTheme.warningAmber.opacity(0.12))
                                                .foregroundStyle(AppTheme.warningAmber)
                                                .clipShape(Capsule())
                                        } else if family == .sfPro {
                                            Text("Default")
                                                .font(AppTypography.font(size: 10, weight: .medium))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(AppTheme.electricBlue.opacity(0.12))
                                                .foregroundStyle(AppTheme.electricBlue)
                                                .clipShape(Capsule())
                                        }
                                    }

                                    Text(fontFamilyDescription(for: family))
                                        .font(AppTypography.font(size: 11))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }

                                Spacer()

                                Text("Aa 123")
                                    .font(sampleFont(for: family, size: 14))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.cardBackgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                            .padding(10)
                            .background(isSelected ? AppTheme.electricBlue.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .smartCard()

            // 3. Font Size Scaling & Base Weight
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Font Size Scaling & Base Weight")
                            .font(AppTypography.font(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Scale text from 85% to 120% without clipping or layout distortion. Respects accessibility scaling.")
                            .font(AppTypography.font(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()

                    Text("\(Int(round(settings.fontScale * 100)))%")
                        .font(AppTypography.monospaced(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.electricBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.electricBlue.opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 12) {
                    Text("85%")
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)

                    Slider(value: $settings.fontScale, in: 0.85...1.20, step: 0.05)

                    Text("120%")
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                // 3 Primary Presets: Small, Normal, Large
                HStack(spacing: 8) {
                    ForEach(AppFontSizePreset.allCases) { preset in
                        let isSelected = settings.currentFontSizePreset == preset
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                settings.applyFontSizePreset(preset)
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(preset.title)
                                    .font(AppTypography.font(size: 11, weight: isSelected ? .bold : .medium))
                                Text(preset.description)
                                    .font(AppTypography.font(size: 9))
                                    .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textTertiary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .background(isSelected ? AppTheme.electricBlue.opacity(0.15) : AppTheme.cardBackgroundSecondary)
                            .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().opacity(0.2)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Base Typography Weight")
                        .font(AppTypography.font(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(AppFontWeight.allCases) { weight in
                            let isSelected = settings.baseFontWeight == weight
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    settings.baseFontWeight = weight
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    Text(weight.rawValue)
                                        .font(AppTypography.font(size: 12, weight: weight.fontWeight))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(isSelected ? AppTheme.electricBlue.opacity(0.15) : AppTheme.cardBackgroundSecondary)
                                .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .smartCard()

            // 4. Monospaced Font Selection
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Monospaced Font (Technical Telemetry & Developer Tools)")
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Applied to CPU metrics, memory allocations, disk bytes, network rates, and cryptographic hashes.")
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                HStack(spacing: 10) {
                    ForEach(AppMonospacedFontFamily.allCases) { mono in
                        let isSelected = settings.monospacedFontFamily == mono
                        let isAvailable = mono.isAvailableOnSystem

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                settings.monospacedFontFamily = mono
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(mono.rawValue)
                                        .font(AppTypography.font(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppTheme.electricBlue)
                                    }
                                }

                                Text("128.4 MB/s")
                                    .font(monoFontSample(for: mono, size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)

                                if !isAvailable {
                                    Text("Fallback Active")
                                        .font(AppTypography.font(size: 9))
                                        .foregroundStyle(AppTheme.warningAmber)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isSelected ? AppTheme.electricBlue.opacity(0.08) : AppTheme.cardBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .smartCard()

            // 5. Menu Bar Status Icon Symbol Selection
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Menu Bar Status Icon")
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Monochrome template-style symbol that automatically adapts to light and dark macOS menu bars.")
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(MenuBarIconSymbol.allCases) { symbol in
                        let isSelected = settings.menuBarIconSymbol == symbol

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                settings.menuBarIconSymbol = symbol
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: symbol.symbolName)
                                    .font(.system(size: 16))
                                    .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textPrimary)
                                    .frame(width: 24, height: 24)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(symbol.rawValue)
                                        .font(AppTypography.font(size: 11, weight: isSelected ? .semibold : .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    if symbol == .pulseWave {
                                        Text("Borno Motif")
                                            .font(AppTypography.font(size: 9, weight: .medium))
                                            .foregroundStyle(AppTheme.electricCyan)
                                    }
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.electricBlue)
                                }
                            }
                            .padding(10)
                            .background(isSelected ? AppTheme.electricBlue.opacity(0.10) : AppTheme.cardBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .smartCard()

            // 6. Live Reactive Typography & Telemetry Preview Studio
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.fill")
                                .foregroundStyle(AppTheme.electricBlue)
                            Text("Live Typography & Telemetry Preview")
                                .font(AppTypography.font(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Text("Real-time preview responding to active font family, scale factor, and monospaced choices.")
                            .font(AppTypography.font(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        withAnimation {
                            settings.resetTypographyToDefaults()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Typography")
                        }
                        .font(AppTypography.font(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Borno Pulse • Apple Silicon Telemetry")
                            .font(AppTypography.title)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("Scale: \(Int(round(settings.fontScale * 100)))%")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }

                    Text("High-performance native macOS system monitoring with zero background telemetry leaks, accurate hardware power measurement, and real-time disk analytics.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: 10) {
                        telemetryPreviewChip(label: "CPU", value: "14.8%", color: AppTheme.electricBlue)
                        telemetryPreviewChip(label: "RAM", value: "6.42 GB / 36 GB", color: AppTheme.purpleAccent)
                        telemetryPreviewChip(label: "NET", value: "↓ 84.2 MB/s", color: AppTheme.successGreen)
                        telemetryPreviewChip(
                            label: "CPU TEMP",
                            value: Formatters.temperature(SystemMonitor.shared.snapshot.sensors.cpuTemperature?.celsius, unit: settings.temperatureUnit),
                            color: AppTheme.orangeAccent
                        )
                    }

                    HStack(spacing: 8) {
                        Text("SHA-256")
                            .font(AppTypography.monospaced(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
                            .font(AppTypography.monospaced(size: 10))
                            .foregroundStyle(AppTheme.electricCyan)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .padding(14)
                .background(AppTheme.cardBackgroundSecondary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
            }
            .smartCard()
        }
    }

    // MARK: - Tab Content: 3. General & System
    private var generalSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Startup & Background Execution
            VStack(alignment: .leading, spacing: 14) {
                Text("Startup & Background Execution")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                LaunchAtLoginToggle(title: "Launch Borno Pulse at Login (ServiceManagement)")

                Divider().opacity(0.2)

                HStack(spacing: 12) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.successGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Background Menu Bar Execution")
                            .font(AppTypography.font(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Closing the Borno Pulse window hides the dashboard while keeping the menu bar monitor, clipboard watcher, and alerts running. To quit completely, choose Quit Borno Pulse from the menu bar or press ⌘Q.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .smartCard()

            // 2. Telemetry Engine Live State
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Live Telemetry Engine")
                            .font(AppTypography.font(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Darwin Mach host statistics, IOKit registry polling, and Darwin system activity.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()

                    StatusBadge(
                        text: monitor.isPaused ? "Paused" : "Live Monitoring",
                        color: monitor.isPaused ? AppTheme.warningAmber : AppTheme.successGreen
                    )
                }

                HStack(spacing: 12) {
                    Button {
                        if monitor.isPaused {
                            monitor.resumeMonitoring()
                        } else {
                            monitor.pauseMonitoring()
                        }
                    } label: {
                        Label(monitor.isPaused ? "Resume Live Telemetry" : "Pause Live Telemetry", systemImage: monitor.isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        monitor.refreshNow()
                        statusFeedbackMessage = "Telemetry refreshed immediately."
                    } label: {
                        Label("Sample Now (⌘R)", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .smartCard()

            // 3. Telemetry Refresh & Units
            VStack(alignment: .leading, spacing: 14) {
                Text("Telemetry Refresh & Units")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Picker("Telemetry Polling Interval", selection: $settings.refreshIntervalSeconds) {
                    Text("0.5 Seconds (High Fidelity)").tag(0.5)
                    Text("1.0 Second (Default Standard)").tag(1.0)
                    Text("2.0 Seconds (Balanced Power)").tag(2.0)
                    Text("5.0 Seconds (Maximum Energy Saving)").tag(5.0)
                }
                .pickerStyle(.menu)

                Picker("Temperature Unit", selection: $settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Read Hardware Temperature & Fan Sensors", isOn: $settings.hardwareSensorAccessEnabled)
                    Text("Reads the SMC and IOHID thermal sensors. When toggled off, only the system thermal state and battery registry data are shown.")
                        .font(AppTypography.font(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                Picker("Graph Historical Buffer", selection: $settings.historyDurationPoints) {
                    Text("30 Data Points").tag(30)
                    Text("60 Data Points (Default)").tag(60)
                    Text("120 Data Points").tag(120)
                }
                .pickerStyle(.menu)
            }
            .smartCard()

            // 4. About & System Details
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.electricBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Borno Pulse")
                            .font(AppTypography.font(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Smart Mac Utilities & System Monitor • Version 1.0.0 (Build 1)")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }

                Text("Engineered with 100% native Swift 6, SwiftUI, Metal, and Darwin APIs. Built for Apple Silicon and Intel architecture Macs.")
                    .font(AppTypography.font(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    Text("• Zero Network Telemetry")
                    Text("• Zero Ads")
                    Text("• Apple Silicon Optimized")
                }
                .font(AppTypography.font(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.electricCyan)
            }
            .smartCard()
        }
    }

    // MARK: - Tab Content: 5. Alerts & Exclusions
    private var alertsSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Hardware Alert Thresholds
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Alerts & Notification Thresholds")
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Receive native macOS notifications when system resources cross defined limits.")
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Alert on High CPU Load", isOn: $settings.notifyHighCPU)
                    if settings.notifyHighCPU {
                        HStack {
                            Text("Threshold: \(Int(settings.cpuAlertThreshold))%")
                                .font(AppTypography.font(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                            Slider(value: $settings.cpuAlertThreshold, in: 50...99, step: 1)
                        }
                    }
                }

                Divider().opacity(0.15)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Alert on High Memory Pressure", isOn: $settings.notifyHighMemory)
                    if settings.notifyHighMemory {
                        HStack {
                            Text("Threshold: \(Int(settings.memoryAlertThreshold))%")
                                .font(AppTypography.font(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                            Slider(value: $settings.memoryAlertThreshold, in: 60...99, step: 1)
                        }
                    }
                }

                Divider().opacity(0.15)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Alert on Low Battery", isOn: $settings.notifyLowBattery)
                    if settings.notifyLowBattery {
                        HStack {
                            Text("Threshold: \(settings.batteryAlertThreshold)%")
                                .font(AppTypography.font(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                            Slider(value: Binding(
                                get: { Double(settings.batteryAlertThreshold) },
                                set: { settings.batteryAlertThreshold = Int($0) }
                            ), in: 5...40, step: 1)
                        }
                    }
                }

                Divider().opacity(0.15)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Notify when Battery is Fully Charged (100%)", isOn: $settings.notifyFullyCharged)
                    Toggle("Notify when Power Cable Disconnected", isOn: $settings.notifyPowerDisconnected)
                    Toggle("Notify on Rapid Battery Discharge", isOn: $settings.notifyRapidDischarge)
                }
            }
            .smartCard()

            // 2. Temperature, Disk & Network Alerts
            VStack(alignment: .leading, spacing: 14) {
                Text("Sensor, Disk & Network Alerts")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Alert on High CPU Temperature", isOn: $alertService.enableCPUTemperatureAlert)
                    if alertService.enableCPUTemperatureAlert {
                        HStack {
                            Text("Threshold: \(Int(alertService.cpuTemperatureThresholdCelsius))°C")
                                .font(AppTypography.font(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                            Slider(value: $alertService.cpuTemperatureThresholdCelsius, in: 60...105, step: 1)
                        }
                    }
                }

                Divider().opacity(0.15)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Alert on Low Disk Space", isOn: $alertService.enableDiskAlert)
                    if alertService.enableDiskAlert {
                        HStack {
                            Text("Threshold: \(Int(alertService.diskThresholdGB)) GB free")
                                .font(AppTypography.font(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                            Slider(value: $alertService.diskThresholdGB, in: 5...50, step: 5)
                        }
                    }
                }

                Divider().opacity(0.15)

                Toggle("Alert on Network Disconnect", isOn: $alertService.enableNetworkDisconnectAlert)
            }
            .smartCard()

            // 3. Cache Cleaner Exclusions
            VStack(alignment: .leading, spacing: 12) {
                Text("Cache Cleaner Exclusions")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Folders and files specified here will never be touched by the cache cleaner.")
                    .font(AppTypography.font(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)

                HStack {
                    TextField("e.g. ~/Library/Caches/com.myimportantapp", text: $newExclusionPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        if !newExclusionPath.isEmpty {
                            var current = settings.cleanupExclusions
                            current.append(newExclusionPath)
                            settings.cleanupExclusions = current
                            newExclusionPath = ""
                        }
                    }
                    .controlSize(.small)
                }

                if !settings.cleanupExclusions.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(settings.cleanupExclusions, id: \.self) { path in
                            HStack {
                                Text(path)
                                    .font(AppTypography.font(size: 12))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Button {
                                    settings.cleanupExclusions.removeAll { $0 == path }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(AppTheme.dangerRed)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(AppTheme.cardBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
            }
            .smartCard()
        }
    }

    // MARK: - Tab Content: 6. PDF Studio & Files
    private var pdfStudioSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. PDF Studio Annotation Defaults
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PDF Studio Annotation Defaults")
                        .font(AppTypography.font(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Configure default typography, line stroke thickness, and opacity when creating new annotations.")
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Picker("Default Annotation Font", selection: $settings.pdfDefaultFontName) {
                    ForEach(PDFEditorService.fontChoices, id: \.postScript) { item in
                        Text(item.name).tag(item.postScript)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.pdfDefaultFontName) { _, newFont in
                    pdfService.textFontName = newFont
                }

                HStack {
                    Text("Default Font Size: \(Int(settings.pdfDefaultFontSize)) pt")
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    Slider(value: $settings.pdfDefaultFontSize, in: 9...36, step: 1)
                        .onChange(of: settings.pdfDefaultFontSize) { _, newSize in
                            pdfService.textFontSize = newSize
                        }
                }

                HStack {
                    Text("Default Stroke Width: \(String(format: "%.1f", settings.pdfDefaultStrokeWidth)) pt")
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    Slider(value: $settings.pdfDefaultStrokeWidth, in: 1.0...8.0, step: 0.5)
                        .onChange(of: settings.pdfDefaultStrokeWidth) { _, newWidth in
                            pdfService.strokeWidth = newWidth
                        }
                }

                HStack {
                    Text("Default Annotation Opacity: \(Int(settings.pdfDefaultAnnotationOpacity * 100))%")
                        .font(AppTypography.font(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    Slider(value: $settings.pdfDefaultAnnotationOpacity, in: 0.1...1.0, step: 0.05)
                        .onChange(of: settings.pdfDefaultAnnotationOpacity) { _, newOpacity in
                            pdfService.annotationOpacity = newOpacity
                        }
                }
            }
            .smartCard()

            // 2. Document Safety & Object Options
            VStack(alignment: .leading, spacing: 14) {
                Text("Document Safety & Object Handling")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Toggle("Lock Image Aspect Ratio on Insert & Resize", isOn: $settings.pdfLockImageAspectRatio)
                    .onChange(of: settings.pdfLockImageAspectRatio) { _, newValue in
                        pdfService.lockImageAspectRatio = newValue
                    }

                Toggle("Confirm Before Discarding Unsaved Document Changes", isOn: $settings.pdfConfirmUnsavedChanges)

                Divider().opacity(0.2)

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.successGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Safe Writer Atomic Protection")
                            .font(AppTypography.font(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("All PDF split, merge, convert, and save operations write to atomic temporary files before replacing targets, preventing file corruption or loss during power failure.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .smartCard()
        }
    }

    // MARK: - Tab Content: 7. Privacy & Security
    private var privacySecuritySettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Zero Network Telemetry Guarantee
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(AppTheme.successGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zero Network Telemetry Guarantee")
                            .font(AppTypography.font(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Borno Pulse operates entirely on this Mac. No metrics, copies, passwords, or usage patterns are ever transmitted over the network.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .smartCard()

            // 2. macOS System Permissions
            VStack(alignment: .leading, spacing: 14) {
                Text("macOS System Permissions")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Permission (Clipboard Quick Paste)")
                            .font(AppTypography.font(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Allows Borno Pulse to simulate Command+V when selecting an item from the ⌘B clipboard picker.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()

                    let trusted = ClipboardPasteService.shared.isAccessibilityTrusted
                    StatusBadge(text: trusted ? "Granted" : "Not Granted", color: trusted ? AppTheme.successGreen : AppTheme.warningAmber)

                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider().opacity(0.15)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Full Disk Access (Optional for Cache Cleaner & Storage)")
                            .font(AppTypography.font(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Enables comprehensive analysis of user caches and accurate APFS disk space allocation.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()

                    Button("Open Privacy Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .smartCard()

            // 3. Local Analytics & History Consent
            VStack(alignment: .leading, spacing: 14) {
                Text("Local Analytics & History Consent")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Toggle("Record Storage Analytics Historical Snapshots (On-Device)", isOn: Binding(
                    get: { HistoricalStorageService.shared.isHistoryCollectionEnabled },
                    set: { HistoricalStorageService.shared.isHistoryCollectionEnabled = $0 }
                ))

                Toggle("Track Application Screen Time & Active Categories (On-Device)", isOn: Binding(
                    get: { ScreenTimeTrackerService.shared.isTrackingEnabled },
                    set: { ScreenTimeTrackerService.shared.isTrackingEnabled = $0 }
                ))
            }
            .smartCard()
        }
    }

    // MARK: - Tab Content: 8. Shortcuts & Diagnostics
    private var shortcutsDiagnosticsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Keyboard Shortcuts Directory
            VStack(alignment: .leading, spacing: 14) {
                Text("Borno Pulse Keyboard Shortcuts")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                VStack(spacing: 8) {
                    shortcutRow(keys: "⌘ B", title: "Open Clipboard History Picker", subtitle: "Global shortcut to select and paste recent clipboard copies")
                    shortcutRow(keys: "⌘ K", title: "Command Palette / Quick Launcher", subtitle: "Jump directly to any monitor, tool, or utility screen")
                    shortcutRow(keys: "⌘ R", title: "Refresh Telemetry Now", subtitle: "Force immediate hardware metric sample cycle")
                    shortcutRow(keys: "⇧ ⌘ P", title: "Pause / Resume Live Monitoring", subtitle: "Temporarily pause background polling to save battery")
                    shortcutRow(keys: "⇧ ⌘ K", title: "Scan Caches Now", subtitle: "Initiate cache cleaner file scanner")
                    shortcutRow(keys: "⌘ W", title: "Close Main Window", subtitle: "Hides UI while preserving background menu bar tools")
                    shortcutRow(keys: "⌘ ,", title: "Open Settings & Preferences", subtitle: "Quick access to this preferences studio")
                }
            }
            .smartCard()

            // 2. Unit Tests & Diagnostics Suite
            unitTestRunnerCard
        }
    }

    private func shortcutRow(keys: String, title: String, subtitle: String) -> some View {
        HStack {
            Text(keys)
                .font(AppTypography.monospaced(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.electricBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTypography.font(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(AppTypography.font(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
        }
        .padding(8)
        .background(AppTheme.cardBackgroundSecondary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Tab Content: 9. Backup & Data Management
    private var backupResetSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Local Data Cleanup
            VStack(alignment: .leading, spacing: 14) {
                Text("Local Data Management")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear Storage Analytics History")
                            .font(AppTypography.font(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Removes all local historical disk consumption records.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Button("Clear History…") {
                        showClearStorageHistoryConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider().opacity(0.15)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wipe All Clipboard History")
                            .font(AppTypography.font(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Removes all saved text, formatted rich text, and stored image copies.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Button("Wipe Clipboard…") {
                        showWipeClipboardConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.dangerRed)
                    .controlSize(.small)
                }
            }
            .smartCard()
            .confirmationDialog("Wipe All Clipboard Data?", isPresented: $showWipeClipboardConfirmation) {
                Button("Wipe Everything", role: .destructive) {
                    ClipboardManagerService.shared.wipeEverything()
                    statusFeedbackMessage = "Clipboard history completely wiped."
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every clipboard entry, pinned item, and cached image.")
            }

            // 2. Preference Resets
            VStack(alignment: .leading, spacing: 14) {
                Text("Reset Specific Preferences")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 12) {
                    Button("Reset Typography") {
                        settings.resetTypographyToDefaults()
                        statusFeedbackMessage = "Typography restored to SF Pro 100%."
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Reset Menu Bar Metrics") {
                        settings.resetMenuBarMetrics()
                        statusFeedbackMessage = "Menu bar status metrics reset to default (CPU, MEM, NET, BAT)."
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Reset Widget Layout") {
                        MenuBarWidgetPreferences.shared.resetToDefaults()
                        statusFeedbackMessage = "Widget Studio layout reset to Balanced."
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider().opacity(0.15)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Factory Reset All App Preferences")
                            .font(AppTypography.font(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.dangerRed)
                        Text("Restores all appearance, typography, telemetry, alert, and PDF settings back to initial install defaults.")
                            .font(AppTypography.font(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Button("Reset All Settings…") {
                        showResetAllConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.dangerRed)
                    .controlSize(.small)
                }
            }
            .smartCard()
        }
    }

    // MARK: - Helper Views
    private func appearanceOptionTile(title: String, subtitle: String, icon: String, mode: AppAppearanceMode) -> some View {
        let isSelected = settings.appearanceMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.appearanceMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textSecondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.electricBlue)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.font(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(AppTypography.font(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AppTheme.electricBlue.opacity(0.08) : AppTheme.cardBackgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func fontScalePresetButton(title: String, scale: Double) -> some View {
        let isSelected = abs(settings.fontScale - scale) < 0.01
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.fontScale = scale
            }
        } label: {
            Text(title)
                .font(AppTypography.font(size: 11, weight: isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(isSelected ? AppTheme.electricBlue.opacity(0.15) : AppTheme.cardBackgroundSecondary)
                .foregroundStyle(isSelected ? AppTheme.electricBlue : AppTheme.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(isSelected ? AppTheme.electricBlue : AppTheme.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func telemetryPreviewChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTypography.font(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(AppTypography.monospaced(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
    }

    private func fontFamilyDescription(for family: AppFontFamily) -> String {
        switch family {
        case .sfPro:
            return "Native Apple system typography. Perfectly tuned for macOS."
        case .avenirNext:
            return "Geometric sans-serif with modern, open letterforms."
        case .helveticaNeue:
            return "Classic Swiss modernist neutral typography with crisp geometry."
        case .inter:
            return "Crafted specifically for computer screens and high UI readability."
        case .sfMono:
            return "Apple developer monospaced font applied across all user interface elements."
        }
    }

    private func sampleFont(for family: AppFontFamily, size: CGFloat) -> Font {
        if let ps = family.postScriptName, family.isAvailableOnSystem {
            return Font.custom(ps, size: size)
        }
        return Font.system(size: size)
    }

    private func monoFontSample(for mono: AppMonospacedFontFamily, size: CGFloat) -> Font {
        if let ps = mono.postScriptName, mono.isAvailableOnSystem {
            return Font.custom(ps, size: size)
        }
        return Font.system(size: size, design: .monospaced)
    }

    private var unitTestRunnerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Built-in Diagnostic & Unit Test Suite", systemImage: "checkmark.seal.fill")
                    .font(AppTypography.font(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.successGreen)
                Spacer()
                Button(isRunningTests ? "Running Tests…" : "Run Test Suite") {
                    isRunningTests = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        testResults = SmartToolTests.runAllTests()
                        isRunningTests = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentFill)
                .controlSize(.small)
                .disabled(isRunningTests)
            }

            Text("Executes self-diagnostic unit tests verifying metric calculation bounds, mock providers, Intel/Apple Silicon handling, APFS purgeable algorithms, cleaner safety rules, and typography customization invariants.")
                .font(AppTypography.font(size: 11))
                .foregroundStyle(AppTheme.textSecondary)

            if let res = testResults {
                HStack(spacing: 12) {
                    StatusBadge(text: "\(res.passed) Passed", color: AppTheme.successGreen)
                    if res.failed > 0 {
                        StatusBadge(text: "\(res.failed) Failed", color: AppTheme.dangerRed)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(res.logs.prefix(25), id: \.self) { log in
                        Text(log)
                            .font(AppTypography.monospaced(size: 10))
                            .foregroundStyle(log.contains("PASS") ? AppTheme.successGreen : AppTheme.dangerRed)
                    }
                    if res.logs.count > 25 {
                        Text("… and \(res.logs.count - 25) more passing tests")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .padding(8)
                .background(AppTheme.cardBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 0.5))
            }
        }
        .smartCard()
    }
}
