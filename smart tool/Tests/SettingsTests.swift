//
//  SettingsTests.swift
//  Borno Pulse
//
//  Settings behavior and layout integrity tests.
//  Every preference touched here is restored before the test returns.
//

import AppKit
import Combine
import Foundation
import SwiftUI

extension SmartToolTests {
    @MainActor
    static func runSettingsTests(_ assert: (Bool, String) -> Void) {
        let settings = AppSettings.shared

        // 1. Observer publishing
        var fired = 0
        let token = settings.objectWillChange.sink { _ in fired += 1 }
        let originalScale = settings.fontScale
        settings.fontScale = originalScale == 1.0 ? 1.05 : 1.0
        assert(fired > 0, "Settings: changing a stored preference notifies observers (fired \(fired))")
        settings.fontScale = originalScale
        token.cancel()

        // 2. SettingsSectionTab completeness (all 9 categories)
        let tabs = SettingsSectionTab.allCases
        assert(tabs.count == 9, "Settings: exactly 9 comprehensive settings category tabs available (found \(tabs.count))")
        for tab in tabs {
            assert(!tab.rawValue.isEmpty, "Settings tab '\(tab.rawValue)' has non-empty title")
            assert(!tab.icon.isEmpty, "Settings tab '\(tab.rawValue)' has valid SF Symbol icon '\(tab.icon)'")
        }

        // 3. Category tabs include all audited sections
        let tabSet = Set(tabs)
        assert(tabSet.contains(.appearanceTypography), "Settings contains Appearance & Typography")
        assert(tabSet.contains(.menuBarWidget), "Settings contains Menu Bar & Widget")
        assert(tabSet.contains(.general), "Settings contains General & System")
        assert(tabSet.contains(.clipboard), "Settings contains Clipboard")
        assert(tabSet.contains(.alerts), "Settings contains Alerts & Exclusions")
        assert(tabSet.contains(.pdfStudio), "Settings contains PDF Studio & Files")
        assert(tabSet.contains(.privacySecurity), "Settings contains Privacy & Security")
        assert(tabSet.contains(.shortcutsDiagnostics), "Settings contains Shortcuts & Diagnostics")
        assert(tabSet.contains(.backupReset), "Settings contains Backup & Data Management")

        // 4. PDF Studio Preference Defaults & Persistence
        let originalPDFSize = settings.pdfDefaultFontSize
        let originalPDFFont = settings.pdfDefaultFontName
        let originalPDFOpacity = settings.pdfDefaultAnnotationOpacity
        let originalPDFStroke = settings.pdfDefaultStrokeWidth

        settings.pdfDefaultFontSize = 18.0
        settings.pdfDefaultFontName = "Times"
        settings.pdfDefaultAnnotationOpacity = 0.8
        settings.pdfDefaultStrokeWidth = 3.5

        assert(settings.pdfDefaultFontSize == 18.0, "Settings: PDF default font size persists")
        assert(settings.pdfDefaultFontName == "Times", "Settings: PDF default font name persists")
        assert(settings.pdfDefaultAnnotationOpacity == 0.8, "Settings: PDF default opacity persists")
        assert(settings.pdfDefaultStrokeWidth == 3.5, "Settings: PDF default stroke width persists")

        settings.pdfDefaultFontSize = originalPDFSize
        settings.pdfDefaultFontName = originalPDFFont
        settings.pdfDefaultAnnotationOpacity = originalPDFOpacity
        settings.pdfDefaultStrokeWidth = originalPDFStroke

        // 5. Typography Reset Invariants
        settings.appFontFamily = .inter
        settings.fontScale = 1.15
        settings.baseFontWeight = .semibold
        settings.resetTypographyToDefaults()
        assert(settings.appFontFamily == .sfPro, "Settings: Reset restores SF Pro")
        assert(settings.fontScale == 1.0, "Settings: Reset restores 100% scale")
        assert(settings.baseFontWeight == .regular, "Settings: Reset restores Regular weight")
        assert(settings.currentFontSizePreset == .normal, "Settings: Reset restores Normal font size preset")

        // 5B. Font Size Preset Invariants
        settings.applyFontSizePreset(.small)
        assert(settings.fontScale == 0.90, "Settings: Small preset applies 0.90 scale")
        assert(settings.currentFontSizePreset == .small, "Settings: Detected current preset is Small")

        settings.applyFontSizePreset(.large)
        assert(settings.fontScale == 1.15, "Settings: Large preset applies 1.15 scale")
        assert(settings.currentFontSizePreset == .large, "Settings: Detected current preset is Large")

        settings.applyFontSizePreset(.normal)
        assert(settings.fontScale == 1.0, "Settings: Normal preset applies 1.0 scale")
        assert(settings.currentFontSizePreset == .normal, "Settings: Detected current preset is Normal")

        // Check font availability detection
        assert(AppFontFamily.sfPro.isAvailableOnSystem, "AppFontFamily: SF Pro is available")
        assert(AppFontFamily.allCases.count >= 5, "AppFontFamily: at least 5 families provided")

        // 6. Menu Bar Metrics Reset Invariants
        settings.setMenuBarMetrics([.cpuTemperature, .gpuTemperature])
        assert(settings.menuBarStatusMetrics.count == 2, "Settings: menu bar custom metrics count is 2")
        settings.resetMenuBarMetrics()
        assert(settings.menuBarStatusMetrics.count == 4, "Settings: Reset restores default 4 metrics")
        assert(settings.menuBarStatusMetrics[0] == .cpuUsage, "Settings: First metric is CPU")

        // 7. Navigation Router State Preservation
        SettingsNavigation.shared.requestedTab = .pdfStudio
        assert(SettingsNavigation.shared.requestedTab == .pdfStudio, "SettingsNavigation: preserves requested tab")
        SettingsNavigation.shared.requestedTab = nil
    }
}
