# Changelog

All notable changes to **Borno Pulse** are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
    3
## [1.3.0] - 2026-10-12

### Added
- **Keep Running When Lid Is Closed (Clamshell Mode)**: Dedicated clamshell management system (`ClamshellManager`) utilizing native IOKit power assertions (`kIOPMAssertionTypePreventUserIdleSystemSleep`) to maintain background operations (Docker, local dev servers, scripts) with the lid closed.
- **Hardware Readiness Audit Checklist**: Live verification of Mac laptop model, AC power connection (`IOPSGetProvidingPowerSourceType`), external display topology (`CGGetOnlineDisplayList`), and Apple official clamshell compliance.
- **Workload Verification Diagnostics**: Real-time diagnostic panel monitoring Docker container status, active listening server sockets (Vite, Next.js, Django, FastAPI), background processes, and macOS awake uptime.
- **Duration Presets & Countdown**: Configurable timers (1h, 2h, 3h, Until Stopped, or Custom hours & minutes) with real-time remaining countdown and visual status pill.
- **Quick Actions 21-Action Grid**: Responsive grid in the Menu Bar Widget with circular icons, hover interactions, destructive action confirmations (Empty Trash), and system action launchers.
- **Clamshell Mode Invariant Tests**: Expanded test suite to **854+ tests** validating duration calculations, hardware readiness checklists, and power assertion lifecycles.

### Fixed
- **CoreFoundation Autorelease Pool Crash**: Resolved `EXC_BAD_ACCESS` in `objc_release` caused by unretained `IOPSGetPowerSourceDescription` dictionary bridging by transitioning to direct `IOPSGetProvidingPowerSourceType` string evaluation.
- **Timer Execution Efficiency**: Eliminated redundant nested `Task { @MainActor }` calls within main runloop telemetry timers.
- **Fixed-Buffer Safety**: Added safe UTF-8 prefix bounds checks to Darwin `proc_bsdinfo.pbi_comm` string parsing.

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
