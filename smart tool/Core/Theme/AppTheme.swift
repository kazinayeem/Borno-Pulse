//
//  AppTheme.swift
//  Borno Pulse
//
//  Centralized semantic color system. Every color resolves against the effective
//  NSAppearance of the view drawing it, so one token works in Light and Dark.
//  The app-wide appearance itself is applied by `AppearanceController`.
//

import AppKit
import SwiftUI

public enum AppTheme {
    // Dynamic color helper using standard AppKit dynamicProvider
    public static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: dynamicNSColor(light: light, dark: dark))
    }

    public static func dynamicNSColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? dark : light
        })
    }

    // MARK: - Accents

    // Light values are tuned for at least 4.5:1 contrast as text on white cards.
    public static let electricBlue = dynamic(
        light: NSColor(red: 0.05, green: 0.44, blue: 0.90, alpha: 1.0),
        dark: NSColor(red: 0.25, green: 0.62, blue: 1.00, alpha: 1.0)
    )
    public static let electricBlueLight = dynamic(
        light: NSColor(red: 0.20, green: 0.58, blue: 0.98, alpha: 1.0),
        dark: NSColor(red: 0.35, green: 0.72, blue: 1.00, alpha: 1.0)
    )
    public static let electricCyan = dynamic(
        light: NSColor(red: 0.00, green: 0.50, blue: 0.66, alpha: 1.0),
        dark: NSColor(red: 0.00, green: 0.82, blue: 0.94, alpha: 1.0)
    )
    public static let neonCyan = electricCyan
    public static let accentColor = electricBlue

    // MARK: - Status

    public static let successGreen = dynamic(
        light: NSColor(red: 0.10, green: 0.52, blue: 0.27, alpha: 1.0),
        dark: NSColor(red: 0.25, green: 0.82, blue: 0.52, alpha: 1.0)
    )
    public static let matrixGreen = successGreen

    public static let warningAmber = dynamic(
        light: NSColor(red: 0.72, green: 0.40, blue: 0.00, alpha: 1.0),
        dark: NSColor(red: 1.00, green: 0.74, blue: 0.22, alpha: 1.0)
    )

    public static let dangerRed = dynamic(
        light: NSColor(red: 0.80, green: 0.16, blue: 0.20, alpha: 1.0),
        dark: NSColor(red: 1.00, green: 0.40, blue: 0.42, alpha: 1.0)
    )

    public static let purpleAccent = dynamic(
        light: NSColor(red: 0.48, green: 0.24, blue: 0.82, alpha: 1.0),
        dark: NSColor(red: 0.72, green: 0.52, blue: 1.00, alpha: 1.0)
    )

    public static let orangeAccent = dynamic(
        light: NSColor(red: 0.80, green: 0.38, blue: 0.03, alpha: 1.0),
        dark: NSColor(red: 1.00, green: 0.60, blue: 0.22, alpha: 1.0)
    )

    public static let success = successGreen
    public static let warning = warningAmber
    public static let error = dangerRed
    public static let info = electricBlue

    /// Solid fills for prominent buttons. Mid-tone in both appearances so white labels stay readable.
    public static let accentFill = dynamic(
        light: NSColor(red: 0.05, green: 0.44, blue: 0.90, alpha: 1.0),
        dark: NSColor(red: 0.10, green: 0.48, blue: 0.95, alpha: 1.0)
    )
    public static let successFill = dynamic(
        light: NSColor(red: 0.09, green: 0.50, blue: 0.26, alpha: 1.0),
        dark: NSColor(red: 0.12, green: 0.56, blue: 0.32, alpha: 1.0)
    )
    public static let infoFill = dynamic(
        light: NSColor(red: 0.00, green: 0.46, blue: 0.60, alpha: 1.0),
        dark: NSColor(red: 0.00, green: 0.52, blue: 0.66, alpha: 1.0)
    )
    public static let dangerFill = dynamic(
        light: NSColor(red: 0.78, green: 0.15, blue: 0.19, alpha: 1.0),
        dark: NSColor(red: 0.84, green: 0.22, blue: 0.25, alpha: 1.0)
    )
    /// Label color drawn on top of the solid fills above.
    public static let textOnAccent = Color.white

    // MARK: - Surfaces

    // Light: soft neutral canvas with white cards. Dark: graphite canvas with lifted cards.
    public static let graphiteCanvas = dynamic(
        light: NSColor(red: 0.965, green: 0.969, blue: 0.976, alpha: 1.0),
        dark: NSColor(red: 0.105, green: 0.110, blue: 0.125, alpha: 1.0)
    )
    public static let background = graphiteCanvas
    public static let windowBackground = graphiteCanvas
    public static let contentBackground = graphiteCanvas

    public static let sidebarBackground = dynamic(
        light: NSColor(red: 0.935, green: 0.940, blue: 0.950, alpha: 1.0),
        dark: NSColor(red: 0.085, green: 0.090, blue: 0.105, alpha: 1.0)
    )

    public static let toolbarBackground = dynamic(
        light: NSColor(red: 0.980, green: 0.982, blue: 0.986, alpha: 1.0),
        dark: NSColor(red: 0.125, green: 0.130, blue: 0.148, alpha: 1.0)
    )

    public static let cardBackground = dynamic(
        light: NSColor.white,
        dark: NSColor(red: 0.150, green: 0.157, blue: 0.180, alpha: 1.0)
    )

    /// Popovers, sheets and floating panels that sit above cards.
    public static let elevatedCardBackground = dynamic(
        light: NSColor.white,
        dark: NSColor(red: 0.180, green: 0.188, blue: 0.215, alpha: 1.0)
    )

    /// Inset panels, list rows, code blocks and table headers inside a card.
    public static let cardBackgroundSecondary = dynamic(
        light: NSColor(red: 0.950, green: 0.954, blue: 0.965, alpha: 1.0),
        dark: NSColor(red: 0.120, green: 0.126, blue: 0.145, alpha: 1.0)
    )
    public static let insetBackground = cardBackgroundSecondary

    /// Text fields, editors and search fields. Always paired with `inputBorder`.
    public static let inputBackground = dynamic(
        light: NSColor.white,
        dark: NSColor(red: 0.095, green: 0.100, blue: 0.115, alpha: 1.0)
    )
    public static let inputBorder = dynamic(
        light: NSColor(white: 0.0, alpha: 0.16),
        dark: NSColor(white: 1.0, alpha: 0.16)
    )

    /// Low-emphasis tint for chips, unselected tabs, hover rows and progress tracks.
    public static let subtleFill = dynamic(
        light: NSColor(white: 0.0, alpha: 0.040),
        dark: NSColor(white: 1.0, alpha: 0.055)
    )
    public static let subtleFillStrong = dynamic(
        light: NSColor(white: 0.0, alpha: 0.070),
        dark: NSColor(white: 1.0, alpha: 0.095)
    )
    public static let hoverFill = subtleFillStrong
    public static let tableRowAlternate = dynamic(
        light: NSColor(white: 0.0, alpha: 0.022),
        dark: NSColor(white: 1.0, alpha: 0.028)
    )
    public static let tableHeaderBackground = cardBackgroundSecondary

    public static let selectionBackground = dynamic(
        light: NSColor(red: 0.05, green: 0.44, blue: 0.90, alpha: 0.12),
        dark: NSColor(red: 0.25, green: 0.62, blue: 1.00, alpha: 0.22)
    )
    public static let selectionForeground = electricBlue

    // MARK: - Borders

    public static let cardBorder = dynamic(
        light: NSColor(white: 0.0, alpha: 0.09),
        dark: NSColor(white: 1.0, alpha: 0.09)
    )
    public static let separator = cardBorder

    public static let cardBorderHover = dynamic(
        light: NSColor(white: 0.0, alpha: 0.16),
        dark: NSColor(white: 1.0, alpha: 0.17)
    )
    public static let borderStrong = cardBorderHover

    // MARK: - Typography

    public static let textPrimary = dynamic(
        light: NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1.0),
        dark: NSColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 1.0)
    )

    public static let textSecondary = dynamic(
        light: NSColor(red: 0.36, green: 0.38, blue: 0.42, alpha: 1.0),
        dark: NSColor(red: 0.68, green: 0.70, blue: 0.74, alpha: 1.0)
    )

    public static let textTertiary = dynamic(
        light: NSColor(red: 0.47, green: 0.49, blue: 0.53, alpha: 1.0),
        dark: NSColor(red: 0.54, green: 0.56, blue: 0.60, alpha: 1.0)
    )

    public static let placeholderText = textTertiary

    public static let disabledText = dynamic(
        light: NSColor(red: 0.56, green: 0.58, blue: 0.61, alpha: 1.0),
        dark: NSColor(red: 0.46, green: 0.48, blue: 0.52, alpha: 1.0)
    )
    public static let disabledFill = subtleFillStrong

    // MARK: - Charts

    public static let chartGrid = dynamic(
        light: NSColor(white: 0.0, alpha: 0.10),
        dark: NSColor(white: 1.0, alpha: 0.12)
    )
    public static let chartAxisLabel = textSecondary
    public static let chartTrack = subtleFill

    // MARK: - Gradients

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

    // MARK: - Metrics

    public enum Radius {
        public static let small: CGFloat = 6
        public static let medium: CGFloat = 8
        public static let card: CGFloat = 10
        public static let large: CGFloat = 12
    }
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
                color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04),
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
