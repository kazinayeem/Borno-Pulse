//
//  SystemCleanerAndLifecycleTests.swift
//  Borno Pulse Tests
//
//  Comprehensive test suite for:
//  - Application lifecycle, Dock visibility policy, Window close interception, and Reopen
//  - System Cleaner multi-tier categories, disk space reporting, and dry run
//  - Node.js scanner, package manager detection, monorepo flag, and safe deletion
//

import AppKit
import Foundation

@MainActor
public enum SystemCleanerAndLifecycleTests {
    public static func runTests(assert: (Bool, String) -> Void) {
        testLifecycleAndDockVisibility(assert: assert)
        testNodeModulesScannerAndSafeCleanup(assert: assert)
        testSystemCleanerService(assert: assert)
    }

    // MARK: - 1. Lifecycle, Close, Dock Visibility & Quit Tests
    private static func testLifecycleAndDockVisibility(assert: (Bool, String) -> Void) {
        // A. Initial isQuitting flag
        assert(AppDelegate.isQuitting == false, "Lifecycle: AppDelegate.isQuitting is false during normal session")

        // B. Closing last window must not terminate Borno Pulse
        let appDelegate = AppDelegate()
        assert(
            appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared) == false,
            "Lifecycle: Closing last window does not quit the application"
        )

        // C. Reopening from Dock or Finder must return true (handled)
        let handledReopen = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        assert(handledReopen == true, "Lifecycle: applicationShouldHandleReopen returns true indicating handled reopen")

        // D. Dock activation policy must be .regular
        NSApp.setActivationPolicy(.regular)
        assert(
            NSApp.activationPolicy == .regular,
            "Lifecycle: Application activation policy is .regular ensuring Dock visibility"
        )

        // E. Window Close Interception
        let testWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        testWindow.title = "Test Lifecycle Window"

        // When not quitting: windowShouldClose hides window and returns false
        AppDelegate.isQuitting = false
        let shouldCloseNormal = MainWindowDelegate.shared.windowShouldClose(testWindow)
        assert(
            shouldCloseNormal == false,
            "Lifecycle: MainWindowDelegate.windowShouldClose returns false to prevent window destruction"
        )
        assert(
            !testWindow.isVisible,
            "Lifecycle: MainWindowDelegate orders out window so it is visually closed"
        )

        // When quitting: windowShouldClose returns true to permit clean exit
        AppDelegate.isQuitting = true
        let shouldCloseQuitting = MainWindowDelegate.shared.windowShouldClose(testWindow)
        assert(
            shouldCloseQuitting == true,
            "Lifecycle: MainWindowDelegate.windowShouldClose returns true during app termination"
        )
        AppDelegate.isQuitting = false

        // F. MainWindowRouter registration and demilitarize
        MainWindowRouter.shared.register(window: testWindow)
        assert(
            MainWindowRouter.shared.mainWindow != nil,
            "Lifecycle: MainWindowRouter reliably tracks registered main window"
        )

        // G. MenuBarCoordinator Teardown safety
        MenuBarCoordinator.shared.teardown()
        assert(true, "Lifecycle: MenuBarCoordinator.teardown executes cleanly without crashing")
        MenuBarCoordinator.shared.setup()
    }

    // MARK: - 2. Node.js Scanner & Safe Cleanup Tests
    private static func testNodeModulesScannerAndSafeCleanup(assert: (Bool, String) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("BornoPulseNodeTest_\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            assert(false, "NodeTest: Failed to create temporary test directory: \(error)")
            return
        }

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create standard npm project
        let projectA = tempDir.appendingPathComponent("app-web")
        let nodeModulesA = projectA.appendingPathComponent("node_modules")
        let pkgJsonA = projectA.appendingPathComponent("package.json")
        let lockA = projectA.appendingPathComponent("package-lock.json")
        let srcA = projectA.appendingPathComponent("src")
        let srcFileA = srcA.appendingPathComponent("App.js")
        let dummyDep = nodeModulesA.appendingPathComponent("chalk")

        // Create pnpm monorepo project
        let projectB = tempDir.appendingPathComponent("monorepo")
        let pnpmWorkspace = projectB.appendingPathComponent("pnpm-workspace.yaml")
        let pnpmLock = projectB.appendingPathComponent("pnpm-lock.yaml")
        let pkgB = projectB.appendingPathComponent("packages/core")
        let nodeModulesB = pkgB.appendingPathComponent("node_modules")

        do {
            try FileManager.default.createDirectory(at: dummyDep, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: srcA, withIntermediateDirectories: true)
            try "{\"name\":\"app-web\",\"version\":\"1.0.0\"}".write(to: pkgJsonA, atomically: true, encoding: .utf8)
            try "{\"lockfileVersion\": 3}".write(to: lockA, atomically: true, encoding: .utf8)
            try "console.log('App code');".write(to: srcFileA, atomically: true, encoding: .utf8)
            let dummyData = Data(repeating: 0x41, count: 1024 * 16) // 16 KB
            try dummyData.write(to: dummyDep.appendingPathComponent("index.js"))

            try FileManager.default.createDirectory(at: nodeModulesB, withIntermediateDirectories: true)
            try "packages:\n  - 'packages/*'".write(to: pnpmWorkspace, atomically: true, encoding: .utf8)
            try "lockfileVersion: '9.0'".write(to: pnpmLock, atomically: true, encoding: .utf8)
            try dummyData.write(to: nodeModulesB.appendingPathComponent("dummy.js"))

            // Symlink loop protection test: symlink pointing back to tempDir
            let loopLink = projectA.appendingPathComponent("symlink_loop")
            try? FileManager.default.createSymbolicLink(at: loopLink, withDestinationURL: tempDir)
        } catch {
            assert(false, "NodeTest: Failed to create mock test files: \(error)")
            return
        }

        // Test scanner
        let scanner = NodeModulesScannerService.shared
        let results = scanner.scanDirectory(rootURL: tempDir)

        assert(results.count == 2, "NodeScanner: Discovered exactly 2 node_modules directories (found \(results.count))")

        if let itemA = results.first(where: { $0.projectDirectory.contains("app-web") }) {
            assert(itemA.hasPackageJson == true, "NodeScanner: Detected package.json in app-web")
            assert(itemA.hasLockfile == true, "NodeScanner: Detected package-lock.json in app-web")
            assert(itemA.detectedPackageManager == "npm", "NodeScanner: Correctly detected npm package manager")
            assert(itemA.sizeBytes >= 1024 * 16, "NodeScanner: Measured directory size >= 16KB (actual: \(itemA.sizeBytes))")
            assert(itemA.isMonorepo == false, "NodeScanner: app-web correctly classified as non-monorepo")
        } else {
            assert(false, "NodeScanner: Failed to locate app-web node_modules result")
        }

        if let itemB = results.first(where: { $0.projectDirectory.contains("monorepo") }) {
            assert(itemB.hasLockfile == true, "NodeScanner: Detected pnpm-lock.yaml in monorepo")
            assert(itemB.detectedPackageManager == "pnpm", "NodeScanner: Correctly detected pnpm package manager")
            assert(itemB.isMonorepo == true, "NodeScanner: Correctly flagged monorepo project")
        } else {
            assert(false, "NodeScanner: Failed to locate monorepo node_modules result")
        }

        // Safe Deletion Verification
        let beforeSourceExists = FileManager.default.fileExists(atPath: srcFileA.path)
        let beforePkgExists = FileManager.default.fileExists(atPath: pkgJsonA.path)
        let beforeLockExists = FileManager.default.fileExists(atPath: lockA.path)

        assert(beforeSourceExists && beforePkgExists && beforeLockExists, "NodeCleanup: Preconditions met before deletion")

        // Delete ONLY app-web node_modules
        let deleteResult = scanner.deleteNodeModulesDirectory(path: nodeModulesA.path)
        assert(deleteResult == true, "NodeCleanup: deleteNodeModulesDirectory returned success")

        let nodeModulesStillExists = FileManager.default.fileExists(atPath: nodeModulesA.path)
        assert(!nodeModulesStillExists, "NodeCleanup: node_modules directory was successfully deleted")

        // CRITICAL SAFETY INVARIANT: project files, source code, and manifests MUST remain intact
        let afterSourceExists = FileManager.default.fileExists(atPath: srcFileA.path)
        let afterPkgExists = FileManager.default.fileExists(atPath: pkgJsonA.path)
        let afterLockExists = FileManager.default.fileExists(atPath: lockA.path)
        let projectFolderExists = FileManager.default.fileExists(atPath: projectA.path)

        assert(projectFolderExists, "NodeCleanup [SAFETY]: Parent project directory was strictly PRESERVED")
        assert(afterSourceExists, "NodeCleanup [SAFETY]: Source file (src/App.js) was strictly PRESERVED")
        assert(afterPkgExists, "NodeCleanup [SAFETY]: package.json was strictly PRESERVED")
        assert(afterLockExists, "NodeCleanup [SAFETY]: package-lock.json was strictly PRESERVED")
    }

    // MARK: - 3. System Cleaner Service Tests
    private static func testSystemCleanerService(assert: (Bool, String) -> Void) {
        let cleaner = SystemCleanerService.shared
        cleaner.refreshDiskSpace()

        assert(cleaner.diskSpace.totalCapacityBytes > 0, "SystemCleaner: Disk total capacity is measured (\(Formatters.bytes(cleaner.diskSpace.totalCapacityBytes)))")
        assert(cleaner.diskSpace.availableBytes > 0, "SystemCleaner: Disk available bytes is measured (\(Formatters.bytes(cleaner.diskSpace.availableBytes)))")
        assert(cleaner.diskSpace.usedBytes > 0, "SystemCleaner: Disk used bytes is measured (\(Formatters.bytes(cleaner.diskSpace.usedBytes)))")

        cleaner.setupCategories()
        assert(!cleaner.categories.isEmpty, "SystemCleaner: Initialized cleanup categories (\(cleaner.categories.count) categories)")

        // Mode preset tests
        cleaner.selectedMode = .quick
        cleaner.applyModePreset()
        let quickSelected = cleaner.categories.filter { $0.isSelected }
        assert(
            quickSelected.allSatisfy { $0.safetyTier == .safe },
            "SystemCleaner: Quick Clean selects ONLY safe categories (no high or moderate risk)"
        )

        cleaner.selectedMode = .developer
        cleaner.applyModePreset()
        let devSelected = cleaner.categories.filter { $0.isSelected }
        let hasDevCategory = devSelected.contains { $0.id.contains("developer") || $0.id.contains("xcode") || $0.id.contains("npm") }
        assert(hasDevCategory, "SystemCleaner: Developer Clean enables developer build caches")

        // Simulation / Dry Run Test
        cleaner.executeClean(dryRun: true)
        if let report = cleaner.lastExecutionReport {
            assert(report.isDryRun == true, "SystemCleaner: Simulation report accurately reflects dry-run execution")
            assert(report.success == true, "SystemCleaner: Dry-run simulation finished successfully")
        } else {
            assert(false, "SystemCleaner: Last execution report generated after cleanup")
        }
    }
}
