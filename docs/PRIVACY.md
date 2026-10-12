# Privacy & Security Architecture

**[Borno Pulse](https://github.com/kazinayeem/Borno-Pulse)** is engineered from the ground up to respect user privacy and adhere to a strict **offline-first** design philosophy.

Repository: [https://github.com/kazinayeem/Borno-Pulse](https://github.com/kazinayeem/Borno-Pulse)

---

## 1. Zero External Telemetry

- **No Remote Analytics**: Borno Pulse contains no tracking pixels, advertising frameworks, analytics SDKs (e.g. Firebase, Mixpanel, Google Analytics), or remote error reporting services (e.g. Sentry).
- **No Network Dial-Home**: The application never contacts external servers to report usage statistics, crash logs, or system hardware identifiers.
- **Offline Reliability**: Every monitoring gauge, file converter, PDF tool, cryptographic hasher, and port auditor operates completely offline without requiring an active internet connection.

---

## 2. Local-Only Data Storage

All data created or processed by Borno Pulse is stored strictly on your local Mac:

- **Preferences & Settings**: Stored in native macOS `UserDefaults` (`~/Library/Preferences/com.naem.smart-tool.plist`).
- **Clipboard History**: If enabled, history entries are stored in a local, unshared SQLite database or JSON store located inside your user application support directory.
- **Battery History**: 7-day power telemetry samples are saved to a local JSON cache with automatic 7-day retention trimming.
- **Backup Helper Profiles**: Stored as plain local JSON configuration files. No cloud synchronization is performed unless you manually choose a synced folder destination (such as iCloud Drive).

---

## 3. Sensitive Data Redaction & Masking

Borno Pulse includes proactive defense mechanisms against accidental disclosure of credentials:

- **Clipboard Secret Masking**: The Clipboard Manager automatically pattern-matches passwords, credit cards, private keys, and bearer tokens, masking sensitive text before display.
- **Port Manager Redaction**: Process command line arguments scanned by `PortScannerService` are sanitized to redact sensitive flags (e.g. `--password=...`, `-p secret`, `token=...`).
- **HTTP Client Secret Protection**: Authorization headers and bearer tokens entered in the Developer Toolbox are masked in logs and exportable snapshots.

---

## 4. macOS Permissions & System Privileges

Borno Pulse requests only the minimum system permissions necessary to deliver its core features:

| Permission | Purpose | Optional / Required |
|------------|---------|---------------------|
| **Notifications** | Alerts for low battery, full charge, high thermal load, and Pomodoro breaks. | Optional |
| **Accessibility** | Window title tracking for Screen Time app usage monitoring. | Optional |
| **Input Monitoring** | Global keyboard hotkeys for Quick Launcher (⌘K) and Clipboard picker. | Optional |
| **Files & Folders** | User-selected directories for Local Backup Helper and Storage Analyzer. | Prompted on user action |
| **Full Disk Access** | Access to all system caches in Cache Cleaner and system-wide storage analysis. | Optional (admin choice) |

Permissions can be reviewed or revoked at any time in **System Settings → Privacy & Security**.

---

## 5. Third-Party Dependencies & Asset Licensing

Borno Pulse relies exclusively on Apple's first-party frameworks:
- **SwiftUI & AppKit**: User interface and native macOS windowing.
- **IOKit & Darwin Mach APIs**: Hardware telemetry, power management, and virtual memory.
- **Metal**: GPU capabilities and hardware acceleration.
- **PDFKit & ImageIO**: Native document editing, image compression, and format conversion.
- **Vision**: Offline OCR text recognition running locally on the Apple Neural Engine.
- **Network & BSD Sockets**: Local socket queries, ping latency, and DNS inspection.

No external binary libraries or untrusted closed-source dependencies are linked into the app.
