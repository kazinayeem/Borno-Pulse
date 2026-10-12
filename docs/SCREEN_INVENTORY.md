# Borno Pulse — Screen Inventory & Audit Status

This document catalogs every user interface surface, navigation section, settings tab, utility sheet, and menu bar widget view in **[Borno Pulse](https://github.com/kazinayeem/Borno-Pulse)**.

All screenshots are captured programmatically from the compiled, running application using native AppKit display caching across both **Light Mode** and **Dark Mode**.

Repository: [https://github.com/kazinayeem/Borno-Pulse](https://github.com/kazinayeem/Borno-Pulse)

---

## 1. Main Navigation Sections (Dashboard)

| # | Section Name | Identifier | Source View | Light Screenshot | Dark Screenshot | Status |
|---|--------------|------------|-------------|------------------|-----------------|--------|
| 1 | **Overview** | `.overview` | `OverviewView.swift` | `screenshots/light/overview.png` | `screenshots/dark/overview.png` | Fully Implemented |
| 2 | **CPU** | `.cpu` | `CPUDetailView.swift` | `screenshots/light/cpu.png` | `screenshots/dark/cpu.png` | Fully Implemented |
| 3 | **GPU & Neural Engine** | `.gpu` | `GPUDetailView.swift` | `screenshots/light/gpu.png` | `screenshots/dark/gpu.png` | Fully Implemented |
| 4 | **Memory** | `.memory` | `MemoryDetailView.swift` | `screenshots/light/memory.png` | `screenshots/dark/memory.png` | Fully Implemented |
| 5 | **Temperature & Fans** | `.sensors` | `SensorsDetailView.swift` | `screenshots/light/sensors.png` | `screenshots/dark/sensors.png` | Fully Implemented |
| 6 | **Storage** | `.storage` | `StorageDetailView.swift` | `screenshots/light/storage.png` | `screenshots/dark/storage.png` | Fully Implemented |
| 7 | **Network** | `.network` | `NetworkDetailView.swift` | `screenshots/light/network.png` | `screenshots/dark/network.png` | Fully Implemented |
| 8 | **Battery & Energy** | `.battery` | `BatteryDetailView.swift` | `screenshots/light/battery.png` | `screenshots/dark/battery.png` | Fully Implemented |
| 9 | **Developer Toolbox** | `.developerToolbox` | `DeveloperToolboxView.swift` | `screenshots/light/developer_toolbox.png` | `screenshots/dark/developer_toolbox.png` | Fully Implemented |
| 10 | **Network Toolkit** | `.networkToolkit` | `NetworkToolkitView.swift` | `screenshots/light/network_toolkit.png` | `screenshots/dark/network_toolkit.png` | Fully Implemented |
| 11 | **Port Manager** | `.portManager` | `PortManagerView.swift` | `screenshots/light/port_manager.png` | `screenshots/dark/port_manager.png` | Fully Implemented |
| 12 | **Clipboard Manager** | `.clipboard` | `ClipboardManagerView.swift` | `screenshots/light/clipboard.png` | `screenshots/dark/clipboard.png` | Fully Implemented |
| 13 | **Focus & Pomodoro** | `.focusPomodoro` | `FocusPomodoroView.swift` | `screenshots/light/focus_pomodoro.png` | `screenshots/dark/focus_pomodoro.png` | Fully Implemented |
| 14 | **Batch File Converter** | `.batchConverter` | `BatchConverterView.swift` | `screenshots/light/batch_converter.png` | `screenshots/dark/batch_converter.png` | Fully Implemented |
| 15 | **PDF Studio** | `.pdfStudio` | `PDFStudioWorkspaceView.swift` | `screenshots/light/pdf_studio.png` | `screenshots/dark/pdf_studio.png` | Fully Implemented |
| 16 | **File Tools** | `.fileTools` | `FileToolsDashboardView.swift` | `screenshots/light/file_tools.png` | `screenshots/dark/file_tools.png` | Fully Implemented |
| 17 | **Privacy & Security** | `.privacySecurity` | `PrivacySecurityWorkspaceView.swift` | `screenshots/light/privacy_security.png` | `screenshots/dark/privacy_security.png` | Fully Implemented |
| 18 | **Local Backup Helper** | `.localBackup` | `LocalBackupHelperView.swift` | `screenshots/light/local_backup.png` | `screenshots/dark/local_backup.png` | Fully Implemented |
| 19 | **Screen Time** | `.screenTime` | `ScreenTimeDashboardView.swift` | `screenshots/light/screen_time.png` | `screenshots/dark/screen_time.png` | Fully Implemented |
| 20 | **Storage Analytics** | `.storageAnalytics` | `StorageAnalyticsDashboardView.swift` | `screenshots/light/storage_analytics.png` | `screenshots/dark/storage_analytics.png` | Fully Implemented |
| 21 | **Processes** | `.processes` | `ProcessMonitorView.swift` | `screenshots/light/processes.png` | `screenshots/dark/processes.png` | Fully Implemented |
| 22 | **Cache Cleaner** | `.cleaner` | `CacheCleanerView.swift` | `screenshots/light/cleaner.png` | `screenshots/dark/cleaner.png` | Fully Implemented |
| 23 | **Diagnostics** | `.diagnostics` | `DiagnosticsView.swift` | `screenshots/light/diagnostics.png` | `screenshots/dark/diagnostics.png` | Fully Implemented |
| 24 | **Settings** | `.settings` | `SettingsView.swift` | `screenshots/light/settings.png` | `screenshots/dark/settings.png` | Fully Implemented |
| 25 | **Clamshell Mode** | `.clamshellMode` | `ClamshellModeView.swift` | `screenshots/light/clamshell_mode.png` | `screenshots/dark/clamshell_mode.png` | Fully Implemented |

---

## 2. Settings Subsections & Category Tabs

| Tab Name | Tab Identifier | Light Screenshot | Dark Screenshot | Status |
|----------|----------------|------------------|-----------------|--------|
| **Appearance & Typography** | `.appearanceTypography` | `screenshots/light/settings_appearance.png` | `screenshots/dark/settings_appearance.png` | Fully Implemented |
| **Menu Bar & Widget** | `.menuBarWidget` | `screenshots/light/settings_menubar.png` | `screenshots/dark/settings_menubar.png` | Fully Implemented |
| **General & System** | `.general` | `screenshots/light/settings_general.png` | `screenshots/dark/settings_general.png` | Fully Implemented |
| **Clipboard** | `.clipboard` | `screenshots/light/settings_clipboard.png` | `screenshots/dark/settings_clipboard.png` | Fully Implemented |
| **Alerts & Exclusions** | `.alerts` | `screenshots/light/settings_alerts.png` | `screenshots/dark/settings_alerts.png` | Fully Implemented |
| **PDF Studio & Files** | `.pdfStudio` | `screenshots/light/settings_pdf.png` | `screenshots/dark/settings_pdf.png` | Fully Implemented |
| **Privacy & Security** | `.privacySecurity` | `screenshots/light/settings_privacy.png` | `screenshots/dark/settings_privacy.png` | Fully Implemented |
| **Shortcuts & Diagnostics** | `.shortcutsDiagnostics` | `screenshots/light/settings_shortcuts.png` | `screenshots/dark/settings_shortcuts.png` | Fully Implemented |
| **Backup & Data Management** | `.backupReset` | `screenshots/light/settings_backup.png` | `screenshots/dark/settings_backup.png` | Fully Implemented |

---

## 3. Command Palette & Menu Bar Utility Widget

| Interface Element | Description | Light Screenshot | Dark Screenshot | Status |
|-------------------|-------------|------------------|-----------------|--------|
| **Quick Launcher (⌘K)** | Global fuzzy command palette across all 25 modules | `screenshots/light/quick_launcher.png` | `screenshots/dark/quick_launcher.png` | Fully Implemented |
| **Widget: Audio** | Volume mixer & audio output selection popover | `screenshots/widget/light-audio.png` | `screenshots/widget/dark-audio.png` | Fully Implemented |
| **Widget: Battery** | Real-time battery wattage, rate, health & slope | `screenshots/widget/light-battery.png` | `screenshots/widget/dark-battery.png` | Fully Implemented |
| **Widget: Hardware** | CPU, GPU, RAM, Thermals snapshot | `screenshots/widget/light-hardware.png` | `screenshots/widget/dark-hardware.png` | Fully Implemented |
| **Widget: Quick Actions** | Instant cache cleaning, kill heavy apps, presets | `screenshots/widget/light-actions.png` | `screenshots/widget/dark-actions.png` | Fully Implemented |
| **Widget: Primary** | Default popover presentation | `screenshots/widget/light-widget.png` | `screenshots/widget/dark-widget.png` | Fully Implemented |

---

## 4. Automation Verification Summary
- **Automation Engine**: `ScreenshotAutomationService.swift`
- **Execution Script**: `scripts/capture-screenshots.sh`
- **Resolution**: Native macOS Retina display caching (`bitmapImageRepForCachingDisplay`)
- **Total Unique Screens Tracked**: 35 screens (25 navigation sections + 9 settings tabs + 1 Quick Launcher) across Light & Dark appearances (70 images) + 10 Menu Bar Widget popover states = **80 total screenshot assets**.
