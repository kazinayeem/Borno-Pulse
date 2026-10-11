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
    
    /// Returns the active scaled font based on user preferences in AppSettings
    public static func font(
        size: CGFloat,
        weight: Font.Weight? = nil,
        isMonospaced: Bool = false
    ) -> Font {
        let settings = AppSettings.shared
        let scaledSize = max(8.0, size * settings.fontScale)
        let resolvedWeight = weight ?? settings.baseFontWeight.fontWeight

        if isMonospaced {
            let monoFamily = settings.monospacedFontFamily
            if let postScript = monoFamily.postScriptName, monoFamily.isAvailableOnSystem {
                return Font.custom(postScript, size: scaledSize)
            } else {
                return Font.system(size: scaledSize, weight: resolvedWeight, design: .monospaced)
            }
        }

        let family = settings.appFontFamily
        if family == .sfPro {
            return Font.system(size: scaledSize, weight: resolvedWeight, design: .default)
        }

        // Custom font resolution with graceful system fallback
        if let psName = family.postScriptName, family.isAvailableOnSystem {
            return Font.custom(psName, size: scaledSize)
        }

        // Graceful fallback to native system font
        return Font.system(size: scaledSize, weight: resolvedWeight, design: .default)
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
    let isMonospaced: Bool

    public func body(content: Content) -> some View {
        content
            .font(AppTypography.font(size: size, weight: weight, isMonospaced: isMonospaced))
    }
}

public extension View {
    func appFont(size: CGFloat, weight: Font.Weight? = nil, isMonospaced: Bool = false) -> some View {
        self.modifier(AppFontModifier(size: size, weight: weight, isMonospaced: isMonospaced))
    }

    func appMonospaced(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.modifier(AppFontModifier(size: size, weight: weight, isMonospaced: true))
    }
}
