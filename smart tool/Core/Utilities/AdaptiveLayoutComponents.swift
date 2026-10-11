//
//  AdaptiveLayoutComponents.swift
//  Borno Pulse
//
//  Centralized, reusable responsive layout components for native macOS:
//  - AdaptivePageHeader (auto-wraps toolbar controls when window is compact)
//  - AdaptiveTwoColumnLayout (side-by-side on wide viewports, stacked on compact)
//  - AdaptiveMetricCard (responsive card with flexible titles, badges, and tooltips)
//  - AdaptiveTableContainer (horizontal scroll preservation for dense data tables)
//  - AdaptiveCardGrid (responsive auto-wrapping grid)
//

import SwiftUI

// MARK: - Adaptive Page Header
public struct AdaptivePageHeader<LeadingExtra: View, Trailing: View>: View {
    public let title: String
    public let subtitle: String?
    public let leadingExtra: LeadingExtra
    public let trailing: Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leadingExtra: () -> LeadingExtra = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingExtra = leadingExtra()
        self.trailing = trailing()
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            // Wide layout: Title on left, actions on right
            HStack(alignment: .top, spacing: 16) {
                titleSection
                Spacer(minLength: 16)
                trailing
            }

            // Compact layout: Actions stacked below title
            VStack(alignment: .leading, spacing: 12) {
                titleSection
                trailing
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(AppTypography.font(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                
                leadingExtra
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppTypography.font(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// Convenience extension for headers without extra badge
public extension AdaptivePageHeader where LeadingExtra == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(title: title, subtitle: subtitle, leadingExtra: { EmptyView() }, trailing: trailing)
    }
}

// MARK: - Adaptive Two Column Layout
public struct AdaptiveTwoColumnLayout<Left: View, Right: View>: View {
    public let left: Left
    public let right: Right
    public let spacing: CGFloat
    public let rightWidth: CGFloat?

    public init(
        spacing: CGFloat = 16,
        rightWidth: CGFloat? = nil,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) {
        self.spacing = spacing
        self.rightWidth = rightWidth
        self.left = left()
        self.right = right()
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            // Side-by-side on wide screens
            HStack(alignment: .top, spacing: spacing) {
                left
                    .frame(maxWidth: .infinity)
                if let rw = rightWidth {
                    right
                        .frame(width: rw)
                } else {
                    right
                        .frame(maxWidth: .infinity)
                }
            }

            // Stacked on narrow screens
            VStack(alignment: .leading, spacing: spacing) {
                left
                    .frame(maxWidth: .infinity)
                right
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Responsive Metric Card
public struct ResponsiveMetricCard: View {
    public let title: String
    public let value: String
    public let subvalue: String?
    public let icon: String
    public let tint: Color
    public let badge: String?
    public let tooltip: String?

    public init(
        title: String,
        value: String,
        subvalue: String? = nil,
        icon: String,
        tint: Color = AppTheme.electricBlue,
        badge: String? = nil,
        tooltip: String? = nil
    ) {
        self.title = title
        self.value = value
        self.subvalue = subvalue
        self.icon = icon
        self.tint = tint
        self.badge = badge
        self.tooltip = tooltip
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card Header: Icon + Title + Badge
            ViewThatFits(in: .horizontal) {
                // Wide: title and badge in one row
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                    
                    Text(title)
                        .font(AppTypography.font(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 4)
                    
                    if let badge = badge {
                        badgeView(badge)
                    }
                }
                
                // Compact: stacked title and badge
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tint)
                        
                        Text(title)
                            .font(AppTypography.font(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    if let badge = badge {
                        badgeView(badge)
                    }
                }
            }

            // Metric Value
            Text(value)
                .font(AppTypography.monospaced(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .help(tooltip ?? value)

            // Subvalue
            if let sub = subvalue {
                Text(sub)
                    .font(AppTypography.font(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(sub)
            }
        }
        .padding(14)
        .smartCard()
    }

    private func badgeView(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.font(size: 9, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Adaptive Table Container
public struct AdaptiveTableContainer<Content: View>: View {
    public let minWidth: CGFloat
    public let content: Content

    public init(minWidth: CGFloat = 680, @ViewBuilder content: () -> Content) {
        self.minWidth = minWidth
        self.content = content()
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            content
                .frame(minWidth: minWidth, alignment: .leading)
        }
    }
}

// MARK: - Adaptive Card Grid
public struct AdaptiveCardGrid<Content: View>: View {
    public let minColumnWidth: CGFloat
    public let spacing: CGFloat
    public let content: Content

    public init(minColumnWidth: CGFloat = 180, spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.minColumnWidth = minColumnWidth
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minColumnWidth), spacing: spacing)],
            spacing: spacing
        ) {
            content
        }
    }
}
