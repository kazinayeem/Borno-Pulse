//
//  Formatters.swift
//  Borno Pulse
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
    
    /// Placeholder for a missing reading. Deliberately not numeric so it can't be read as 0°.
    public static let unavailableTemperature = "Unavailable"

    /// Formats a Celsius reading in the requested unit. Defaults to whole degrees because
    /// on-die and battery sensors are not accurate beyond about ±1 °C.
    public static func temperature(_ celsius: Double?, unit: TemperatureUnit = .celsius, decimals: Int = 0) -> String {
        guard let celsius, celsius.isFinite else { return unavailableTemperature }
        let places = max(0, min(decimals, 2))
        return String(format: "%.\(places)f %@", unit.convert(fromCelsius: celsius), unit.symbol)
    }

    /// Compact menu bar form, e.g. "47°C".
    public static func compactTemperature(_ celsius: Double?, unit: TemperatureUnit = .celsius) -> String {
        guard let celsius, celsius.isFinite else { return "--\(unit.symbol)" }
        return String(format: "%.0f%@", unit.convert(fromCelsius: celsius), unit.symbol)
    }
    
    public static func rpm(_ value: Double) -> String {
        return String(format: "%.0f RPM", value)
    }

    /// "Updated 3s ago" style freshness text for a reading timestamp.
    public static func readingAge(since date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 2 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
    
    public static func duration(_ seconds: TimeInterval, showSeconds: Bool = false) -> String {
        let totalSeconds = max(0, Int(seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            if showSeconds && secs > 0 {
                return "\(hours)h \(minutes)m \(secs)s"
            }
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            if showSeconds && secs > 0 {
                return "\(minutes)m \(secs)s"
            }
            return "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }
    
    public static func durationPrecise(_ seconds: TimeInterval) -> String {
        return duration(seconds, showSeconds: true)
    }
}

