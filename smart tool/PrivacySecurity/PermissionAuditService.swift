//
//  PermissionAuditService.swift
//  Borno Pulse
//

import AppKit
import ApplicationServices
import Foundation

public final class PermissionAuditService: Sendable {
    public static let shared = PermissionAuditService()
    
    private init() {}
    
    public func performAudit() -> [PermissionAuditItem] {
        var items: [PermissionAuditItem] = []
        
        // 1. Accessibility
        let axTrusted = AXIsProcessTrusted()
        items.append(PermissionAuditItem(
            name: "Accessibility Permissions",
            featureImpact: "Required for system window positioning, global hotkeys, and frontmost application focus tracking.",
            isGranted: axTrusted,
            statusText: axTrusted ? "Granted" : "Not Granted (Optional)",
            systemSettingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ))
        
        // 2. Full Disk Access
        let home = FileManager.default.homeDirectoryForCurrentUser
        let safariPath = home.appendingPathComponent("Library/Safari/Bookmarks.plist")
        let fdaGranted = FileManager.default.isReadableFile(atPath: safariPath.path)
        items.append(PermissionAuditItem(
            name: "Full Disk Access (FDA)",
            featureImpact: "Allows Storage Analytics and Cache Cleaner to analyze protected system caches, Time Machine local snapshots, and system libraries.",
            isGranted: fdaGranted,
            statusText: fdaGranted ? "Granted" : "Restricted (Standard User Scope)",
            systemSettingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ))
        
        // 3. AppleScript Automation
        let script = NSAppleScript(source: "tell application \"Finder\" to return name")
        var errDict: NSDictionary?
        _ = script?.executeAndReturnError(&errDict)
        let autoGranted = (errDict == nil)
        items.append(PermissionAuditItem(
            name: "Automation / Apple Events",
            featureImpact: "Enables extension-free active browser domain inspection (Safari & Chromium) for Screen Time.",
            isGranted: autoGranted,
            statusText: autoGranted ? "Granted" : "Prompt on First Request",
            systemSettingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ))
        
        // 4. File System Entitlements (App Sandbox)
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        items.append(PermissionAuditItem(
            name: "macOS Sandbox Boundaries",
            featureImpact: "Governs directory access boundaries. User-selected files and Downloads are granted read/write permissions via standard panels.",
            isGranted: true,
            statusText: isSandboxed ? "Sandboxed with User Entitlements" : "Standard macOS App (Hardened Runtime)",
            systemSettingsURL: nil
        ))
        
        return items
    }
}
