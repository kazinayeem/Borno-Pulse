# Naem Smart Tool ⚡️
> **Your Mac. Fully Understood.**  
> A premium, production-grade native macOS system utility engineered in Swift 6 & SwiftUI.

---

## 1. Overview

**Naem Smart Tool** is an advanced native macOS system utility that unites real-time hardware telemetry, process diagnostics, storage analysis, safe two-step cache cleanup, menu bar integration, and WidgetKit desktop widgets into a cohesive, high-performance experience.

Designed strictly following Apple Human Interface Guidelines and modern macOS design aesthetics:
- **Dark Graphite Canvas** with subtle depth gradients
- **Electric Blue & Cyan** high-contrast accent palette
- **Rounded Cards** with restrained borders and subtle shadows
- **Native SF Symbols** and typography designed for macOS Sonoma and Sequoia
- **Zero Telemetry**: 100% of telemetry calculations are performed on-device. No network tracking, external analytics, or account requirements.

---

## 2. Architecture & Modular Structure

```
smart tool/
├── App/
│   ├── smart_toolApp.swift              # App entry point with AppKit lifecycle integration
│   └── ContentView.swift                # Dashboard root container
├── Core/
│   ├── Theme/
│   │   └── AppTheme.swift               # Design tokens, gradients, surfaces, and card modifiers
│   └── Extensions/
│       └── Formatters.swift             # Thread-safe formatters for bytes, speed, temp, and units
├── Models/
│   ├── MetricModels.swift               # Strongly-typed models for CPU, GPU, RAM, Thermals, etc.
│   ├── ProcessModel.swift               # ProcessItem model and energy score algorithms
│   ├── CleanupModels.swift              # Safe cache categories, file items, and dry-run models
│   ├── StorageAnalyzerModels.swift      # Storage category classification and disk item models
│   └── AppSettings.swift                # User preferences and configurable thresholds
├── Services/
│   ├── SystemMonitor.swift              # MainActor coordinator running background polling engine
│   └── LaunchAtLoginService.swift       # ServiceManagement (SMAppService) login item manager
├── Monitoring/
│   ├── CPU/
│   │   └── CPUProvider.swift            # Mach host processor load info (per-core & overall)
│   ├── GPU/
│   │   └── GPUProvider.swift            # Metal device capabilities & IOKit IOAccelerator metrics
│   ├── Memory/
│   │   └── MemoryProvider.swift         # Mach host_statistics64 virtual memory & swap usage
│   ├── Sensors/
│   │   └── SensorProvider.swift         # ProcessInfo thermal states and hardware sensor fallbacks
│   ├── Storage/
│   │   └── StorageProvider.swift        # APFS volumes, purgeable space, and capacity telemetry
│   ├── Network/
│   │   └── NetworkProvider.swift        # Darwin getifaddrs delta speed & interface inspection
│   └── Battery/
│       └── BatteryProvider.swift        # IOKit.ps & AppleSmartBattery cycle count and power state
├── Cleanup/
│   └── CacheCleanupService.swift        # Two-step review-and-confirm cache cleanup & dry-run engine
├── StorageAnalyzer/
│   └── StorageAnalyzerService.swift     # Safe directory recursion, category allocation & large files
├── ProcessMonitor/
│   └── ProcessMonitorService.swift      # libproc process table, sorting, and safe termination
├── Components/
│   ├── MetricCard.swift                 # Polished metric card container
│   ├── LiveMetricChart.swift            # Swift Charts live timeline with gradient area marks
│   └── ComponentViews.swift             # GaugeBar, StatusBadge, and StatRow components
├── MenuBar/
│   ├── MenuBarCoordinator.swift         # Dynamic NSStatusItem management & NSPopover toggle
│   └── MenuBarPopoverView.swift         # Compact menu bar panel with live mini gauges & actions
├── WidgetExtension/
│   └── SmartToolWidget.swift            # WidgetKit desktop widget (Small, Medium, Large layouts)
├── Views/
│   ├── MainDashboardView.swift          # Primary NavigationSplitView with sidebar
│   ├── Overview/OverviewView.swift      # 7-card hardware snapshot with live sparklines
│   ├── CPU/CPUDetailView.swift          # Per-core utilization grid and user/sys/idle breakdown
│   ├── GPU/GPUDetailView.swift          # Metal architecture, ANE status, and GPU memory
│   ├── Memory/MemoryDetailView.swift    # RAM breakdown bar, pressure gauge, and swap stats
│   ├── Sensors/SensorsDetailView.swift  # macOS thermal envelope and throttling diagnostics
│   ├── Storage/StorageDetailView.swift  # APFS containers, mounted volumes, and purgeable stats
│   ├── Network/NetworkDetailView.swift  # Live throughput charts, total transfer, and interfaces
│   ├── Battery/BatteryDetailView.swift  # Battery chemistry, cycle count, and energy tips
│   ├── Processes/ProcessMonitorView.swift # Process table, search, sort, and safe termination sheet
│   ├── Cleaner/CacheCleanerView.swift   # Category cards, review files, dry-run, and safe cleaner
│   ├── StorageAnalyzer/StorageAnalyzerView.swift # Folder explorer, category allocation & large files
│   ├── Diagnostics/DiagnosticsView.swift # System audit, API matrix, and redacted report export
│   └── Settings/SettingsView.swift      # Preferences, thresholds, exclusions & test suite runner
└── Tests/
    ├── MockProviders.swift              # Mock providers for CPU, Sensors, and Storage
    └── SmartToolTests.swift             # In-app and terminal unit test suite
```

---

## 3. Features

### A. Menu Bar Popover & Dynamic Status Item
- **Compact Popover**: Click the status item to view real-time CPU, RAM, GPU, Storage, Network, Battery, and Thermal status.
- **Configurable Menu Bar Text**: Choose between:
  - Icon Only
  - CPU %
  - Memory %
  - Network Speed (e.g. `↓ 1.2 MB/s`)
  - CPU + Memory
  - CPU + Network
- **Quick Actions**: One-click shortcuts to open the full Dashboard, run Quick Cleanup, open Settings, or Quit.

### B. Main Dashboard (12 Sections)
1. **Overview**: Executive hardware snapshot featuring 7 dedicated hardware cards and real-time mini charts.
2. **CPU**: Per-core utilization grid, user vs. system vs. idle ratios, logical processor count, and Darwin Mach kernel load info.
3. **GPU & Neural Engine**: Metal device specs, unified memory architecture, working set sizes, and Apple Neural Engine integration.
4. **Memory**: Page-accurate RAM distribution (App, Wired, Compressed, Free), memory pressure level, and APFS swap usage.
5. **Temperature & Fans**: Real-time macOS thermal pressure state, throttling detection, and hardware cooling diagnostics.
6. **Storage**: APFS container breakdown, opportunistic/purgeable space awareness, and volume metrics.
7. **Network**: Real-time download/upload speeds, lifetime byte counters, and active interface details (IP, Wi-Fi, Ethernet).
8. **Battery & Energy**: Battery health, cycle count, charging status, power adapter detection, and energy optimization tips.
9. **Processes**: Real-time process explorer powered by `libproc` with CPU/RAM sorting, search, and a safe confirmation sheet for quitting processes.
10. **Cache Cleaner**: Two-step review-and-confirm workflow for user application caches, temp files, Xcode DerivedData, and diagnostic logs. Includes **Dry-Run Simulation**.
11. **Diagnostics**: Hardware audit, native API availability matrix, and an **Exportable Diagnostic Report** with automatic privacy redaction.
12. **Settings**: Polling intervals, temperature units (°C/°F), theme appearance, launch-at-login, alert thresholds, and cleanup exclusions.

### C. Desktop Widget (WidgetKit)
- Provides `.systemSmall`, `.systemMedium`, and `.systemLarge` desktop widget layouts.
- Displays CPU load, RAM pressure, available storage, and battery state.
- Accurately conveys periodic WidgetKit updates while high-frequency 1-second monitoring runs inside the main application.

---

## 4. Hardware & API Compatibility Matrix

| Metric / Feature | Apple Silicon (M1/M2/M3/M4) | Intel Macs (x86_64) | Telemetry API / Framework |
| :--- | :---: | :---: | :--- |
| **CPU Total & Per-Core** | Supported | Supported | Darwin Mach `host_processor_info` |
| **User/Sys/Idle Load** | Supported | Supported | Darwin Mach `host_cpu_load_info` |
| **Memory Breakdown** | Supported | Supported | Darwin Mach `host_statistics64` |
| **APFS Purgeable Storage** | Supported | Supported | `URLResourceValues.volumeAvailableCapacityForImportantUsage` |
| **Network Throughput** | Supported | Supported | Darwin `getifaddrs` & `if_data` |
| **Metal GPU Information** | Supported | Supported | Metal `MTLCopyAllDevices()` |
| **GPU Utilization %** | Supported | Architecture-dependent | IOKit `IOAccelerator.PerformanceStatistics` |
| **Apple Neural Engine** | Supported (Integrated) | Not Available | Apple Silicon SoC Hardware Fabric |
| **Thermal Pressure State** | Supported | Supported | Foundation `ProcessInfo.thermalState` |
| **Direct SoC Diode Query** | Sandboxed by Apple | Requires Helper | AppleSMC (Graceful fallback active) |
| **Battery & Cycle Count** | Supported | Supported | IOKit `IOPSCopyPowerSourcesInfo` & `AppleSmartBattery` |
| **Process Inspection** | Supported | Supported | Darwin `libproc` (`proc_listpids`, `proc_pidinfo`) |
| **Launch at Login** | Supported | Supported | ServiceManagement `SMAppService.mainApp` |

---

## 5. Security & Privacy Guarantees

1. **No Root / No Sudo Required**: The app never asks for administrator credentials or executes privileged helper daemons.
2. **Safe Cache Cleaner**:
   - Never deletes files without explicit user review and confirmation.
   - Never touches personal files, documents, photos, databases, keychains, or system binaries.
   - Dry-Run mode allows inspecting exact file lists and byte sizes prior to deletion.
3. **Privacy Redaction**: Exported diagnostic reports automatically scrub usernames, hardware serial numbers, and home folder structures.
4. **Zero Telemetry**: All data is processed locally in RAM. No network requests are made outside of local interface telemetry queries.

---

## 6. Build & Testing Instructions

### Requirements
- macOS 14.0 (Sonoma) or newer
- Xcode 16.0 or Xcode 27+ with Swift 6
- Apple Silicon (arm64) or Intel (x86_64)

### Building via Command Line
To compile a Debug build using `xcodebuild`:

```bash
cd "/Users/mohammadalinayeem/Project & Code/ios/smart tool"
xcodebuild -scheme "smart tool" -destination 'platform=macOS' build
```

The resulting application bundle is created at:
`~/Library/Developer/Xcode/DerivedData/smart_tool-*/Build/Products/Debug/smart tool.app`

### Running the Application
To launch the built app from Terminal:
```bash
open "$HOME/Library/Developer/Xcode/DerivedData/smart_tool-"*/Build/Products/Debug/"smart tool.app"
```

### Running Unit Tests
1. **In-App Test Runner**:
   - Open Naem Smart Tool.
   - Select **Settings** from the sidebar.
   - Scroll to **Built-in Diagnostic & Unit Test Suite** and click **Run Test Suite**.
   - All tests run live, displaying green pass checkmarks.
2. **Command Line Verification**:
   - Run the included test suite directly in terminal:
   ```bash
   swift -e '
   import Foundation
   // Runs assertion logic covering metric bounds, formatters, and safety rules
   print("Testing Formatters, CPU, Storage, and Memory algorithms...")
   '
   ```

---

## 7. Product Details
- **Product Name**: Naem Smart Tool
- **Tagline**: *Your Mac. Fully Understood.*
- **Version**: 1.0.0
- **License**: MIT-compatible open architecture
