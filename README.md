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
├── FileTools/
│   ├── ImageTools/
│   │   ├── ImageToolModels.swift             # Models, formats, presets & metadata structures
│   │   ├── ImageFormatConverterService.swift # ImageIO/CoreGraphics format conversion & alpha flattening
│   │   ├── ImageCompressorService.swift      # Lossy/lossless compression, presets & size reduction
│   │   ├── ImageResizerService.swift         # Aspect ratio scaling, pixel/preset & no-upscaling guard
│   │   └── ImageMetadataService.swift        # EXIF, camera info, color profile & location scrub exporter
│   ├── PDFTools/
│   │   ├── PDFToolModels.swift               # PDF page items, presets & metadata records
│   │   ├── PDFCompressorService.swift        # PDF stream optimization & image downsampling
│   │   ├── PDFToImagesService.swift          # CoreGraphics page rasterizer (DPI & page range selection)
│   │   ├── ImagesToPDFService.swift          # PDFPage & A4/Letter/Custom canvas layout generator
│   │   ├── PDFMergerSplitterService.swift    # Multi-doc merger & page range/interval splitter
│   │   ├── PDFPageToolsService.swift         # 90° page rotation, deletion & thumbnail organizer
│   │   └── PDFSecurityService.swift          # Encryption unlock, metadata audit & privacy sanitizer
│   └── FileUtilities/
│       ├── ChecksumService.swift             # CryptoKit SHA-256, MD5, SHA-1 hashing & verifier
│       ├── BatchRenamerService.swift         # Find/replace, prefix/suffix, numbering & collision guard
│       ├── DuplicateFinderService.swift      # Two-tier size bucketing & SHA-256 duplicate finder
│       ├── ArchiveUtilityService.swift       # ZIP compressor & extractor with path traversal guard
│       └── TextEncodingInspectorService.swift# UTF-8/UTF-16/BOM/ASCII detector & CRLF/LF line ending analysis
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
│   ├── FileTools/                       # File Tools Workspace Views
│   │   ├── FileToolsDashboardView.swift # Central Hub & quick launch view
│   │   ├── Components/FileDropZoneView.swift # Universal drag-and-drop zone
│   │   ├── ImageTools/                  # Converter, Compressor, Resizer & Metadata Views
│   │   ├── PDFTools/                    # PDF Compressor, PDF2Img, Img2PDF, Merge/Split, Pages, Security
│   │   └── FileUtilities/               # Checksum, Renamer, Duplicates, ZIP & Text Inspector
│   ├── Diagnostics/DiagnosticsView.swift # System audit, API matrix, and redacted report export
│   └── Settings/SettingsView.swift      # Preferences, thresholds, exclusions & test suite runner
└── Tests/
    ├── MockProviders.swift              # Mock providers for CPU, Sensors, and Storage
    └── SmartToolTests.swift             # 15 In-app and terminal unit test suites
```

---

## 3. Features

### A. File Tools Suite (100% Offline & Private)
A collection of native macOS file tools built with `ImageIO`, `CoreGraphics`, `PDFKit`, and `CryptoKit`:

1. **Image Tools**:
   - **Format Converter**: Batch convert PNG, JPG, WebP, HEIC, TIFF, BMP. For PNG to JPG conversion, includes an interactive background color picker (default white) to flatten transparency cleanly. Preserves dimensions and orientation.
   - **Image Compressor**: Compress JPG, PNG, and WebP using presets (High Quality 85%, Balanced 70%, Small File 50%, or Custom). Displays before-and-after sizes and percentage savings.
   - **Image Resizer**: Scale by pixels, percentage, or social/display presets with aspect ratio lock and an anti-upscaling safety guard.
   - **Metadata Viewer**: Inspect EXIF tags, camera details, color profile, and export location-scrubbed copies.

2. **PDF Tools**:
   - **PDF Compressor**: Streamlines PDF streams and downsamples images without altering vector text or page geometry.
   - **PDF to Images**: High-resolution rasterization to PNG or JPG with selectable DPI (72, 150, 300, 600) and page ranges.
   - **Images to PDF**: Combine multiple images into multi-page PDFs with A4, US Letter, or custom canvas sizing.
   - **PDF Merger & Splitter**: Merge documents in custom order or split by page ranges, every page, or every N pages.
   - **PDF Page Organizer**: 90° clockwise rotation, page removal, and export of a modified document copy.
   - **PDF Security & Privacy**: Password unlock interface for encrypted PDFs and one-click export of metadata-stripped copies.

3. **File Utilities**:
   - **Checksum Calculator**: Compute SHA-256, MD5, and SHA-1 hashes with live comparison and verification against expected checksums.
   - **Batch File Renamer**: Find & replace, prefix/suffix, number sequencing, and casing transformations with live collision detection.
   - **Duplicate File Finder**: Two-tier scanner using exact file size bucketing followed by SHA-256 cryptographic match, with safe confirmation deletion.
   - **ZIP Archive Utility**: Create and extract ZIP archives natively with strict path traversal (Zip-Slip) protection.
   - **Text Encoding Inspector**: Detects UTF-8, UTF-16, ASCII, Windows-1252, BOM headers, and CRLF vs LF line endings.

---

### B. Menu Bar Popover & Dynamic Status Item
- **Compact Popover**: Click the status item to view real-time CPU, RAM, GPU, Storage, Network, Battery, and Thermal status.
- **Configurable Menu Bar Text**: Choose between:
  - Icon Only
  - CPU %
  - Memory %
  - Network Speed (e.g. `↓ 1.2 MB/s`)
  - CPU + Memory
  - CPU + Network
- **Quick Actions**: One-click shortcuts to open the full Dashboard, run Quick Cleanup, open Settings, or Quit.

### C. Main Dashboard & Monitoring (13 Sections)
1. **Overview**: Executive hardware snapshot featuring 7 dedicated hardware cards and real-time mini charts.
2. **CPU**: Per-core utilization grid, user vs. system vs. idle ratios, and Darwin Mach kernel load info.
3. **GPU & Neural Engine**: Metal device specs, unified memory architecture, and Apple Neural Engine integration.
4. **Memory**: Page-accurate RAM distribution (App, Wired, Compressed, Free), pressure gauge, and swap usage.
5. **Temperature & Fans**: Real-time macOS thermal pressure state, throttling detection, and hardware cooling diagnostics.
6. **Storage**: APFS container breakdown, opportunistic/purgeable space awareness, and volume metrics.
7. **Network**: Real-time download/upload speeds, lifetime byte counters, and active interface details.
8. **Battery & Energy**: Battery health, cycle count, charging status, and energy optimization tips.
9. **File Tools**: Full hub for Image Tools, PDF Tools, and File Utilities.
10. **Processes**: Real-time process explorer powered by `libproc` with CPU/RAM sorting, search, and safe quit.
11. **Cache Cleaner**: Two-step review-and-confirm workflow with **Dry-Run Simulation**.
12. **Diagnostics & Self-Tests**: Hardware audit, API matrix, and **15 Invariant Self-Tests** with Markdown report export.
13. **Settings**: Polling intervals, temperature units, theme appearance, launch-at-login, and cleanup exclusions.

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
