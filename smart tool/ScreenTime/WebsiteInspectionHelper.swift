//
//  WebsiteInspectionHelper.swift
//  Borno Pulse
//

import AppKit
import Foundation

/// Safe, standalone browser domain inspector using native AppleScript Apple Events.
/// Zero browser extensions, zero tracking scripts, zero private browsing/history scraping.
public final class WebsiteInspectionHelper: Sendable {
    public static let shared = WebsiteInspectionHelper()
    
    public enum InspectionResult: Sendable {
        case success(domain: String)
        case notABrowser
        case permissionDenied
        case windowUnavailable
        case executionError(String)
    }
    
    private init() {}
    
    /// Evaluates frontmost browser's active tab URL safely without blocking the main run loop.
    public func inspectActiveDomain(bundleIdentifier: String, appName: String) async -> InspectionResult {
        let b = bundleIdentifier.lowercased()
        let n = appName.lowercased()
        
        let scriptSource: String?
        if b.contains("safari") || n.contains("safari") {
            scriptSource = """
            tell application "Safari"
                if (count of windows) > 0 then
                    try
                        return URL of current tab of front window
                    on error
                        return ""
                    end try
                end if
                return ""
            end tell
            """
        } else if b.contains("chrome") || n.contains("chrome") ||
                  b.contains("brave") || n.contains("brave") ||
                  b.contains("edge") || n.contains("edge") ||
                  b.contains("arc") || n.contains("arc") {
            let targetName = appName.replacingOccurrences(of: "\"", with: "")
            scriptSource = """
            tell application "\(targetName)"
                if (count of windows) > 0 then
                    try
                        return URL of active tab of front window
                    on error
                        return ""
                    end try
                end if
                return ""
            end tell
            """
        } else {
            return .notABrowser
        }
        
        guard let source = scriptSource else {
            return .notABrowser
        }
        
        return await Task.detached(priority: .userInitiated) {
            let (rawURLString, errString, exitCode) = Self.runOsaScript(source: source)
            
            if exitCode != 0 {
                if let err = errString, err.contains("-1743") || err.contains("Not authorized") {
                    return .permissionDenied
                } else {
                    return .executionError(errString ?? "Process exit code \(exitCode)")
                }
            }
            
            guard !rawURLString.isEmpty else {
                return .windowUnavailable
            }
            
            if let url = URL(string: rawURLString), let host = url.host(), !host.isEmpty {
                let cleanedHost = host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
                return .success(domain: cleanedHost)
            } else {
                return .windowUnavailable
            }
        }.value
    }
    
    /// Executes AppleScript in an isolated subprocess, preventing libdispatch thread-queue assertions.
    public static func runOsaScript(source: String) -> (output: String, error: String?, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let errString = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return (output: output, error: errString?.isEmpty == true ? nil : errString, exitCode: process.terminationStatus)
        } catch {
            return (output: "", error: error.localizedDescription, exitCode: -1)
        }
    }
}
