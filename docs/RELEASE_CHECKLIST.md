# Borno Pulse — Release Verification Checklist

This document tracks verification status and release engineering requirements for **Borno Pulse** production releases on macOS.

---

## 1. Application Identity & Build Configuration

| Item | Requirement | Verification Status | Notes |
|:---|:---|:---:|:---|
| **App Name** | `Borno Pulse` | ✅ Verified | Display name, bundle CFBundleName, and window title |
| **Bundle Identifier** | `com.bornosoft.smart-tool` | ✅ Verified | Consistent across `Info.plist` and `project.pbxproj` |
| **Release Version** | `1.3.0` | ✅ Verified | SemVer compatible across UI, about dialog, and packaging |
| **Build Number** | `1` | ✅ Verified | Matching CFBundleVersion |
| **Deployment Target** | macOS 14.0+ (Sonoma, Sequoia+) | ✅ Verified | Minimum OS enforced in project settings |
| **Target Architecture** | Universal (`arm64` Apple Silicon + `x86_64` Intel) | ✅ Verified | Compiled as universal macOS release binary |
| **Build Configuration** | Release (`-configuration Release`) | ✅ Verified | Optimization level `-O`, debug assertions disabled |
| **Swift Concurrency** | Swift 6 Complete Concurrency Checking | ✅ Verified | Strict concurrency flags enabled |

---

## 2. Code Signing, Hardened Runtime & Notarization

| Item | Requirement | Verification Status | Notes |
|:---|:---|:---:|:---|
| **Ad-Hoc Signing** | Valid Mach-O signature applied | ✅ Verified | `codesign --force --deep --sign -` applied to release bundle |
| **Hardened Runtime** | `ENABLE_HARDENED_RUNTIME = YES` | ✅ Verified | Configured in Xcode project for Release builds |
| **Developer ID Application** | Apple Developer ID certificate | ⚠️ CI / Secret Required | Used in `.github/workflows/release.yml` when secrets are provided |
| **Apple Notarization** | `xcrun notarytool` ticket stapled | ⚠️ CI / Secret Required | Automated in GitHub Actions when Apple Developer credentials exist |
| **Gatekeeper Guidance** | Safe user documentation for unsigned builds | ✅ Verified | Documented `xattr -cr /Applications/Borno\ Pulse.app` in README & docs |

---

## 3. Automated Invariant & Quality Assurance Tests

All tests executed natively via the application binary using `--run-tests`:

| Test Domain | Coverage | Verification Status | Result |
|:---|:---|:---:|:---:|
| **Hardware Telemetry** | CPU per-core, Mach memory, Metal GPU, battery decay models | ✅ Verified | Passed (0 failures) |
| **Clamshell Mode** | IOKit sleep assertions, hardware audit, duration timer | ✅ Verified | Passed (0 failures) |
| **Quick Actions** | 21 actions, registry definitions, title & icon completeness | ✅ Verified | Passed (0 failures) |
| **Keep Awake** | IOPMAssertionCreateWithName lifecycle and teardown | ✅ Verified | Passed (0 failures) |
| **Node.js Cleanup** | Recursive search, monorepo/lockfile detection, safe directory deletion | ✅ Verified | Passed (0 failures) |
| **Safety Invariants** | Source code, `package.json`, and parent directory preservation | ✅ Verified | Passed (0 failures) |
| **System Cleaner** | Volume measurement, category presets (`quick`, `developer`, `custom`) | ✅ Verified | Passed (0 failures) |
| **Lifecycle & Dock** | Red close button window ordering, Dock visibility, reopen handler | ✅ Verified | Passed (0 failures) |
| **Settings Navigation** | Responsive multi-row `FlowLayout` tab wrapping without clipping | ✅ Verified | Passed (0 failures) |
| **Developer Profile** | Avatar loading from asset catalog, bundle resources, and remote fallback | ✅ Verified | Passed (0 failures) |

---

## 4. Packaging & Distribution Artifacts

| Artifact | Specification | Verification Status | Output Path |
|:---|:---|:---:|:---|
| **Release Application** | `Borno Pulse.app` macOS bundle | ✅ Verified | `dist/Borno Pulse.app` |
| **Release DMG (Versioned)** | UDZO read-only disk image with `/Applications` link | ✅ Verified | `dist/Borno-Pulse-v1.3.0.dmg` (18 MB) |
| **Release DMG (Latest)** | Direct-download disk image mirror | ✅ Verified | `dist/Borno-Pulse-macOS.dmg` & `releases/Borno-Pulse-macOS.dmg` |
| **Release ZIP** | Clean zip archive with bundle structure (`--norsrc`) | ✅ Verified | `dist/Borno-Pulse-macOS.zip` (15 MB) |
| **Checksum Manifest** | SHA-256 hashes of all release packages | ✅ Verified | `dist/checksums-sha256.txt` |
| **Installed Bundle** | Clean install in system `/Applications` | ✅ Verified | `/Applications/Borno Pulse.app` |

---

## 5. Repository & Documentation Compliance

| Document | Purpose | Verification Status | Notes |
|:---|:---|:---:|:---|
| `README.md` | Root landing page with direct download badges, screenshots, usage | ✅ Verified | Verified repository coordinates (`kazinayeem/Borno-Pulse`) |
| `LICENSE` | MIT Open-Source License | ✅ Verified | Copyright © 2026 BornoSoft |
| `CONTRIBUTING.md` | Community contribution guidelines | ✅ Verified | Branching and test instructions included |
| `CODE_OF_CONDUCT.md` | Contributor Covenant v2.1 | ✅ Verified | Standards and reporting contact |
| `SECURITY.md` | Security vulnerability disclosure process | ✅ Verified | Direct contact and turnaround policy |
| `CHANGELOG.md` | Version history and feature milestones | ✅ Verified | Updated for v1.3.0 |
| `docs/BUILDING.md` | Local compilation and packaging guide | ✅ Verified | Step-by-step instructions for Xcode & CLI |
| `docs/PRIVACY.md` | Privacy architecture and zero-telemetry guarantee | ✅ Verified | Explains local data boundaries |
| `.github/workflows/release.yml` | Automated GitHub Actions release pipeline | ✅ Verified | Automated test, build, package, and publish |
