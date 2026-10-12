//
//  AppTypography.swift
//  Borno Pulse
//
//  Centralized typography, icon styling, and font scaling system
//  supporting SF Pro, Avenir Next, Helvetica Neue, Inter, and SF Mono.
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Supported Font Families
public enum AppFontFamily: String, CaseIterable, Identifiable, Codable, Sendable {
    case sfPro = "SF Pro"
    case avenirNext = "Avenir Next"
    case helveticaNeue = "Helvetica Neue"
    case inter = "Inter"
    case sfMono = "SF Mono"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sfPro: return "SF Pro (System Default)"
        case .avenirNext: return "Avenir Next"
        case .helveticaNeue: return "Helvetica Neue"
        case .inter: return "Inter"
        case .sfMono: return "SF Mono"
        }
    }

    public var postScriptName: String? {
        switch self {
        case .sfPro: return nil // Use native system font
        case .avenirNext: return "AvenirNext-Regular"
        case .helveticaNeue: return "HelveticaNeue"
        case .inter: return "Inter-Regular"
        case .sfMono: return "SFMono-Regular"
        }
    }

    public var isAvailableOnSystem: Bool {
        switch self {
        case .sfPro:
            return true
        case .avenirNext, .helveticaNeue:
            guard let name = postScriptName else { return true }
            return NSFont(name: name, size: 12) != nil
        case .inter:
            return NSFont(name: "Inter-Regular", size: 12) != nil || NSFont(name: "Inter", size: 12) != nil
        case .sfMono:
            return NSFont(name: "SFMono-Regular", size: 12) != nil
        }
    }
}

// MARK: - Font Size Presets
public enum AppFontSizePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case small = "Small"
    case normal = "Normal"
    case large = "Large"

    public var id: String { rawValue }

    public var scale: Double {
        switch self {
        case .small: return 0.90
        case .normal: return 1.00
        case .large: return 1.15
        }
    }

    public var title: String {
        switch self {
        case .small: return "Small"
        case .normal: return "Normal"
        case .large: return "Large"
        }
    }

    public var description: String {
        switch self {
        case .small: return "Compact interface and menu bar metrics"
        case .normal: return "Balanced default size"
        case .large: return "Improved readability"
        }
    }
}

// MARK: - Base Weight Options
public enum AppFontWeight: String, CaseIterable, Identifiable, Codable, Sendable {
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"

    public var id: String { rawValue }

    public var fontWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        }
    }
}

// MARK: - Monospaced Font Families for Technical Telemetry
public enum AppMonospacedFontFamily: String, CaseIterable, Identifiable, Codable, Sendable {
    case systemMonospaced = "System Monospaced"
    case sfMono = "SF Mono"
    case menlo = "Menlo"
    case courierNew = "Courier New"

    public var id: String { rawValue }

    public var postScriptName: String? {
        switch self {
        case .systemMonospaced: return nil
        case .sfMono: return "SFMono-Regular"
        case .menlo: return "Menlo-Regular"
        case .courierNew: return "CourierNewPSMT"
        }
    }

    public var isAvailableOnSystem: Bool {
        guard let name = postScriptName else { return true }
        return NSFont(name: name, size: 12) != nil
    }
}

// MARK: - Menu Bar Status Item Symbols
public enum MenuBarIconSymbol: String, CaseIterable, Identifiable, Codable, Sendable {
    case gauge = "Gauge Needle"
    case pulseWave = "Pulse Wave"
    case boltHeart = "Energy Pulse"
    case cpuChip = "CPU Processor"
    case trendChart = "Activity Trend"
    case sparkles = "Modern Sparkle"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .gauge: return "gauge.with.dots.needle.bottom.100percent"
        case .pulseWave: return "waveform.path.ecg"
        case .boltHeart: return "bolt.heart.fill"
        case .cpuChip: return "cpu"
        case .trendChart: return "chart.line.uptrend.xyaxis"
        case .sparkles: return "sparkles"
        }
    }
}

// MARK: - Centralized Typography Engine
@MainActor
public enum AppTypography {
    
    public static let fontScaleRange: ClosedRange<Double> = 0.85...1.20

    /// Returns the active scaled font based on user preferences in AppSettings.
    /// `design: .monospaced` uses the chosen monospaced family; `.rounded` and `.serif` keep their
    /// system design so numeric displays and decorative text retain their intended shape.
    public static func font(
        size: CGFloat,
        weight: Font.Weight? = nil,
        design: Font.Design? = nil,
        isMonospaced: Bool = false
    ) -> Font {
        let settings = AppSettings.shared
        let scale = min(max(settings.fontScale, fontScaleRange.lowerBound), fontScaleRange.upperBound)
        let scaledSize = max(8.0, size * scale)
        let resolvedWeight = weight ?? settings.baseFontWeight.fontWeight

        if isMonospaced || design == .monospaced {
            if let name = installedName(settings.monospacedFontFamily.postScriptName) {
                return Font.custom(name, size: scaledSize).weight(resolvedWeight)
            }
            return Font.system(size: scaledSize, weight: resolvedWeight, design: .monospaced)
        }

        let family = settings.appFontFamily
        if family == .sfPro || design == .rounded || design == .serif {
            return Font.system(size: scaledSize, weight: resolvedWeight, design: design ?? .default)
        }

        if let name = installedName(family.postScriptName) ?? (family == .inter ? installedName("Inter") : nil) {
            return Font.custom(name, size: scaledSize).weight(resolvedWeight)
        }

        return Font.system(size: scaledSize, weight: resolvedWeight, design: .default)
    }

    private static var installedNames: [String: Bool] = [:]

    /// `name` when that font is installed. Lookups are cached because every styled view calls this
    /// on each render.
    private static func installedName(_ name: String?) -> String? {
        guard let name else { return nil }
        if let known = installedNames[name] { return known ? name : nil }
        let available = NSFont(name: name, size: 12) != nil
        installedNames[name] = available
        return available ? name : nil
    }

    /// Monospaced technical telemetry font (percentages, clock, memory, hashes)
    public static func monospaced(
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        font(size: size, weight: weight, isMonospaced: true)
    }

    // Standard Preset Tokens
    public static var title: Font { font(size: 20, weight: .bold) }
    public static var title2: Font { font(size: 16, weight: .semibold) }
    public static var headline: Font { font(size: 14, weight: .semibold) }
    public static var body: Font { font(size: 13, weight: .regular) }
    public static var bodyMedium: Font { font(size: 13, weight: .medium) }
    public static var callout: Font { font(size: 12, weight: .regular) }
    public static var caption: Font { font(size: 11, weight: .regular) }
    public static var footnote: Font { font(size: 10, weight: .regular) }
    public static var metricNumber: Font { monospaced(size: 13, weight: .bold) }
}

// MARK: - View Modifiers
public struct AppFontModifier: ViewModifier {
    @ObservedObject private var settings = AppSettings.shared
    let size: CGFloat
    let weight: Font.Weight?
    var design: Font.Design? = nil
    let isMonospaced: Bool

    public func body(content: Content) -> some View {
        content
            .font(AppTypography.font(size: size, weight: weight, design: design, isMonospaced: isMonospaced))
    }
}

public extension View {
    /// Applies the user's font family, scale and base weight. Use this instead of
    /// `.font(.system(size:))` so Settings › Typography reaches the view.
    func appFont(size: CGFloat, weight: Font.Weight? = nil, design: Font.Design? = nil, isMonospaced: Bool = false) -> some View {
        self.modifier(AppFontModifier(size: size, weight: weight, design: design, isMonospaced: isMonospaced))
    }

    func appMonospaced(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.modifier(AppFontModifier(size: size, weight: weight, isMonospaced: true))
    }
}
