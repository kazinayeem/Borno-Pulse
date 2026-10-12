# Borno Pulse — Feature Catalog & Module Documentation

This document provides a comprehensive inventory of all features implemented in **[Borno Pulse](https://github.com/kazinayeem/Borno-Pulse)**, detailing their capabilities, access paths, permissions, and operational constraints.

Repository: [https://github.com/kazinayeem/Borno-Pulse](https://github.com/kazinayeem/Borno-Pulse)

---

## 1. Hardware & Monitoring Engine

### Overview (`.overview`)
- **Capabilities**: High-level real-time summary cards for CPU load, Memory pressure, GPU utilization, Thermal status, Battery charge & rate, Storage capacity, and Network throughput.
- **Access**: Main Dashboard sidebar → **Overview** (default home screen).
- **Permissions**: None (Mach host APIs and IOKit).
- **Execution**: 100% offline & local.

### CPU Monitoring (`.cpu`)
- **Capabilities**: Overall CPU load percentage, per-core utilization bars (Performance vs. Efficiency cores), system load averages (1m, 5m, 15m), and Mach thread counts.
- **Access**: Main Dashboard sidebar → **CPU**.

### GPU & Neural Engine (`.gpu`)
- **Capabilities**: GPU device naming, Metal feature set support, live GPU core utilization percentage, and Apple Silicon Neural Engine (ANE) hardware status.
- **Access**: Main Dashboard sidebar → **GPU & Neural Engine**.

### Memory (`.memory`)
- **Capabilities**: Physical RAM breakdown (Active, Wired, Compressed, Free), memory pressure level (Normal, Warn, Critical), virtual memory swap usage, and page-in/page-out rates.
- **Access**: Main Dashboard sidebar → **Memory**.

### Temperature & Fans (`.sensors`)
- **Capabilities**: Thermal envelope status, CPU/GPU thermal diode sampling, fan RPM readouts (when available), and thermal throttling alerts.
- **Access**: Main Dashboard sidebar → **Temperature & Fans**.

### Storage (`.storage`)
- **Capabilities**: APFS volumes, total capacity, available space, purgeable space breakdown, and mount point overview.
- **Access**: Main Dashboard sidebar → **Storage**.

### Network (`.network`)
- **Capabilities**: Active network interface detection (Wi-Fi, Ethernet, Thunderbolt Bridge), live upload/download bandwidth gauges, cumulative bytes sent/received, and BSD `getifaddrs` inspection.
- **Access**: Main Dashboard sidebar → **Network**.

### Battery & Energy (`.battery`)
- **Capabilities**:
  - `BatteryEstimationService`: Real-time empirical slope calculation ($\%/hr$), lithium-ion non-linear charging taper compensation, remaining time projections, and confidence ratings.
  - Hardware power telemetry: live DC cell voltage (V), current flow (A), and system power draw / charging rate in Watts (W).
  - Health & cycle count diagnostics (design capacity comparison).
  - 7-day historical Swift Charts graphing charge trajectories.
- **Access**: Main Dashboard sidebar → **Battery & Energy**.

---

## 2. Developer & Network Toolkit

### Port Manager (`.portManager`)
- **Capabilities**: Real-time scanning of local listening TCP sockets (`*:3000`, `127.0.0.1:8000`, `[::1]:8080`), automatic dev server classification (Vite, Next.js, Django, FastAPI, Postgres, Redis), Docker port correlation, conflict detection, secret flag redaction, and CSV export.
- **Access**: Main Dashboard sidebar → **Port Manager**.

### Developer Toolbox (`.developerToolbox`)
- **Capabilities**:
  - **JSON Studio**: Pretty formatter, minifier, interactive tree viewer, syntax error locator, CSV exporter, and side-by-side JSON diff.
  - **JWT Inspector**: Decode claims, header, and payload with signature format verification and token expiration audit.
  - **API Client**: Lightweight HTTP request runner supporting GET, POST, PUT, DELETE with automated bearer token masking.
  - **Docker Dashboard**: Local Docker daemon socket check, container listing, CPU/RAM stats, and start/stop/restart controls.
- **Access**: Main Dashboard sidebar → **Developer Toolbox**.

### Network Toolkit (`.networkToolkit`)
- **Capabilities**:
  - **Ping Latency**: ICMP ping graph with min/avg/max latency calculation.
  - **DNS Lookup**: Queries A, AAAA, CNAME, MX, TXT, and NS records.
  - **TLS/SSL Inspector**: Certificate subject, issuer, validity period, and expiration warnings.
  - **IP Diagnostics**: Local network interface address resolution.
- **Access**: Main Dashboard sidebar → **Network Toolkit**.

---

## 3. Productivity & File Tools

### Clipboard Manager (`.clipboard`)
- **Capabilities**: Opt-in clipboard history, automatic masking of sensitive patterns (passwords, credit cards, API keys), application exclusion list, search, and one-click copy.
- **Access**: Main Dashboard sidebar → **Clipboard Manager** or dedicated menu bar picker.

### Focus & Pomodoro (`.focusPomodoro`)
- **Capabilities**: 25-minute focus intervals with short (5m) and long (15m) break timers, daily/weekly streak tracking, and Screen Time synchronization.
- **Access**: Main Dashboard sidebar → **Focus & Pomodoro**.

### PDF Studio (`.pdfStudio`)
- **Capabilities**: 12 local PDF utilities:
  1. **Advanced PDF Editor**: Canvas editor with interactive shape drawing, text annotations, comments, image stamps, signatures, and thumbnails.
  2. **Images to PDF**: Convert PNG, JPEG, HEIC, TIFF, WebP into upright PDF documents.
  3. **Merge PDFs**: Reorder, rotate, and combine multiple documents.
  4. **Office to PDF**: Local Markdown and DOCX rendering to PDF.
  5. **Page Organizer**: Drag-and-drop page reordering, rotation, and deletion.
  6. **Splitter**: Page-by-page or custom range PDF splitting.
  7. **Extractor**: Extract selected page intervals into a new document.
  8. **Compressor**: Downsample images and optimize streams.
  9. **Local OCR**: Vision-based text layer generator for scanned documents.
  10. **Metadata Inspector & Sanitizer**: View properties and strip author metadata.
  11. **Export & Flatten**: Burn annotations into page content.
- **Access**: Main Dashboard sidebar → **PDF Studio**.

### File Tools (`.fileTools`)
- **Capabilities**: Image format converter, lossless compressor, batch resizer, and EXIF metadata viewer.
- **Access**: Main Dashboard sidebar → **File Tools**.

### Batch File Converter (`.batchConverter`)
- **Capabilities**: Multi-file batch processing queue supporting simultaneous conversion across image and document formats.
- **Access**: Main Dashboard sidebar → **Batch File Converter**.

---

## 4. Privacy, Safety & System Utilities

### Privacy & Security (`.privacySecurity`)
- **Capabilities**: Streaming file hasher (SHA-256, SHA-384, SHA-512, legacy MD5), metadata inspector, and macOS TCC permission audit.
- **Access**: Main Dashboard sidebar → **Privacy & Security**.

### Local Backup Helper (`.localBackup`)
- **Capabilities**: Folder backup profiles with Full, Incremental, and Mirror sync modes and SHA-256 integrity verification.
- **Access**: Main Dashboard sidebar → **Local Backup Helper**.

### Screen Time (`.screenTime`)
- **Capabilities**: Local foreground window tracking with daily application usage breakdown and category classification.
- **Access**: Main Dashboard sidebar → **Screen Time**.

### Storage Analytics (`.storageAnalytics`)
- **Capabilities**: Recursive directory scanner with squarified interactive treemaps, largest file finder, and category breakdown.
- **Access**: Main Dashboard sidebar → **Storage Analytics**.

### Process Monitor (`.processes`)
- **Capabilities**: Running process table with PID, process name, CPU%, RAM footprint, energy impact score, and termination controls.
- **Access**: Main Dashboard sidebar → **Processes**.

### Cache Cleaner (`.cleaner`)
- **Capabilities**: Safe user cache scanner, dry-run preview, and two-step purge for temporary files.
- **Access**: Main Dashboard sidebar → **Cache Cleaner**.

### Diagnostics (`.diagnostics`)
- **Capabilities**: Integrated system sanity check evaluating battery health, thermal throttling, swap usage, and disk space.
- **Access**: Main Dashboard sidebar → **Diagnostics**.

### Keep Running When Lid Is Closed / Clamshell Mode (`.clamshellMode`)
- **Capabilities**:
  - **Power Assertion Management**: Native IOKit power assertion (`kIOPMAssertionTypePreventUserIdleSystemSleep`) keeping background workloads running with the lid closed.
  - **Preset Durations & Custom Interval**: 1 hour, 2 hours, 3 hours, Until Stopped, or custom duration (hours and minutes) with real-time countdown timer.
  - **Hardware Readiness Audit Checklist**: Live verification of laptop hardware model, AC power connection (`IOPSGetProvidingPowerSourceType`), and external display connection (`CGGetOnlineDisplayList`).
  - **Official Clamshell Mode Verification**: Identifies whether the setup satisfies official Apple clamshell requirements (external display + AC power + input device).
  - **Workload Diagnostic Inspection**: Live status verification for Docker containers, local development servers (Vite, Next.js, Django, FastAPI), background processes, and macOS awake uptime.
  - **Thermal Safety Guidelines**: Best practices for ventilation and heat dissipation during closed-lid operation.
- **Access**: Main Dashboard sidebar → **Clamshell Mode**, Menu Bar Widget → **Actions** tab, or Quick Launcher (⌘K).

---

## 5. Global Utilities & Surfaces

### Settings (`.settings`)
- **Capabilities**: 9 full-coverage category tabs:
  1. *Appearance & Typography*: Light/Dark/System theme, font family selection, font scale presets.
  2. *Menu Bar & Widget*: Customize visible metrics tokens, ordering, and icon symbol.
  3. *General & System*: Launch at login, refresh intervals, dock icon behavior.
  4. *Clipboard*: Retention days, history limits, sensitive data masking toggles.
  5. *Alerts & Exclusions*: Threshold alerts for battery, CPU, RAM, and temperature.
  6. *PDF Studio & Files*: Default annotation colors, font size, stroke width.
  7. *Privacy & Security*: Telemetry permissions and data redaction rules.
  8. *Shortcuts & Diagnostics*: Global hotkeys for Quick Launcher and Clipboard.
  9. *Backup & Data Management*: Export preferences, import backups, and reset options.

### Quick Launcher Command Palette (⌘K)
- **Capabilities**: Keyboard-first fuzzy search across all 25 modules and system shortcuts.
- **Access**: Global hotkey **⌘K** or sidebar button.

### Menu Bar Utility Popover & Quick Actions Grid
- **Capabilities**: Compact multi-category status popover featuring:
  - **Audio**: System volume slider, mute toggle, and input/output device switching.
  - **Battery**: Real-time wattage, estimated time remaining, battery health, and charging trajectory.
  - **Hardware**: Mini CPU, GPU, RAM, and thermal load bars.
  - **Quick Actions Grid (21 System Actions)**: Responsive grid with circular icon backgrounds, hover states, confirmation dialogs for destructive actions (Empty Trash), and capability indicators:
    1. *Toggle Dark Mode*: Instant system appearance switch.
    2. *Keep Awake*: Sleep prevention toggle with visual active badge.
    3. *Clamshell Mode*: Direct launcher for Keep Running When Lid Is Closed.
    4. *Start Screen Saver*: Instant screensaver activation via CoreGraphics.
    5. *Clean Screen*: Blackout overlay for physical screen wiping.
    6. *Hide All Windows*: Show desktop toggle.
    7. *Toggle Dock Autohide*: Dock auto-hide state toggle.
    8. *Hide Desktop Icons*: Non-destructive Finder desktop icon toggle.
    9. *Lock Screen*: Immediate screen lock via SACLockScreenImmediate.
    10. *Keyboard Cleaning Mode*: Modal input-lock overlay.
    11. *Activity Monitor*: One-click launcher for macOS Activity Monitor.
    12. *System Settings*: One-click launcher for macOS System Settings.
    13. *Scan Cache*: Fast cache audit trigger.
    14. *Empty Trash*: Destructive action with explicit confirmation alert.
    15. *Refresh Metrics*: Immediate telemetry reload.
    16. *Toggle Focus*: Focus filter toggle.
    17. *Open Downloads*: Fast Finder navigation to `~/Downloads`.
    18. *Port Manager*: Quick jump to local port auditor.
    19. *Network Toolkit*: Quick jump to ping & DNS diagnostics.
    20. *Open Terminal*: Quick launch Terminal at current user home.
    21. *Hardware Notch*: Honest capability indicator explaining physical camera cutout behavior.
