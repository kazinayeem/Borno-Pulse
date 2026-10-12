# Borno Pulse ⚡️

<p align="center">
  <strong>Smart Mac Utilities & System Monitor</strong><br>
  <em>A native, production-grade macOS Super Utility Suite engineered in Swift 6 & SwiftUI.</em><br>
  Provided by <strong><a href="https://bornosoft.bd">BornoSoft</a></strong> • Free & Open Source under the <a href="LICENSE">MIT License</a>.
</p>

<p align="center">
  <a href="https://github.com/kazinayeem/Borno-Pulse"><img src="https://img.shields.io/badge/Repository-kazinayeem%2FBorno--Pulse-blue.svg" alt="GitHub Repository"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT License"></a>
  <a href="docs/BUILDING.md"><img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B%20%7C%20Apple%20Silicon%20%26%20Intel-purple.svg" alt="Platform"></a>
  <a href="docs/SCREEN_INVENTORY.md"><img src="https://img.shields.io/badge/Swift-6.0%20Strict%20Concurrency-orange.svg" alt="Swift 6"></a>
</p>

<p align="center">
  <a href="https://github.com/kazinayeem/Borno-Pulse/raw/main/releases/Borno-Pulse-macOS.dmg">
    <img src="https://img.shields.io/badge/⚡️_Download_DMG-Direct_macOS_Installer-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="Direct Download Borno Pulse DMG">
  </a>
  &nbsp;
  <a href="https://github.com/kazinayeem/Borno-Pulse/releases">
    <img src="https://img.shields.io/badge/All_Releases-GitHub-333333?style=for-the-badge&logo=github&logoColor=white" alt="GitHub Releases">
  </a>
</p>

---

## 1. Overview

**Borno Pulse** brings professional hardware telemetry, developer utilities, storage treemap analytics, cache cleanup, offline image & PDF tools, screen time tracking, and an interactive menu bar utility popover into a unified native macOS experience.

Engineered with an **offline-first philosophy**, Borno Pulse contacts no remote analytics servers, performs no cloud telemetry, and keeps all sensitive user clipboard data, backups, and metrics strictly on your local device.

### Highlights
- 📊 **Hardware Telemetry Engine**: Per-core CPU load, Metal GPU utilization, Mach virtual memory pressure, swap footprint, and APFS purgeable volume tracking.
- 🔋 **Empirical Battery Estimation**: Real-time power draw in Watts, empirical decay slope ($\%/hr$), lithium-ion saturation curve compensation, and 7-day retention persistence.
- 💻 **Clamshell Mode (Lid-Closed Operation)**: Native IOKit sleep assertions keeping Docker, local servers, and background scripts running with the lid closed, complete with duration presets, countdown timer, hardware audit, and workload verification.
- 🌐 **Developer & Port Manager**: BSD listening socket auditor (`*:3000`, `127.0.0.1:8000`), dev server detection (Vite, Next.js, Django, FastAPI), Docker port correlation, JSON studio, JWT claim decoding, and ICMP ping latency graphs.
- 📄 **Offline PDF Studio**: 12 local tools including an interactive PDF Canvas Editor, Images to PDF, Merge, Split, Lossless Compression, and Apple Neural Engine Vision OCR.
- 📋 **Privacy-Preserving Clipboard**: Local clipboard history with automated credential & API key masking.
- ⚡️ **Menu Bar Utility Widget & Quick Actions**: Compact 4-category menu bar popover (Audio Mixer, Battery Telemetry, Hardware Load, 21-Action Icon Grid) with customizable status item metric tokens.
- 🎨 **Typography & Appearance Engine**: Live Light/Dark/System theme switching, font family selection (SF Pro, New York, SF Mono, Menlo, Helvetica Neue), and font scaling presets.

---

## 2. Download & Installation

### Option 1: Direct DMG Download (One-Click)

<p align="center">
  <a href="https://github.com/kazinayeem/Borno-Pulse/raw/main/releases/Borno-Pulse-macOS.dmg">
    <img src="https://img.shields.io/badge/⬇️_Click_to_Download-Borno--Pulse--macOS.dmg_(17_MB)-2ea44f?style=for-the-badge&logo=apple&logoColor=white" alt="Click to Download DMG">
  </a>
</p>

| Package | Format | Architecture | Direct Download |
|:---|:---:|:---:|:---:|
| **Borno Pulse Disk Image** | `.dmg` (17 MB) | Universal (`arm64` Apple Silicon & `x86_64` Intel) | [**⬇️ Direct Download Borno-Pulse-macOS.dmg**](https://github.com/kazinayeem/Borno-Pulse/raw/main/releases/Borno-Pulse-macOS.dmg) |
| **GitHub Releases Mirror** | Release Assets | Universal (`arm64` Apple Silicon & `x86_64` Intel) | [**GitHub Releases Portal**](https://github.com/kazinayeem/Borno-Pulse/releases) |

#### Quick Install Steps:
1. Click the [**Download Borno-Pulse-macOS.dmg**](https://github.com/kazinayeem/Borno-Pulse/raw/main/releases/Borno-Pulse-macOS.dmg) button above to download directly.
2. Double-click to open the DMG disk image.
3. Drag the **Borno Pulse** app icon into the **Applications** folder shortcut.
4. Launch **Borno Pulse** from Launchpad, Spotlight, or Applications.

> [!TIP]
> **First-Launch Gatekeeper Notice:** For direct downloads on macOS Sequoia (15.x) or Sonoma (14.x), right-click (or Control-click) **Borno Pulse.app** in `/Applications` and select **Open**, or run the following command in Terminal to clear quarantine:
> ```bash
> xattr -cr "/Applications/Borno Pulse.app"
> ```

---

### Option 2: Build & Install via Script

If you have Xcode installed, compile the universal binary and install directly into `/Applications` with one command:

```bash
git clone https://github.com/kazinayeem/Borno-Pulse.git
cd Borno-Pulse
./scripts/package-release.sh --install
```

---

## 3. Visual Tour & Screenshot Gallery

Every screenshot below was captured programmatically from the running, compiled application across **Light Mode** and **Dark Mode** via [`scripts/capture-screenshots.sh`](scripts/capture-screenshots.sh).

### Main Dashboard (Overview)
| Light Mode | Dark Mode |
|:---:|:---:|
| ![Borno Pulse Overview in Light Mode](screenshots/light/overview.png) | ![Borno Pulse Overview in Dark Mode](screenshots/dark/overview.png) |

### Menu Bar Utility Widget
| Light Widget | Dark Widget |
|:---:|:---:|
| ![Menu Bar Widget Light](screenshots/widget/light-widget.png) | ![Menu Bar Widget Dark](screenshots/widget/dark-widget.png) |

### Hardware Telemetry, Clamshell & Developer Tools
| Category | Light Appearance | Dark Appearance |
|:---|:---:|:---:|
| **CPU Monitoring** | ![CPU Light](screenshots/light/cpu.png) | ![CPU Dark](screenshots/dark/cpu.png) |
| **Clamshell Mode** | ![Clamshell Light](screenshots/light/clamshell_mode.png) | ![Clamshell Dark](screenshots/dark/clamshell_mode.png) |
| **Port Manager** | ![Port Manager Light](screenshots/light/port_manager.png) | ![Port Manager Dark](screenshots/dark/port_manager.png) |
| **PDF Studio** | ![PDF Studio Light](screenshots/light/pdf_studio.png) | ![PDF Studio Dark](screenshots/dark/pdf_studio.png) |
| **Settings & Typography** | ![Settings Light](screenshots/light/settings.png) | ![Settings Dark](screenshots/dark/settings.png) |

*Full visual catalog of all 35 screens and 80 image assets available in [`docs/SCREEN_INVENTORY.md`](docs/SCREEN_INVENTORY.md).*

---

## 4. Implemented Features & Architecture

Borno Pulse includes **25 dedicated navigation sections** and system tools:

```
smart tool/
├── App/
│   └── smart_toolApp.swift              # App entry point, lifecycle, CLI argument router
├── Views/
│   ├── MainDashboardView.swift          # Primary SplitView navigation and command palette
│   ├── Overview/OverviewView.swift      # Real-time hardware telemetry dashboard
│   ├── CPU/CPUDetailView.swift          # Core utilization and load averages
│   ├── GPU/GPUDetailView.swift          # Metal capabilities and ANE status
│   ├── Memory/MemoryDetailView.swift    # RAM pressure, wired memory, and swap
│   ├── Battery/BatteryDetailView.swift  # Wattage, voltage, empirical slope, 7-day history
│   ├── Sensors/SensorsDetailView.swift  # Thermal diode envelopes and fan speeds
│   ├── Storage/StorageDetailView.swift  # APFS capacity and purgeable space
│   ├── Network/NetworkDetailView.swift  # Throughput gauges and BSD getifaddrs
│   ├── Settings/SettingsView.swift      # 9-tab preferences and typography controls
│   └── FileTools/                       # PDF Studio, format converters, and compressors
├── MenuBar/
│   ├── MenuBarCoordinator.swift         # StatusItem button and transient popover manager
│   └── MenuBarPopoverView.swift         # 4-category popover (Audio, Battery, Hardware, Actions)
├── DeveloperTools/
│   ├── PortManager/                     # Local socket scanner, dev server classifier, Docker
│   ├── JSON/                            # Formatter, minifier, interactive tree, and diff
│   ├── JWT/                             # Claim decoding and expiration audit
│   ├── HTTPClient/                      # Local API runner with secret masking
│   └── Docker/                          # Container status and lifecycle controls
├── Services/
│   ├── SystemMonitor.swift              # Background telemetry coordinator
│   ├── BatteryEstimationService.swift   # Slopes, non-linear saturation, and predictions
│   └── ScreenshotAutomationService.swift# Full app automated Retina screenshot capture
└── Tests/
    └── SmartToolTests.swift             # 854+ automated regression and invariant checks
```

*For in-depth per-feature descriptions and access instructions, see [`docs/FEATURES.md`](docs/FEATURES.md).*

---

## 5. System Requirements

- **Operating System**: macOS 14.0 (Sonoma) or macOS 15+ (Sequoia)
- **Architecture**: Universal binary supporting both **Apple Silicon** (`arm64`, M1/M2/M3/M4) and **Intel** (`x86_64`)
- **Toolchain**: Xcode 15.0+ or Xcode 16+
- **Language Standard**: Swift 5.9 / Swift 6.0 with strict concurrency checks enabled
- **External Dependencies**: Zero third-party dependencies; uses only Apple native frameworks (`SwiftUI`, `AppKit`, `IOKit`, `Metal`, `PDFKit`, `Vision`).

---

## 6. Building from Source

### 1. Clone the Repository
```bash
git clone https://github.com/kazinayeem/Borno-Pulse.git
cd Borno-Pulse
```

### 2. Build via Xcode
```bash
open "smart tool.xcodeproj"
```
Select the **`smart tool`** scheme and choose **`My Mac`** as the run destination. Press **⌘R** to build and run.

### 3. Build via Command Line
```bash
# Debug build
xcodebuild -project "smart tool.xcodeproj" \
           -scheme "smart tool" \
           -destination "platform=macOS" \
           -configuration Debug \
           build

# Release build
xcodebuild -project "smart tool.xcodeproj" \
           -scheme "smart tool" \
           -destination "platform=macOS" \
           -configuration Release \
           build
```

### 4. Run Automated Invariant Tests
```bash
APP_BIN=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "smart tool" -type f -perm +111 -path "*/smart tool.app/Contents/MacOS/*" | head -n 1)
"$APP_BIN" --run-tests
```

### 5. Run Screenshot Automation
```bash
./scripts/capture-screenshots.sh
```

### 6. Package DMG Installer & Install
```bash
# Package universal DMG and ZIP into dist/
./scripts/package-release.sh

# Or compile, package, and install to /Applications
./scripts/package-release.sh --install
```

*Full build, signing, and packaging documentation is available in [`docs/BUILDING.md`](docs/BUILDING.md).*

---

## 7. Usage Guide

- **Opening the Dashboard**: Click the Borno Pulse Dock icon or press **⌘O** from the menu bar widget.
- **Command Palette (⌘K)**: Press **⌘K** anywhere to open the Quick Launcher search across all 25 system modules.
- **Menu Bar Utility**: Click the gauge icon in your macOS menu bar to view the 4-category popover.
- **Customizing Metrics**: Navigate to **Settings → Menu Bar & Widget** to add, remove, or reorder the live status item tokens.
- **Appearance & Typography**: Navigate to **Settings → Appearance & Typography** to switch themes or select your preferred font family and scale.
- **Quitting the Application**: Choose **Borno Pulse → Quit Borno Pulse** (**⌘Q**) or click Quit from the menu bar widget actions.

---

## 8. Privacy & Security

Borno Pulse is designed with a **100% local-first architecture**:
- **Zero Remote Telemetry**: No third-party analytics SDKs, trackers, or remote telemetry.
- **Sensitive Credential Protection**: Automated regex redaction for passwords, API keys, and bearer tokens in Clipboard and Port Manager.
- **Local Storage Only**: All settings and history reside strictly inside your user application support directory.

*Read our detailed policy in [`docs/PRIVACY.md`](docs/PRIVACY.md).*

---

## 9. Contributing

Contributions are welcome! Whether you are improving telemetry accuracy, adding new developer tools, or refining UI typography, please review our guidelines:
1. Review [`CONTRIBUTING.md`](CONTRIBUTING.md) for branch guidelines and commit styles.
2. Read the [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
3. Ensure all automated tests pass before opening a Pull Request (`"$APP_BIN" --run-tests`).

---

## 10. License

This project is licensed under the **MIT License**. See the [`LICENSE`](LICENSE) file for complete details.

---

## 11. Developer & Founder Profile

<p align="center">
  <img src="https://avatars.githubusercontent.com/u/85398213?v=4" width="110" height="110" style="border-radius: 50%; border: 3px solid #007AFF;" alt="Mohammad Ali Nayeem"><br>
  <strong>Mohammad Ali Nayeem</strong><br>
  <em>Software Engineer</em><br>
  <em>B.Sc in SWE, Daffodil International University</em><br>
  <strong>Founder of <a href="https://bornosoft.bd">BornoSoft</a></strong>
</p>

<p align="center">
  <a href="https://github.com/kazinayeem"><img src="https://img.shields.io/badge/GitHub-@kazinayeem-181717?style=flat-square&logo=github&logoColor=white" alt="GitHub"></a>
  &nbsp;
  <a href="https://bornosoft.bd"><img src="https://img.shields.io/badge/Website-bornosoft.bd-007AFF?style=flat-square&logo=safari&logoColor=white" alt="Website"></a>
</p>

---

## 12. Support & Attribution

- **BornoSoft**: [https://bornosoft.bd](https://bornosoft.bd)
- **Repository**: [https://github.com/kazinayeem/Borno-Pulse](https://github.com/kazinayeem/Borno-Pulse)
- **Issue Tracker**: [https://github.com/kazinayeem/Borno-Pulse/issues](https://github.com/kazinayeem/Borno-Pulse/issues)
- **Pull Requests**: [https://github.com/kazinayeem/Borno-Pulse/pulls](https://github.com/kazinayeem/Borno-Pulse/pulls)
- **Discussions**: [https://github.com/kazinayeem/Borno-Pulse/discussions](https://github.com/kazinayeem/Borno-Pulse/discussions)

