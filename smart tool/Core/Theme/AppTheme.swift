//
//  AppTheme.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public enum AppTheme {
    // Dynamic color helper using standard AppKit dynamicProvider
    public static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? dark : light
        }))
    }
    
    // Primary Accents (refined macOS blue)
    public static let electricBlue = dynamic(
        light: NSColor(red: 0.08, green: 0.48, blue: 0.96, alpha: 1.0),
        dark: NSColor(red: 0.20, green: 0.60, blue: 1.00, alpha: 1.0)
    )
    public static let electricBlueLight = dynamic(
        light: NSColor(red: 0.20, green: 0.58, blue: 0.98, alpha: 1.0),
        dark: NSColor(red: 0.35, green: 0.72, blue: 1.00, alpha: 1.0)
    )
    public static let electricCyan = dynamic(
        light: NSColor(red: 0.00, green: 0.55, blue: 0.72, alpha: 1.0),
        dark: NSColor(red: 0.00, green: 0.82, blue: 0.94, alpha: 1.0)
    )
    public static let neonCyan = electricCyan
    public static let accentColor = electricBlue
    
    // Status Colors (accessible in both light & dark)
    public static let successGreen = dynamic(
        light: NSColor(red: 0.14, green: 0.60, blue: 0.32, alpha: 1.0),
        dark: NSColor(red: 0.20, green: 0.82, blue: 0.50, alpha: 1.0)
    )
    public static let matrixGreen = successGreen
    
    public static let warningAmber = dynamic(
        light: NSColor(red: 0.85, green: 0.48, blue: 0.05, alpha: 1.0),
        dark: NSColor(red: 1.00, green: 0.72, blue: 0.18, alpha: 1.0)
    )
    
    public static let dangerRed = dynamic(
        light: NSColor(red: 0.84, green: 0.18, blue: 0.22, alpha: 1.0),
        dark: NSColor(red: 1.00, green: 0.32, blue: 0.36, alpha: 1.0)
    )
    
    public static let purpleAccent = dynamic(
        light: NSColor(red: 0.50, green: 0.26, blue: 0.84, alpha: 1.0),
        dark: NSColor(red: 0.68, green: 0.42, blue: 1.00, alpha: 1.0)
    )
    
    public static let orangeAccent = dynamic(
        light: NSColor(red: 0.86, green: 0.42, blue: 0.06, alpha: 1.0),
        dark: NSColor(red: 1.00, green: 0.55, blue: 0.15, alpha: 1.0)
    )
    
    // Surfaces
    // Light Mode: soft neutral white canvas; Dark Mode: deep graphite
    public static let graphiteCanvas = dynamic(
        light: NSColor(red: 0.97, green: 0.975, blue: 0.985, alpha: 1.0),
        dark: NSColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1.0)
    )
    public static let background = graphiteCanvas
    
    // Sidebar background: subtly differentiated light neutral
    public static let sidebarBackground = dynamic(
        light: NSColor(red: 0.94, green: 0.95, blue: 0.965, alpha: 1.0),
        dark: NSColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0)
    )
    
    // Card Background: pure white in light mode; layered dark neutral in dark mode
    public static let cardBackground = dynamic(
        light: NSColor.white,
        dark: NSColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1.0)
    )
    
    // Secondary card surface (for inset panels, list rows, code blocks)
    public static let cardBackgroundSecondary = dynamic(
        light: NSColor(red: 0.95, green: 0.955, blue: 0.97, alpha: 1.0),
        dark: NSColor(red: 0.15, green: 0.16, blue: 0.20, alpha: 1.0)
    )
    
    // Borders: thin, low-contrast gray in light mode; subtle dark-neutral in dark mode
    public static let cardBorder = dynamic(
        light: NSColor(white: 0.0, alpha: 0.07),
        dark: NSColor(white: 1.0, alpha: 0.08)
    )
    
    public static let cardBorderHover = dynamic(
        light: NSColor(white: 0.0, alpha: 0.14),
        dark: NSColor(white: 1.0, alpha: 0.16)
    )
    
    // Typography: high-contrast, accessible text
    public static let textPrimary = dynamic(
        light: NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1.0),
        dark: NSColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0)
    )
    
    public static let textSecondary = dynamic(
        light: NSColor(red: 0.40, green: 0.42, blue: 0.46, alpha: 1.0),
        dark: NSColor(red: 0.62, green: 0.64, blue: 0.69, alpha: 1.0)
    )
    
    public static let textTertiary = dynamic(
        light: NSColor(red: 0.58, green: 0.60, blue: 0.64, alpha: 1.0),
        dark: NSColor(red: 0.44, green: 0.46, blue: 0.50, alpha: 1.0)
    )
    
    // Gradients
    public static let blueGradient = LinearGradient(
        colors: [electricBlue, electricCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let greenGradient = LinearGradient(
        colors: [successGreen, Color(red: 0.20, green: 0.85, blue: 0.55)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let warningGradient = LinearGradient(
        colors: [warningAmber, Color(red: 1.00, green: 0.60, blue: 0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let dangerGradient = LinearGradient(
        colors: [dangerRed, Color(red: 0.90, green: 0.20, blue: 0.25)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let darkCanvasGradient = LinearGradient(
        colors: [background, background],
        startPoint: .top,
        endPoint: .bottom
    )
}

public struct SmartCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 14
    var cornerRadius: CGFloat = 10
    var borderOpacity: CGFloat = 0.08
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.03),
                radius: 4,
                x: 0,
                y: 1
            )
    }
}

public extension View {
    func smartCard(padding: CGFloat = 14, cornerRadius: CGFloat = 10, borderOpacity: CGFloat = 0.08) -> some View {
        self.modifier(SmartCardModifier(padding: padding, cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
    
    func secondarySurface(padding: CGFloat = 10, cornerRadius: CGFloat = 8) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 0.5)
            )
    }
}
