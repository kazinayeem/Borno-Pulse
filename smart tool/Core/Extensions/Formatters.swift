//
//  Formatters.swift
//  Naem Smart Tool
//

import Foundation

public enum Formatters {
    public static func bytes(_ bytes: UInt64) -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    public static func bytes(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    public static func memoryBytes(_ bytes: UInt64) -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
    
    public static func speed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB/s", bytesPerSecond / (1024 * 1024))
        } else {
            return String(format: "%.2f GB/s", bytesPerSecond / (1024 * 1024 * 1024))
        }
    }
    
    public static func percentage(_ value: Double, decimals: Int = 1) -> String {
        return String(format: "%.\(decimals)f%%", min(max(value, 0.0), 100.0))
    }
    
    public static func temperature(_ celsius: Double, inFahrenheit: Bool = false) -> String {
        if inFahrenheit {
            let f = (celsius * 9 / 5) + 32
            return String(format: "%.1f °F", f)
        }
        return String(format: "%.1f °C", celsius)
    }
    
    public static func rpm(_ value: Double) -> String {
        return String(format: "%.0f RPM", value)
    }
}
