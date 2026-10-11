//
//  DiagnosticLogger.swift
//  Borno Pulse
//
//  Focused diagnostic logging for concurrency, lifecycle, and background service execution.
//

import Foundation
import os

public enum AppLog {
    public static let concurrency = Logger(subsystem: "com.naem.smart-tool", category: "Concurrency")
    public static let lifecycle = Logger(subsystem: "com.naem.smart-tool", category: "Lifecycle")
    public static let battery = Logger(subsystem: "com.naem.smart-tool", category: "Battery")
    public static let clipboard = Logger(subsystem: "com.naem.smart-tool", category: "Clipboard")
    public static let pdf = Logger(subsystem: "com.naem.smart-tool", category: "PDFStudio")
}
