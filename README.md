# Borno Pulse ⚡️
> **Smart Mac Utilities & System Monitor**  
> A premium, production-grade native macOS Super Utility Suite engineered in Swift 6 & SwiftUI.

---

## 1. Overview

**Borno Pulse** is an advanced native macOS system utility suite that unites real-time hardware telemetry, storage treemap analytics, cache cleanup, image & PDF file tools, screen time tracking, and an extensive suite of offline-first power tools:

- 🛠️ **Developer Toolbox**: JSON formatter/minifier/tree explorer/diff, JWT inspector with claim decoding & expiration audit, lightweight API request client with automatic secret redaction, and Docker dashboard with safe container lifecycle controls.
- 🌐 **Network Toolkit**: Real-time interface throughput, BSD getifaddrs IP diagnostics, ICMP ping latency graphs, multi-record DNS lookups (A/AAAA/CNAME/MX/TXT/NS), and TLS/SSL certificate chain & expiration inspector.
- 📋 **Clipboard Manager**: Privacy-first opt-in history with sensitive secret masking (passwords, tokens, cards), app exclusions, and quick copy-back actions.
- ⏱️ **Focus & Pomodoro**: Timestamp-driven focus sessions (25m blocks, short/long breaks), streak tracking, daily/weekly metrics, and foreground Screen Time awareness.
- 🔋 **Advanced Battery Monitoring & Estimation**: Dedicated `BatteryEstimationService` computing empirical discharge/charge slope with non-linear saturation curve compensation, real-time power draw (Watts), observed rate (%/hr), confidence indicators, 7-day retention persistence, customizable alerts (low battery, 100% full, AC disconnect, rapid discharge), and macOS menu bar indicators.
- 🔄 **Batch File Converter**: Unified batch processing queue utilizing existing native ImageIO and PDFKit engines with collision-safe naming and progress reporting.
- 🛡️ **Privacy & Security**: 1MB streaming cryptographic file hasher (SHA-256, SHA-384, SHA-512, legacy SHA-1/MD5 with warnings), metadata inspector, and macOS TCC permission audit.
- ⚡️ **Quick Launcher (⌘K)**: Global keyboard-first command palette with fuzzy search across all 25 system modules and utilities.
- 💾 **Local Backup Helper**: Folder profiles with Full Copy, Incremental Sync, and Mirror modes, SHA-256 integrity verification, safe restore workflow, and exportable reports.
- 📊 **Hardware Telemetry & Analytics**: Real-time CPU/GPU/RAM/Thermal monitoring, APFS purgeable space, interactive squarified treemaps, two-step cache cleaner, and Screen Time analytics.

---

## 2. Architecture & Modular Structure

```
smart tool/
├── App/
│   ├── smart_toolApp.swift              # App entry point, menu bar coordinator, CLI test runner
│   └── ContentView.swift                # Dashboard root container
├── Core/
│   ├── Theme/
│   │   └── AppTheme.swift               # Design tokens, gradients, surfaces, and card modifiers
│   └── Extensions/
│       └── Formatters.swift             # Thread-safe formatters for bytes, speed, temp, and units
├── Models/
│   ├── MetricModels.swift               # Strongly-typed models for CPU, GPU, RAM, Thermals, Battery, etc.
│   ├── ProcessModel.swift               # ProcessItem model and energy score algorithms
│   ├── CleanupModels.swift              # Safe cache categories, file items, and dry-run models
│   ├── StorageAnalyzerModels.swift      # Storage category classification and disk item models
│   └── AppSettings.swift                # User preferences, menu bar display, and alert thresholds
├── Services/
│   ├── SystemMonitor.swift              # MainActor coordinator running background polling engine
│   └── LaunchAtLoginService.swift       # ServiceManagement (SMAppService) login item manager
├── Monitoring/
│   ├── Battery/
│   │   ├── BatteryProvider.swift          # IOKit.ps & AppleSmartBattery hardware voltage/amperage query
│   │   └── BatteryEstimationService.swift # Real-time empirical slope, non-linear taper, 7-day history & alerts
│   ├── CPU/CPUProvider.swift            # Host processor load info (per-core & overall)
│   ├── GPU/GPUProvider.swift            # Metal capabilities & IOKit IOAccelerator metrics
│   ├── Memory/MemoryProvider.swift      # Mach host_statistics64 virtual memory & swap
│   ├── Sensors/SensorProvider.swift     # Thermal envelope and throttling diagnostics
│   ├── Storage/StorageProvider.swift    # APFS volumes, purgeable space, and capacity
│   └── Network/NetworkProvider.swift    # Darwin getifaddrs delta speed & interface inspection
├── DeveloperTools/
│   ├── JSON/                            # Formatter, minifier, line/col validator, CSV export, diff
│   ├── JWT/                             # Claims, header, payload, and clock expiration models
│   ├── HTTPClient/                      # URLSession client, TLS validation, secret redaction
│   └── Docker/                          # Container states, images, stats, and lifecycle actions
├── NetworkTools/                        # Connectivity, Ping, DNS, SSL Certificate inspection
├── Clipboard/                           # Opt-in clipboard history, secret protection, app exclusions
├── Focus/                               # Focus & Pomodoro timer, streak tracking, Screen Time sync
├── BatchProcessing/                     # Batch converter queue reusing ImageIO & PDFKit
├── PrivacySecurity/                     # Streaming file hasher, metadata inspector, permission audit
├── QuickLauncher/                       # ⌘K Command palette modal with keyboard navigation
├── Backup/                              # Local Backup Helper profiles, incremental sync, restore
├── FileTools/                           # Image format converter, compressor, resizer, PDF tools
├── StorageAnalyzer/                     # Safe directory recursion, category allocation, squarified treemaps
├── Views/                               # SwiftUI views for all modules and system dashboards
└── Tests/
    ├── MockProviders.swift              # Deterministic test doubles for hardware queries
    └── SmartToolTests.swift             # 113 automated unit and invariant regression tests
```

---

## 3. Implemented Modules & Features

### Advanced Battery Monitoring & Time Estimation
- **Dedicated BatteryEstimationService**:
  - Samples battery percentage, power state, and charging rate continuously.
  - Computes empirical rate of change ($\%/hr$) over an adaptive sliding observation window.
  - Accounts for lithium-ion charging taper curve: fast charging up to 80% with non-linear saturation compensation between 80% and 100%.
  - When discharging, projects time remaining until user-configured low-battery safety reserve (e.g. 10%).
  - Blends native macOS IOKit `kIOPSTimeToEmptyKey` / `kIOPSTimeToFullChargeKey` estimates when available with observed workload consumption.
  - Clear confidence qualification: *High Confidence*, *Moderate Confidence*, *Low Confidence*, *Calculating...*, and *Unavailable*.
- **Hardware Diagnostics**:
  - Cycle count (rated for 1,000 cycles), maximum capacity health percentage.
  - Live cell DC voltage (V), current flow (A), and system power draw / charging wattage (W).
  - Internal battery temperature (°C).
- **Interactive Historical Charts**:
  - 1 Hour, 6 Hours, 24 Hours, and 7 Days time ranges.
  - Swift Charts area and line graphs plotting actual recorded charge level and rate trajectory.
  - Lightweight on-disk JSON persistence with automatic 7-day retention trimming.
- **Menu Bar Indicators**:
  - Battery % (`78%`)
  - Estimated Time Remaining (`5h 24m remaining`)
  - Battery Status Icon (`⚡️` / `🔋` / `🔌`)
  - Battery % + Time (`78% (5h 24m)`)
- **Configurable Notifications**:
  - Low battery threshold alert (10%, 15%, 20%, 25%).
  - 100% Fully charged notification.
  - AC power disconnected notification.
  - Rapid battery discharge alert (> 20%, > 25%, > 30%/hr).
- **Graceful Desktop Mac Mode**:
  - Automatically detects desktop Macs without battery hardware (Mac mini, Mac Studio, Mac Pro, iMac).
  - Clearly displays continuous AC power supply status without fabricated battery metrics.

### Advanced PDF Studio (Native macOS)
- **14 Professional Document Processing Tools**:
  1. **Images to PDF**: Import PNG, JPG, HEIC, TIFF, WebP, BMP with page presets (A4, Letter, Legal, Custom), margins, and fit options (contain, cover, stretch).
  2. **Merge PDFs**: Lossless document merger preserving vector artwork, embedded fonts, and selectable text layers.
  3. **Merge Images & PDFs**: Unified mixed assembly canvas combining photos and multi-page PDFs in any custom sequence.
  4. **Advanced PDF Editor**: Full document canvas with page thumbnail strip, drawing, annotation tools (highlight, underline, strikeout, free text, pen, shapes, sticky notes), signature stamping, and interactive AcroForm field detection.
  5. **Page Organizer**: Visual thumbnail grid for drag-and-drop reordering, page rotation, deletion, and duplication.
  6. **PDF to Images**: High-DPI rasterization to PNG, JPG, or TIFF with customizable page ranges.
  7. **Word & Office to PDF**: 100% offline conversion for DOCX, RTF, RTFD, TXT, HTML, and Markdown via Apple CoreText/TextKit pagination and optional local LibreOffice headless detection.
  8. **PDF Compressor**: Presets for stream optimization and image downsampling with file size comparison.
  9. **PDF Splitter**: Split by every page, page ranges, or recurring N-page intervals.
  10. **Page Extractor**: Extract designated pages into a new standalone document.
  11. **Rotate & Reorder**: Batch 90°/180°/270° orientation adjustment and sequence inversion.
  12. **Metadata & Privacy Inspector**: Inspect hidden document attributes, dates, author, and strip tracking tags for privacy.
  13. **OCR & Searchable PDF**: On-device Apple Vision text recognition across 30+ languages to extract text and generate searchable PDFs with invisible text layers.
  14. **Export & Print**: Native macOS print operation (`NSPrintOperation`) and validated export with overwrite guard.
- **Safety & Privacy Safeguards**:
  - 100% local processing: zero telemetry, zero cloud uploads.
  - Never overwrites original files without explicit user confirmation dialog.

---

### Customizable Menu Bar Widget & Mini Dashboard
- **Customizable Widget Preferences (`MenuBarWidgetPreferences`)**:
  - Over 40 distinct telemetry metrics categorized into 8 domains: CPU, Memory, GPU & Neural Engine, Temperature & Fans, Battery & Power, Storage, Network, and System.
  - Three distinct layout densities: Compact (minimal glyphs & values), Balanced (labels, values, and progress bars), and Detailed (sparkline trend charts and secondary states).
  - Configurable metric ordering with drag-and-drop support and persistent ordering.
  - Visual customization toggles: Compact spacing, show/hide icons, show/hide metric labels, show/hide progress bars, show/hide trend sparklines, and percentage vs. raw value toggling.
  - Monitored storage volume selection (system root `/` or external mounted APFS/HFS+ volumes).
  - Quick action footer with 10 native actions (Overview Dashboard, CPU & Cores, Battery, Storage Analytics, Network, Focus Timer, Cache Cleaner with confirmation, Settings, Refresh, Quit).
  - Menu Bar status item indicator customizer with live simulated preview.
- **Threshold Alerts & Cooldown Deduplication (`WidgetAlertService`)**:
  - User-configurable warning thresholds for High CPU %, High Memory Pressure %, Low Disk Free Space (GB), Low Battery %, High Temperature (°C), and Network Interface Disconnect.
  - 5-minute (300-second) cooldown deduplication engine to suppress notification fatigue.
  - 100% honest telemetry: Missing sensor readings or desktop Macs without battery hardware are reported transparently as unavailable rather than fabricating zero values.
- **Live Preview Studio (`MenuBarWidgetSettingsView`)**:
  - Two-column split-view studio in Settings under "Menu Bar & Widget" with immediate real-time updates as metrics and styles are adjusted, and a safe "Reset to Defaults" action.

### Typography, Icon & Appearance Customization
- **Centralized Design System (`AppTypography.swift`)**:
  - Unified typography tokens (`AppTypography.title`, `.headline`, `.body`, `.caption`, `.metricNumber`) and view modifiers (`.appFont(...)`, `.appMonospaced(...)`).
  - Font scaling bounded between **85% and 120%** with quick presets (85% Compact, 100% Default, 110% Comfortable, 120% Large).
  - Primary font family selection: **SF Pro** (System Default), **Avenir Next**, **Helvetica Neue**, **Inter**, and **SF Mono**.
  - System availability query (`isAvailableOnSystem`) with seamless, graceful fallback to native Apple SF Pro when a third-party font is not installed.
  - Base weight selection: **Regular**, **Medium**, and **Semibold**.
  - Separate monospaced font family for technical metrics, developer tools, hashes, and charts: **System Monospaced**, **SF Mono**, **Menlo**, and **Courier New**.
  - Live Typography & Telemetry Preview Studio in Settings with live preview cards and instant "Reset to Defaults".
- **Appearance System**:
  - **Light Mode** is the initial default for new installations.
  - Supports **Light**, **Dark**, and **System** appearance modes.
  - Dynamically updates the main window, settings, menu bar popover, widgets, charts, and dialogs.
  - Persisted across application restarts via `@AppStorage("appearanceMode")`.
- **Application Icon**:
  - Distinctive, recognizable Borno Pulse telemetry cardiogram motif in Apple squircle format.
  - Complete native macOS asset catalog with high-fidelity PNG assets at all required macOS display sizes (16, 32, 64, 128, 256, 512, 1024 pt).
- **Adaptive Menu Bar Icon**:
  - Native monochrome template-style icon (`isTemplate = true`) that dynamically adapts to light and dark macOS menu bars.
  - Customizable symbol options: **Pulse Wave** (`waveform.path.ecg`), **Gauge Needle** (`gauge.with.dots.needle.bottom.100percent`), **Energy Pulse** (`bolt.heart.fill`), **CPU Processor** (`cpu`), **Activity Trend** (`chart.line.uptrend.xyaxis`), and **Modern Sparkle** (`sparkles`).

---

## 4. Build & Test Verification

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Xcode 16.0+ with Swift 6
- Apple Silicon (arm64) or Intel (x86_64)

### Building the Project
```bash
cd "/Users/mohammadalinayeem/Project & Code/ios/smart tool"
xcodebuild -scheme "smart tool" -destination 'platform=macOS' build
```

### Running Automated Invariant Tests
Execute the built application with the `--run-tests` flag:
```bash
"$HOME/Library/Developer/Xcode/DerivedData/smart_tool-"*/Build/Products/Debug/"smart tool.app/Contents/MacOS/smart tool" --run-tests
```

**Test Suite Results**:
```
--- INVARIANT TESTS COMPLETED ---
Passed: 187, Failed: 0
✅ PASS: All 187 invariant test suites passed with zero failures.
```

The test suite validates:
- Menu Bar Widget metric registry coverage (8 categories, 45+ metrics)
- Menu Bar Widget default configuration, layout styles, and quick actions
- Metric selection toggling, drag-and-drop reordering math, and UserDefaults persistence
- Extractor engine honest hardware handling (unavailable notes on desktop Macs / restricted sensors, never fabricated 0s)
- Widget alert threshold evaluation and 5-minute cooldown deduplication suppression
- Real-time battery wattage electrical calculation ($Power = Voltage \times Current$ converting mV & mA)
- Sign conventions for active charging vs discharging
- Power flow distribution invariants ($Adapter Rated \neq System Consumption \neq Battery Charge$)
- Missing sensor data graceful `nil` handling (never fabricating 0W)
- Native IOKit `AppleSmartBattery` telemetry parsing (system load, rated adapter capacity, input power)
- Battery discharge-time remaining calculation to low threshold
- Battery charge-time estimation with non-linear saturation tapering
- Sparse observation window graceful "Calculating..." state
- State transitions (AC plug/unplug) window reset
- 100% on AC fully charged state detection
- Desktop Mac (no battery) graceful AC wall power status
- Native OS blended estimate priority
- Historical 7-day retention policy and range intervals
- PDF Studio 14 tools, page assembly, undo/redo, annotations, and OCR language detection
- JSON, JWT, API client, Docker, Network Ping, DNS, SSL, Clipboard, Focus Pomodoro, Batch Converter, CryptoKit Hasher, Quick Launcher, and Local Backup invariants.

---

## 5. Product Information
- **Product Name**: Borno Pulse
- **Display Name**: Borno Pulse
- **Subtitle**: Smart Mac Utilities & System Monitor
- **Platform**: Native macOS (macOS 14.0+)
- **Architecture**: Swift 6 + SwiftUI + AppKit + Metal + IOKit + PDFKit + CryptoKit
- **Philosophy**: Fast, private, useful, transparent, and reliable.

