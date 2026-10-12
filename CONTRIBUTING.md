# Contributing to Borno Pulse

Thank you for your interest in contributing to **Borno Pulse**! We welcome community contributions to keep this native macOS utility fast, reliable, privacy-first, and completely open source.

---

## 1. Development Workflow

1. **Fork & Clone**: Fork the repository on GitHub and clone your fork locally:
   ```bash
   git clone https://github.com/kazinayeem/Borno-Pulse.git
   cd Borno-Pulse
   ```
2. **Branching**: Create a meaningful topic branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Open Project**: Open `smart tool.xcodeproj` in Xcode 15 or 16:
   ```bash
   open "smart tool.xcodeproj"
   ```
4. **Target & Destination**: Select the `smart tool` scheme and set the destination to `My Mac`.
5. **Coding Guidelines**:
   - Write clean, modern Swift 6 with SwiftUI and native AppKit APIs.
   - Maintain strict concurrency safety (`@MainActor`, `Sendable`, nonisolated where appropriate).
   - Never introduce private Apple APIs that could break app stability.
   - Preserve offline-first architecture; all telemetry and file tools must work without internet access.

---

## 2. Testing Your Changes

Before submitting a Pull Request, run the automated test suite to ensure all invariant checks pass:

```bash
# Run the built app with test suite flag
xcodebuild -scheme "smart tool" -destination "platform=macOS" build
"$HOME/Library/Developer/Xcode/DerivedData/smart_tool-"*/Build/Products/Debug/"smart tool.app/Contents/MacOS/smart tool" --run-tests
```

All 854+ automated regression and invariant checks must pass with zero failures.

---

## 3. UI Changes & Screenshots

If your pull request introduces changes to the user interface, regenerate the screenshots using the automation script:

```bash
./scripts/capture-screenshots.sh
```

Inspect the resulting PNG files in `screenshots/light/`, `screenshots/dark/`, and `screenshots/widget/` to verify that both Light and Dark modes render cleanly without clipped labels or overflow.

---

## 4. Submitting a Pull Request

1. Commit your changes with clear, descriptive commit messages following Conventional Commits (e.g. `feat: add network traceroute`, `fix: prevent menu bar truncation`).
2. Push your topic branch to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
3. Open a Pull Request at [https://github.com/kazinayeem/Borno-Pulse/pulls](https://github.com/kazinayeem/Borno-Pulse/pulls) against the `main` branch.
4. Fill out the PR description with:
   - Summary of changes
   - Motivation and context
   - Relevant screenshots (before & after)
   - Confirmation of test pass

---

## 5. Code of Conduct

All contributors are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md). Please be respectful and constructive in all discussions.
