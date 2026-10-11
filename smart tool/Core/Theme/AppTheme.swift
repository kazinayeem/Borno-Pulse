//
//  AppTheme.swift
//  Naem Smart Tool
//

import SwiftUI

public enum AppTheme {
    // Primary Accents
    public static let electricBlue = Color(red: 0.08, green: 0.55, blue: 1.00)
    public static let electricBlueLight = Color(red: 0.25, green: 0.68, blue: 1.00)
    public static let electricCyan = Color(red: 0.00, green: 0.84, blue: 0.95)
    public static let neonCyan = electricCyan
    
    // Status Colors
    public static let successGreen = Color(red: 0.20, green: 0.84, blue: 0.52)
    public static let matrixGreen = successGreen
    public static let warningAmber = Color(red: 1.00, green: 0.72, blue: 0.18)
    public static let dangerRed = Color(red: 1.00, green: 0.32, blue: 0.36)
    public static let purpleAccent = Color(red: 0.68, green: 0.42, blue: 1.00)
    public static let orangeAccent = Color(red: 1.00, green: 0.55, blue: 0.15)
    
    // Surfaces
    public static let graphiteCanvas = Color(red: 0.07, green: 0.08, blue: 0.10)
    public static let background = graphiteCanvas
    public static let cardBackground = Color(red: 0.12, green: 0.13, blue: 0.17)
    public static let cardBackgroundSecondary = Color(red: 0.15, green: 0.16, blue: 0.21)
    public static let cardBorder = Color.white.opacity(0.08)
    public static let cardBorderHover = Color.white.opacity(0.18)
    
    // Text
    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
    public static let textTertiary = Color.secondary.opacity(0.7)
    
    // Gradients
    public static let blueGradient = LinearGradient(
        colors: [electricBlue, electricCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let greenGradient = LinearGradient(
        colors: [Color(red: 0.15, green: 0.75, blue: 0.45), Color(red: 0.30, green: 0.90, blue: 0.60)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let warningGradient = LinearGradient(
        colors: [Color(red: 0.95, green: 0.65, blue: 0.15), Color(red: 1.00, green: 0.45, blue: 0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let dangerGradient = LinearGradient(
        colors: [Color(red: 0.95, green: 0.25, blue: 0.30), Color(red: 0.80, green: 0.15, blue: 0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let darkCanvasGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.09, blue: 0.12),
            Color(red: 0.05, green: 0.06, blue: 0.08)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

public struct SmartCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 12
    var borderOpacity: CGFloat = 0.08
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? AppTheme.cardBackground
                            : Color(nsColor: .controlBackgroundColor)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(borderOpacity)
                            : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06),
                radius: 8,
                x: 0,
                y: 3
            )
    }
}

public extension View {
    func smartCard(padding: CGFloat = 16, cornerRadius: CGFloat = 12, borderOpacity: CGFloat = 0.08) -> some View {
        self.modifier(SmartCardModifier(padding: padding, cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
}
