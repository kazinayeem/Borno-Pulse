# Building Borno Pulse from Source

This guide provides tested, reproducible instructions for building, running, and packaging **Borno Pulse** on macOS.

---

## 1. Prerequisites

- **macOS Version**: macOS 14.0 (Sonoma) or macOS 15+ (Sequoia)
- **Architecture**: Apple Silicon (arm64, M1/M2/M3/M4) or Intel (x86_64)
- **Xcode Version**: Xcode 15.0 or Xcode 16+
- **Command Line Tools**: Installed via `xcode-select --install`
- **Swift Version**: Swift 5.9+ / Swift 6

---

## 2. Cloning the Repository

```bash
git clone https://github.com/kazinayeem/Borno-Pulse.git
cd Borno-Pulse
```

---

## 3. Opening in Xcode

To inspect, run, or debug interactively:

```bash
open "smart tool.xcodeproj"
```

1. Select the **`smart tool`** scheme in the scheme selector.
2. Select your destination: **`My Mac`**.
3. Press **⌘B** to build or **⌘R** to run.

---

## 4. Building from the Command Line

### Debug Build
```bash
xcodebuild -project "smart tool.xcodeproj" \
           -scheme "smart tool" \
           -destination "platform=macOS" \
           -configuration Debug \
           build
```

### Release Build
```bash
xcodebuild -project "smart tool.xcodeproj" \
           -scheme "smart tool" \
           -destination "platform=macOS" \
           -configuration Release \
           build
```

The compiled application bundle will be located inside Xcode's DerivedData folder:
`$HOME/Library/Developer/Xcode/DerivedData/smart_tool-*/Build/Products/Release/smart tool.app`

---

## 5. Running Automated Invariant Tests

Borno Pulse includes a comprehensive automated invariant test suite containing **854+ checks** covering hardware telemetry mathematical models, battery empirical decay calculations, PDF page transformations, socket parsing, clamshell duration intervals, and typography persistence.

Run the test suite directly via the built binary:

```bash
APP_BIN=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "smart tool" -type f -perm +111 -path "*/smart tool.app/Contents/MacOS/*" | head -n 1)
"$APP_BIN" --run-tests
```

A clean build will output:
```
--- INVARIANT TESTS COMPLETED ---
Passed: 854+, Failed: 0
```

---

## 6. Running Screenshot Automation

To automatically capture screenshots across all 24 navigation sections, 9 settings tabs, and the menu bar widget in both Light and Dark appearance modes:

```bash
./scripts/capture-screenshots.sh
```

Screenshots are written directly to `screenshots/light/`, `screenshots/dark/`, and `screenshots/widget/`.

---

## 7. Packaging & Distribution

To create a standalone distributable ZIP archive from a Release build:

```bash
RELEASE_APP="$HOME/Library/Developer/Xcode/DerivedData/smart_tool-"*/Build/Products/Release/"smart tool.app"
ditto -c -k --keepParent "$RELEASE_APP" "Borno-Pulse-macOS.zip"
```

For developer distribution outside the Mac App Store, sign the application with your Developer ID certificate and submit for Apple notarization:

```bash
codesign --deep --force --options runtime --sign "Developer ID Application: Your Name (TEAM_ID)" "smart tool.app"
xcrun notarytool submit "Borno-Pulse-macOS.zip" --keychain-profile "AC_PASSWORD" --wait
```

---

## 8. Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `Supported platforms for the buildables in the current scheme is empty` | Generic destination filter | Pass `-destination "platform=macOS"` to `xcodebuild`. |
| `Signing for "smart tool" requires a development team` | No signing identity set | In Xcode target settings, select your personal team or choose "Sign to Run Locally". |
| `_dispatch_assert_queue_fail` | Swift 6 actor crossing | Ensure you are on the latest `main` commit where background thread PDFKit calls bypass MainActor asserts. |
