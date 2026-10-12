# Changelog

All notable changes to **Borno Pulse** are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.0] - 2026-10-12

### Added
- **Automated Screenshot Suite**: Built-in programmatic screenshot engine (`ScreenshotAutomationService`) supporting full application visual regression testing across Light Mode, Dark Mode, and Menu Bar Widget tabs.
- **Port Manager**: Real-time listening port auditor (`PortScannerService`) with Darwin BSD socket parsing, Vite/Next.js/PostgreSQL/Redis process detection, Docker container correlation, and secret redaction.
- **Expanded Settings Suite**: 9 full-coverage category tabs including Appearance & Typography, Menu Bar & Widget, Alerts & Exclusions, and Backup & Data Management.
- **Typography & Font Customization**: Native font family selection (SF Pro, New York, SF Mono, Menlo, Helvetica Neue), font scale presets (Small, Normal, Large), and real-time live preview.

### Changed
- **Menu Bar Popover Widget**: Redesigned 4-category layout (Audio, Battery, Hardware, Actions) with compact cards, single-line typography, and responsive metric alignment.
- **Strict Concurrency Compliance**: Refactored services for Swift 6 region-based isolation, eliminating all actor-boundary compiler warnings and `_dispatch_assert_queue_fail` crashes.

### Fixed
- **PDF Studio Background Analysis Crash**: Removed MainActor override on `PDFEditorCanvasView.document` to allow PDFKit's background Vision page analyzer (`PDFPageAnalyzerV2`) to execute without actor assertion failures.
- **Security-Scoped File Access**: Added bookmark security-scoped access guards to `PDFEditorService` for dropped and externally referenced PDF documents.
- **Chart Layout**: Corrected `AxisValueLabel` anchor positioning in sensor thermal charts.

---

## [1.1.0] - 2026-10-10

### Added
- **PDF Studio Suite**: 12 native offline tools including Advanced PDF Editor, Images to PDF, Merge PDFs, Page Organizer, Splitter, Extractor, Compressor, and Local OCR.
- **Developer Toolbox**: Local JSON formatter/validator/diff, JWT claim inspector, lightweight HTTP client with secret redaction, and Docker container controller.
- **Local Backup Helper**: Folder backup profiles with Full, Incremental, and Mirror sync modes and SHA-256 integrity verification.

---

## [1.0.0] - 2026-09-15

### Initial Release
- Hardware telemetry engine (CPU per-core load, GPU utilization, RAM pressure & swap, APFS storage volumes, thermal sensors, battery health & wattage).
- Menu bar status item with multi-metric tokens and transient popover.
- Opt-in Clipboard Manager with sensitive credential protection.
- Focus & Pomodoro session timer with Screen Time synchronization.
- Cache Cleaner with safe dry-run preview and two-step purge.
- Command Palette (⌘K) quick launcher.
