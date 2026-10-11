//
//  WebsiteInspectionHelper.swift
//  Naem Smart Tool
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
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var errorDict: NSDictionary?
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(returning: .executionError("Could not compile AppleScript"))
                    return
                }
                
                let outputDescriptor = script.executeAndReturnError(&errorDict)
                
                if let error = errorDict {
                    let errNum = error[NSAppleScript.errorNumber] as? Int ?? 0
                    if errNum == -1743 {
                        continuation.resume(returning: .permissionDenied)
                    } else {
                        let errMsg = error[NSAppleScript.errorMessage] as? String ?? "AppleScript error \(errNum)"
                        continuation.resume(returning: .executionError(errMsg))
                    }
                    return
                }
                
                guard let rawURLString = outputDescriptor.stringValue,
                      !rawURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuation.resume(returning: .windowUnavailable)
                    return
                }
                
                if let url = URL(string: rawURLString), let host = url.host(), !host.isEmpty {
                    let cleanedHost = host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
                    continuation.resume(returning: .success(domain: cleanedHost))
                } else {
                    continuation.resume(returning: .windowUnavailable)
                }
            }
        }
    }
}
