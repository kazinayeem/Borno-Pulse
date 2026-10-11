//
//  ThemedComponents.swift
//  Borno Pulse
//
//  Small shared building blocks that keep controls consistent across pages.
//

import SwiftUI

// MARK: - Primary Button

/// Solid call-to-action button with a readable label in both appearances,
/// plus pressed, disabled and keyboard-focus states.
public struct ThemedPrimaryButtonStyle: ButtonStyle {
    public var fill: Color
    public var cornerRadius: CGFloat
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat

    public init(
        fill: Color = AppTheme.accentFill,
        cornerRadius: CGFloat = AppTheme.Radius.medium,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 8
    ) {
        self.fill = fill
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    public func makeBody(configuration: Configuration) -> some View {
        ThemedPrimaryButton(
            configuration: configuration,
            fill: fill,
            cornerRadius: cornerRadius,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        )
    }

    private struct ThemedPrimaryButton: View {
        let configuration: ButtonStyleConfiguration
        let fill: Color
        let cornerRadius: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            configuration.label
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .foregroundStyle(isEnabled ? AppTheme.textOnAccent : AppTheme.disabledText)
                .background(shape.fill(isEnabled ? fill : AppTheme.disabledFill))
                .overlay(shape.fill(Color.black.opacity(configuration.isPressed ? 0.15 : 0)))
                .contentShape(shape)
        }
    }
}

public extension ButtonStyle where Self == ThemedPrimaryButtonStyle {
    static var themedPrimary: ThemedPrimaryButtonStyle { ThemedPrimaryButtonStyle() }

    static func themedPrimary(
        fill: Color,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 8
    ) -> ThemedPrimaryButtonStyle {
        ThemedPrimaryButtonStyle(fill: fill, horizontalPadding: horizontalPadding, verticalPadding: verticalPadding)
    }
}

// MARK: - Inputs

public extension View {
    /// Background and border for plain text fields, editors and pickers that sit on cards.
    func themedInputField(cornerRadius: CGFloat = AppTheme.Radius.small, isFocused: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(shape.fill(AppTheme.inputBackground))
            .clipShape(shape)
            .overlay(
                shape.stroke(
                    isFocused ? AppTheme.electricBlue.opacity(0.7) : AppTheme.inputBorder,
                    lineWidth: isFocused ? 1.5 : 1
                )
            )
    }

    /// Low-emphasis tinted surface for chips, status capsules and inset rows.
    func themedSubtleSurface(cornerRadius: CGFloat = AppTheme.Radius.small) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.subtleFill)
        )
    }
}

/// Search field with an icon, clear button and visible focus ring.
public struct ThemedSearchField: View {
    private let placeholder: String
    @Binding private var text: String
    private let fontSize: CGFloat
    @FocusState private var isFocused: Bool

    public init(_ placeholder: String, text: Binding<String>, fontSize: CGFloat = 12) {
        self.placeholder = placeholder
        self._text = text
        self.fontSize = fontSize
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: fontSize - 1))
                .foregroundStyle(AppTheme.textTertiary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: fontSize))
                .foregroundStyle(AppTheme.textPrimary)
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: fontSize - 1))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .themedInputField(isFocused: isFocused)
    }
}

// MARK: - Selection

public extension AppTheme {
    /// Fill for a selectable chip, tab or preset tile.
    static func selectableFill(_ isSelected: Bool) -> Color {
        isSelected ? selectionBackground : subtleFill
    }

    /// Foreground for a selectable chip, tab or preset tile.
    static func selectableForeground(_ isSelected: Bool) -> Color {
        isSelected ? selectionForeground : textSecondary
    }
}

// MARK: - Empty State

public struct ThemedEmptyState: View {
    private let icon: String
    private let title: String
    private let message: String?

    public init(icon: String, title: String, message: String? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.textTertiary)
                .accessibilityHidden(true)
            Text(title)
                .font(AppTypography.font(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(AppTypography.font(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 420)
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
